import asyncio
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.maintenance import MaintenanceService, MaintenanceUnavailable


def state(enabled=False, admin=False):
    return {"enabled": enabled, "maintenance": enabled and not admin, "admin_exempt": admin}


def test_all_client_endpoints_are_blocked_before_business_logic(available_maintenance_source):
    available_maintenance_source.status.return_value = state(True)
    with TestClient(app) as client:
        for method, path in [('GET', '/v1/products'), ('GET', '/v1/me'),
                             ('POST', '/v1/checkout'), ('POST', '/v1/devis/calculate'),
                             ('GET', '/v1/favorites'), ('GET', '/v1/orders')]:
            response = client.request(method, path)
            assert response.status_code == 503
            assert response.json()['error_code'] == 'maintenance'
            assert response.headers['Cache-Control'].startswith('private, no-store')
        assert client.get('/health').status_code == 200
        assert client.get('/v1/maintenance/status').json()['maintenance'] is True


def test_admin_exemption_is_validated_by_flask_not_client_role(available_maintenance_source):
    async def status(cookie='', **kwargs):
        return state(True, cookie == 'session=valid-admin')
    available_maintenance_source.status.side_effect = status
    with TestClient(app) as client:
        assert client.get('/v1/missing', headers={'X-Admin': 'true'}).status_code == 503
        assert client.get('/v1/missing', headers={'Cookie': 'session=valid-admin'}).status_code == 404


def test_toggle_applies_to_next_request_and_long_poll(available_maintenance_source):
    available_maintenance_source.status.side_effect = [state(False), state(True), state(True), state(False)]
    with TestClient(app) as client:
        assert client.get('/v1/missing').status_code == 404
        response = client.get('/v1/maintenance/status?since=false&wait=1')
        assert response.status_code == 200 and response.json()['maintenance'] is True
        assert client.get('/v1/missing').status_code == 503
        response = client.get('/v1/maintenance/status?since=true&wait=1')
        assert response.status_code == 200 and response.json()['maintenance'] is False


def test_control_outage_does_not_execute_checkout(available_maintenance_source):
    available_maintenance_source.status.side_effect = MaintenanceUnavailable()
    with TestClient(app) as client:
        for path in ['/v1/maintenance/status', '/v1/products']:
            response = client.get(path)
            assert response.status_code == 503
            assert response.json()['error_code'] == 'maintenance_status_unavailable'


def test_cors_preflight_and_blocked_responses(available_maintenance_source):
    available_maintenance_source.status.return_value = state(True)
    with TestClient(app) as client:
        headers = {'Origin': 'http://localhost:3000'}
        response = client.options('/v1/checkout', headers={**headers, 'Access-Control-Request-Method': 'POST'})
        assert response.status_code == 200
        response = client.get('/v1/products', headers=headers)
        assert response.status_code == 503
        assert response.headers['Access-Control-Allow-Origin'] == headers['Origin']


def test_source_no_cache_on_business_requests_and_no_admin_leak():
    async def run():
        source = MaintenanceService('http://flask:8012')
        enabled = False
        seen = []

        def handler(request):
            seen.append(str(request.url))
            return httpx.Response(200, json=state(enabled, request.headers.get('cookie') == 'session=admin'))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            assert (await source.status())['maintenance'] is False
            enabled = True
            assert (await source.status('session=admin'))['maintenance'] is False
            assert (await source.status())['maintenance'] is True
            assert (await source.status(fresh=False))['maintenance'] is True
            assert len(seen) == 3  # Watchers share a snapshot; business checks do not.
            enabled = False
            assert (await source.status())['maintenance'] is False
            assert set(seen) == {'http://flask:8012/api/maintenance/status'}
        finally:
            await source.close()
    asyncio.run(run())


def test_source_outage_keeps_known_maintenance_and_rejects_invalid_data():
    async def run():
        source = MaintenanceService('http://flask:8012')
        source._client = AsyncMock()
        source._client.get.return_value = httpx.Response(200, json=state(True), request=httpx.Request('GET', source.url))
        assert (await source.status())['maintenance'] is True
        source._client.get.side_effect = httpx.ConnectError('offline')
        assert (await source.status())['maintenance'] is True
        source._public_state = None
        try:
            await source.status()
            assert False, 'Unknown status must not reopen services'
        except MaintenanceUnavailable:
            pass
        await source.close()
    asyncio.run(run())


def test_public_responses_never_relay_administrative_fields(available_maintenance_source):
    available_maintenance_source.status.return_value = {
        **state(True), 'actor': 'private-admin@example.test', 'token': 'private-token',
        'deployment': 'internal-server:8012', 'updated_at': '2099-01-01',
    }
    with TestClient(app) as client:
        response = client.get('/v1/maintenance/status')
        assert set(response.json()) == {'maintenance', 'message'}
        response = client.get('/v1/products')
        assert set(response.json()) == {'maintenance', 'message', 'error_code'}
        assert 'private-admin' not in response.text
        assert 'internal-server' not in response.text


@pytest.mark.parametrize('enabled', [False, True])
def test_source_accepts_minimal_public_contract(enabled):
    async def run():
        source = MaintenanceService('http://flask:8012')
        source._client = httpx.AsyncClient(transport=httpx.MockTransport(
            lambda request: httpx.Response(200, json={'maintenance': enabled, 'message': 'OK'})
        ))
        try:
            result = await source.status()
            assert result['maintenance'] is enabled
            assert set(result) == {'maintenance', 'message'}
        finally:
            await source.close()
    asyncio.run(run())
