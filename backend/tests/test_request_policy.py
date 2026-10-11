import asyncio
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.request_policy import (
    DEFAULT_TRUSTED_HOSTS,
    HostValidationMiddleware,
    configured_trusted_hosts,
    route_path,
)
from app.main import app


def test_default_hosts_allow_testserver_only_in_development(monkeypatch):
    monkeypatch.delenv('TRUSTED_HOSTS', raising=False)
    assert set(configured_trusted_hosts('development')) == {*DEFAULT_TRUSTED_HOSTS, 'testserver'}
    assert configured_trusted_hosts('production') == DEFAULT_TRUSTED_HOSTS
    assert 'testserver' not in configured_trusted_hosts('staging')


def test_explicit_trusted_hosts_are_normalized_without_adding_defaults(monkeypatch):
    monkeypatch.setenv('TRUSTED_HOSTS', ' Store.Example.test , [::1]:8011, ::1, 127.0.0.1 ')
    assert configured_trusted_hosts('production') == ('store.example.test', '::1', '127.0.0.1')


@pytest.mark.parametrize('configured', [
    '*', '*.heliantha.ma', '', ' ', 'localhost,',
    'https://heliantha.ma', 'localhost/path', 'bad_host', '-host.test',
    'localhost:0', 'localhost:65536', 'localhost:abc',
])
def test_invalid_or_wildcard_host_configuration_is_rejected(monkeypatch, configured):
    monkeypatch.setenv('TRUSTED_HOSTS', configured)
    with pytest.raises(ValueError, match='TRUSTED_HOSTS'):
        configured_trusted_hosts('production')


def check_authorities(authorities, *, accepted):
    async def run():
        downstream = AsyncMock()
        middleware = HostValidationMiddleware(downstream, allowed_hosts=DEFAULT_TRUSTED_HOSTS)
        scope = {'type': 'http', 'method': 'GET', 'path': '/v1/products',
                 'headers': authorities}
        receive = AsyncMock()
        send = AsyncMock()
        await middleware(scope, receive, send)
        if accepted:
            downstream.assert_awaited_once_with(scope, receive, send)
            send.assert_not_awaited()
        else:
            downstream.assert_not_awaited()
            start = send.await_args_list[0].args[0]
            assert start['status'] == 400
            assert b'no-store' in dict(start['headers'])[b'cache-control']
            assert send.await_args_list[1].args[0]['body'] == b'{"detail":"Host invalide"}'
    asyncio.run(run())


@pytest.mark.parametrize('authority', [
    b'localhost', b'LOCALHOST:8011', b'127.0.0.1:1', b'heliantha.ma:65535',
    b'app.heliantha.ma', b'api.heliantha.ma', b'www.heliantha.ma',
    b'[::1]', b'[0:0:0:0:0:0:0:1]:8011',
])
def test_valid_configured_authorities_reach_downstream(authority):
    check_authorities([(b'Host', authority)], accepted=True)


@pytest.mark.parametrize('authority', [
    b'', b'evil.example.test', b'heliantha.ma.evil.test', b'testserver',
    b'localhost/health', b'localhost/health#', b'localhost?health',
    b'localhost#health', b'localhost@evil.test', b'localhost\\health',
    b'localhost,heliantha.ma', b' localhost', b'localhost ',
    b'localhost\t', b'localhost\x00', b'localhost\r\n', b'localh\xffst',
    b'localhost:0', b'localhost:65536', b'localhost:', b'localhost:+80',
    b'localhost:80:90', b'localhost:abc', b'::1', b'[::1', b'::1]',
    b'[::1]garbage', b'[::1]:', b'[::1]:0', b'[::1]:65536', b'[::1%lo]',
    b'[127.0.0.1]', b'localhost.', b'-localhost', b'localhost-',
    b'local_host', b'local..host', b'999.999.999.999',
])
def test_malformed_or_untrusted_authorities_stop_before_downstream(authority):
    check_authorities([(b'host', authority)], accepted=False)


@pytest.mark.parametrize('headers', [
    [], [(b'host', b'localhost'), (b'Host', b'localhost')],
    [(b'host', b'localhost'), (b'host', b'evil.example.test')],
])
def test_exactly_one_host_header_is_required(headers):
    check_authorities(headers, accepted=False)


@pytest.mark.parametrize(('root_path', 'path', 'expected'), [
    ('', '/v1/products', '/v1/products'),
    ('/mounted', '/v1/products', '/v1/products'),
    ('/mounted', '/mounted/v1/products', '/v1/products'),
    ('/mounted/', '/mounted/v1/products', '/v1/products'),
    ('/mounted', '/mounted', '/'),
    ('/mounted', '/mounted-other/v1/products', '/mounted-other/v1/products'),
    ('/mounted/nested', '/mounted/nested/v1/products', '/v1/products'),
    ('/', '/v1/products', '/v1/products'),
])
def test_route_path_handles_both_asgi_root_path_conventions(root_path, path, expected):
    assert route_path({'root_path': root_path, 'path': path}) == expected


def test_route_path_never_uses_host_or_raw_url_for_exemptions():
    scope = {'root_path': '/mounted', 'path': '/mounted/v1/products',
             'headers': [(b'host', b'testserver/v1/maintenance/status#')],
             'raw_path': b'/v1/maintenance/status'}
    assert route_path(scope) == '/v1/products'


@pytest.mark.parametrize('host', ['evil.example.test', 'testserver/health#', 'testserver:abc'])
def test_app_rejects_invalid_hosts_before_maintenance(available_maintenance_source, host):
    with TestClient(app) as client:
        response = client.get('/v1/products', headers={'Host': host})
    assert response.status_code == 400
    assert response.json() == {'detail': 'Host invalide'}
    assert 'no-store' in response.headers['Cache-Control']
    available_maintenance_source.status.assert_not_awaited()


def test_app_rejects_duplicate_host_headers_before_maintenance(available_maintenance_source):
    with TestClient(app) as client:
        response = client.get('/v1/products', headers=[('Host', 'testserver'), ('Host', 'localhost')])
    assert response.status_code == 400
    available_maintenance_source.status.assert_not_awaited()


@pytest.mark.parametrize(('root_path', 'path'), [
    ('', '/v1/products'),
    ('/mounted', '/v1/products'),
    ('/mounted', '/mounted/v1/products'),
])
def test_app_trusted_host_does_not_bypass_maintenance_for_mounted_paths(
        available_maintenance_source, root_path, path):
    available_maintenance_source.status.return_value = {'maintenance': True}
    with TestClient(app, root_path=root_path) as client:
        response = client.get(path, headers={'Host': 'localhost:8011'})
    assert response.status_code == 503
    assert response.json()['error_code'] == 'maintenance'
    available_maintenance_source.status.assert_awaited_once()
