import asyncio
import time
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
            assert len(seen) == 3  # Explicit fresh checks bypass the business cache.
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


def test_ten_concurrent_business_checks_use_warm_cache_under_50ms():
    async def run():
        source = MaintenanceService('http://flask:8012')
        calls = 0

        async def handler(request):
            nonlocal calls
            calls += 1
            await asyncio.sleep(0.02)
            return httpx.Response(200, json=state(False))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            await source.status(fresh=False)
            started = time.perf_counter()
            results = await asyncio.gather(*(source.status(fresh=False) for _ in range(10)))
            elapsed = time.perf_counter() - started
            assert elapsed < 0.05
            assert all(result['maintenance'] is False for result in results)
            assert calls == 1
            results[0]['maintenance'] = True
            assert (await source.status(fresh=False))['maintenance'] is False
        finally:
            await source.close()
    asyncio.run(run())


def test_expired_cache_has_one_async_refresh_for_ten_waiters():
    async def run():
        source = MaintenanceService('http://flask:8012')
        calls = 0
        refreshing = asyncio.Event()
        release = asyncio.Event()

        async def handler(request):
            nonlocal calls
            calls += 1
            if calls > 1:
                refreshing.set()
                await release.wait()
            return httpx.Response(200, json=state(calls > 1))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            assert (await source.status(fresh=False))['maintenance'] is False
            source._checked_at -= 15.1
            requests = [asyncio.create_task(source.status(fresh=False)) for _ in range(10)]
            await asyncio.wait_for(refreshing.wait(), 1)
            await asyncio.sleep(0)
            assert calls == 2
            release.set()
            results = await asyncio.gather(*requests)
            assert all(result['maintenance'] is True for result in results)
            assert calls == 2
            assert source._pending == {}
        finally:
            release.set()
            await source.close()
    asyncio.run(run())


def test_long_poll_snapshot_refreshes_after_one_second_within_business_ttl():
    async def run():
        source = MaintenanceService('http://flask:8012')
        enabled = False
        calls = 0

        def handler(request):
            nonlocal calls
            calls += 1
            return httpx.Response(200, json=state(enabled))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            assert (await source.status(fresh=False))['maintenance'] is False
            enabled = True
            source._checked_at -= 1.1
            assert (await source.status(fresh=False))['maintenance'] is False
            assert calls == 1
            assert (await source.status(fresh=False, max_age=1.0))['maintenance'] is True
            assert calls == 2
            assert (await source.status(fresh=False, max_age=1.0))['maintenance'] is True
            assert calls == 2
        finally:
            await source.close()
    asyncio.run(run())


@pytest.mark.parametrize('enabled', [False, True])
def test_source_outage_preserves_last_known_public_state(enabled):
    async def run():
        source = MaintenanceService('http://flask:8012')
        calls = 0

        def handler(request):
            nonlocal calls
            calls += 1
            if calls > 1:
                raise httpx.ConnectError('offline')
            return httpx.Response(200, json=state(enabled))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            assert (await source.status(fresh=False))['maintenance'] is enabled
            source._checked_at -= 15.1
            assert (await source.status(fresh=False))['maintenance'] is enabled
            assert calls == 2
            assert (await source.status(fresh=False))['maintenance'] is enabled
            assert calls == 2
        finally:
            await source.close()
    asyncio.run(run())


def test_source_outage_never_reuses_an_admin_exemption():
    async def run():
        source = MaintenanceService('http://flask:8012')
        offline = False

        def handler(request):
            if offline:
                raise httpx.ConnectError('offline')
            return httpx.Response(200, json=state(True, request.headers.get('cookie') == 'session=admin'))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            assert (await source.status('session=admin', fresh=False))['maintenance'] is False
            assert source._public_state is None
            offline = True
            with pytest.raises(MaintenanceUnavailable):
                await source.status('session=admin', fresh=False)
            with pytest.raises(MaintenanceUnavailable):
                await source.status(fresh=False)
            offline = False
            assert (await source.status(fresh=False))['maintenance'] is True
            assert (await source.status('session=admin', fresh=False))['maintenance'] is False
            offline = True
            assert (await source.status('session=admin', fresh=False))['maintenance'] is True
        finally:
            await source.close()
    asyncio.run(run())


def test_different_cookies_have_independent_source_reads_and_never_share_exemptions():
    async def run():
        source = MaintenanceService('http://flask:8012')
        public_started = asyncio.Event()
        release_public = asyncio.Event()
        seen = []

        async def handler(request):
            cookie = request.headers.get('cookie', '')
            seen.append(cookie)
            if not cookie:
                public_started.set()
                await release_public.wait()
            return httpx.Response(200, json=state(True, cookie == 'session=admin'))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        visitor = None
        try:
            visitor = asyncio.create_task(source.status(fresh=False))
            await asyncio.wait_for(public_started.wait(), 1)
            admin = await asyncio.wait_for(source.status('session=admin', fresh=False), 1)
            assert admin['maintenance'] is False
            other = await asyncio.wait_for(source.status('session=visitor', fresh=False), 1)
            assert other['maintenance'] is True
            assert source._public_state is None
            release_public.set()
            assert (await visitor)['maintenance'] is True
            assert (await source.status(fresh=False))['maintenance'] is True
            assert seen == ['', 'session=admin', 'session=visitor']
        finally:
            release_public.set()
            await source.close()
            if visitor is not None:
                await asyncio.gather(visitor, return_exceptions=True)
    asyncio.run(run())


def test_cancelling_a_waiter_does_not_cancel_shared_refresh():
    async def run():
        source = MaintenanceService('http://flask:8012')
        started = asyncio.Event()
        release = asyncio.Event()
        calls = 0

        async def handler(request):
            nonlocal calls
            calls += 1
            started.set()
            await release.wait()
            return httpx.Response(200, json=state(True))

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        try:
            disconnected = asyncio.create_task(source.status(fresh=False))
            await asyncio.wait_for(started.wait(), 1)
            survivor = asyncio.create_task(source.status(fresh=False))
            await asyncio.sleep(0)
            disconnected.cancel()
            with pytest.raises(asyncio.CancelledError):
                await disconnected
            release.set()
            assert (await survivor)['maintenance'] is True
            assert calls == 1
            assert source._pending == {}
        finally:
            release.set()
            await source.close()
    asyncio.run(run())


def test_close_cancels_pending_refresh_before_closing_http_client():
    async def run():
        source = MaintenanceService('http://flask:8012')
        started = asyncio.Event()

        async def handler(request):
            started.set()
            await asyncio.Event().wait()

        source._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        waiter = asyncio.create_task(source.status(fresh=False))
        await asyncio.wait_for(started.wait(), 1)
        await source.close()
        with pytest.raises(asyncio.CancelledError):
            await waiter
        assert source._pending == {}
        assert source._client is None
    asyncio.run(run())


@pytest.mark.parametrize('payload', [
    None,
    {'maintenance': 'false'},
    {'maintenance': False, 'enabled': True, 'admin_exempt': False},
    {'maintenance': False, 'enabled': True, 'admin_exempt': True},
])
def test_invalid_initial_status_never_opens_business_requests(payload):
    async def run():
        source = MaintenanceService('http://flask:8012')
        source._client = httpx.AsyncClient(transport=httpx.MockTransport(
            lambda request: httpx.Response(200, json=payload)
        ))
        try:
            with pytest.raises(MaintenanceUnavailable):
                await source.status(fresh=False)
            assert source._public_state is None
        finally:
            await source.close()
    asyncio.run(run())
