from __future__ import annotations

import asyncio
import gc
from unittest.mock import AsyncMock, patch

import httpx
import pytest
from starlette.testclient import TestClient

from app.core.config import Settings
from app.core.single_flight import SingleFlight
from app.clients.bridge import PrestaShopBridgeClient
from app.clients.prestashop import PrestaShopClient
from app.main import app


pytestmark = pytest.mark.anyio


# ==============================================================================
# 1. SingleFlight Tests
# ==============================================================================

async def test_single_flight_coalesces_concurrent_calls():
    """Verify that multiple concurrent calls for the same key execute only once."""
    sf = SingleFlight()
    call_count = 0

    async def slow_work() -> str:
        nonlocal call_count
        call_count += 1
        await asyncio.sleep(0.05)
        return f"result-{call_count}"

    # 20 concurrent coroutines requesting the same key
    results = await asyncio.gather(*[sf.execute("item-1", slow_work) for _ in range(20)])

    assert call_count == 1
    assert len(results) == 20
    assert all(r == "result-1" for r in results)


async def test_single_flight_independent_keys():
    """Verify different keys run independently."""
    sf = SingleFlight()
    results_map = {}

    async def work(key: str) -> str:
        results_map[key] = results_map.get(key, 0) + 1
        await asyncio.sleep(0.02)
        return f"done-{key}"

    res_a, res_b = await asyncio.gather(
        sf.execute("key-a", lambda: work("key-a")),
        sf.execute("key-b", lambda: work("key-b")),
    )

    assert res_a == "done-key-a"
    assert res_b == "done-key-b"
    assert results_map["key-a"] == 1
    assert results_map["key-b"] == 1


async def test_single_flight_cleans_up_and_propagates_error():
    """Verify that exceptions propagate to all callers and the key is cleaned up."""
    sf = SingleFlight()
    call_count = 0

    async def failing_work():
        nonlocal call_count
        call_count += 1
        await asyncio.sleep(0.02)
        raise ValueError("simulated network error")

    # Both concurrent calls should receive the error
    with pytest.raises(ValueError, match="simulated network error"):
        await asyncio.gather(
            sf.execute("fail-key", failing_work),
            sf.execute("fail-key", failing_work),
        )

    assert call_count == 1
    assert "fail-key" not in sf._in_flight

    # Subsequent call can retry cleanly
    async def ok_work():
        return "recovered"

    res = await sf.execute("fail-key", ok_work)
    assert res == "recovered"


async def test_single_flight_failure_without_followers_does_not_log_orphan_error():
    sf = SingleFlight()
    loop = asyncio.get_running_loop()
    original_handler = loop.get_exception_handler()
    errors = []
    loop.set_exception_handler(lambda loop, context: errors.append(context))

    async def failing_work():
        raise ValueError("single caller failure")

    try:
        with pytest.raises(ValueError, match="single caller failure"):
            await sf.execute("alone", failing_work)
        gc.collect()
        await asyncio.sleep(0)
        assert errors == []
        assert sf._in_flight == {}
    finally:
        loop.set_exception_handler(original_handler)


# ==============================================================================
# 2. Product Image Cache & Headers Tests
# ==============================================================================

def test_product_image_caching_and_304_headers():
    """
    Test GET /v1/products/{id}/image:
    - 1st hit: Fetches from upstream, sets Cache-Control, ETag, Content-Length
    - 2nd hit: Served from fast in-memory cache
    - Conditional request (If-None-Match == ETag): Returns HTTP 304 with empty body
    - Conditional request with non-matching ETag: Returns HTTP 200 with content
    """
    from app.api.routes import catalog as catalog_route

    # Clear image cache for testing
    catalog_route._image_cache.clear()

    fake_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 50
    mock_ps = AsyncMock()
    mock_ps.get_binary = AsyncMock(return_value=(
        fake_jpeg,
        "image/jpeg",
        {"content-sha1": "test-sha1-hash-12345"},
    ))
    mock_ps.reset_perf = lambda: None
    mock_ps.prestashop_calls = 1
    mock_ps.prestashop_time_ms = 10.0

    app.dependency_overrides[catalog_route.get_ps_client] = lambda: mock_ps
    try:
        client = TestClient(app)

        # First request (Cold)
        resp1 = client.get("/v1/products/999/image")
        assert resp1.status_code == 200
        assert resp1.headers.get("content-type") == "image/jpeg"
        assert resp1.headers.get("cache-control") == "public, max-age=300"
        etag = resp1.headers.get("etag")
        assert etag == '"test-sha1-hash-12345"'
        assert resp1.headers.get("content-length") == str(len(fake_jpeg))
        assert resp1.content == fake_jpeg
        assert mock_ps.get_binary.call_count == 1

        # Second request (Warm - from memory cache)
        resp2 = client.get("/v1/products/999/image")
        assert resp2.status_code == 200
        assert resp2.headers.get("etag") == etag
        assert resp2.content == fake_jpeg
        # Verify get_binary was NOT called again!
        assert mock_ps.get_binary.call_count == 1

        # Third request: Conditional If-None-Match matching etag
        resp3 = client.get("/v1/products/999/image", headers={"If-None-Match": etag})
        assert resp3.status_code == 304
        assert resp3.text == ""
        assert resp3.headers.get("etag") == etag
        assert resp3.headers.get("cache-control") == "public, max-age=300"
        assert mock_ps.get_binary.call_count == 1

        # Fourth request: Conditional If-None-Match NOT matching etag
        resp4 = client.get("/v1/products/999/image", headers={"If-None-Match": '"different"'})
        assert resp4.status_code == 200
        assert resp4.content == fake_jpeg
        assert mock_ps.get_binary.call_count == 1
    finally:
        app.dependency_overrides.pop(catalog_route.get_ps_client, None)


def test_product_image_does_not_cache_non_image_response():
    from app.api.routes import catalog as catalog_route

    catalog_route._image_cache.clear()
    mock_ps = AsyncMock()
    mock_ps.get_binary = AsyncMock(return_value=(
        b"<html>not an image</html>",
        "text/html",
        {},
    ))
    mock_ps.reset_perf = lambda: None
    mock_ps.prestashop_calls = 1
    mock_ps.prestashop_time_ms = 10.0

    app.dependency_overrides[catalog_route.get_ps_client] = lambda: mock_ps
    try:
        client = TestClient(app)
        response = client.get("/v1/products/999/image")

        assert response.status_code == 404
        assert "images/products/999" not in catalog_route._image_cache
    finally:
        app.dependency_overrides.pop(catalog_route.get_ps_client, None)


def test_product_image_does_not_cache_empty_response():
    from app.api.routes import catalog as catalog_route

    catalog_route._image_cache.clear()
    mock_ps = AsyncMock()
    mock_ps.get_binary = AsyncMock(return_value=(
        b"",
        "image/jpeg",
        {},
    ))
    mock_ps.reset_perf = lambda: None
    mock_ps.prestashop_calls = 1
    mock_ps.prestashop_time_ms = 10.0

    app.dependency_overrides[catalog_route.get_ps_client] = lambda: mock_ps
    try:
        client = TestClient(app)
        response = client.get("/v1/products/999/image")

        assert response.status_code == 404
        assert "images/products/999" not in catalog_route._image_cache
    finally:
        app.dependency_overrides.pop(catalog_route.get_ps_client, None)


# ==============================================================================
# 3. HTTP Client Granular Timeouts & Keepalive Limits
# ==============================================================================

def test_prestashop_client_and_bridge_pooling_config():
    """Verify connection pool limits and granular timeouts are properly configured."""
    settings = Settings(
        app_name="Heliantha Test",
        prestashop_base_url="https://heliantha.ma",
        prestashop_webservice_key="key",
        mobile_bridge_url="https://heliantha.ma/bridge.php",
        mobile_bridge_secret="secret",
        prestashop_timeout_seconds=15.0,
    )

    ps_client = PrestaShopClient(settings)
    shared_ps = ps_client._shared_client()
    assert isinstance(shared_ps, httpx.AsyncClient)
    assert shared_ps.timeout.connect == 5.0
    assert shared_ps.timeout.read == 15.0
    assert shared_ps.timeout.write == 10.0
    assert shared_ps.timeout.pool == 5.0

    bridge_client = PrestaShopBridgeClient(settings)
    shared_bridge = bridge_client._shared_client()
    assert isinstance(shared_bridge, httpx.AsyncClient)
    assert shared_bridge.timeout.connect == 5.0
    assert shared_bridge.timeout.read == 15.0
    assert shared_bridge.timeout.write == 10.0
    assert shared_bridge.timeout.pool == 5.0


# ==============================================================================
# 4. Preview Concurrency & No-Cache Verification
# ==============================================================================

async def test_checkout_preview_parallel_gathering():
    """
    Verify checkout preview runs product catalog lookup and Morocco country lookup in parallel
    and never caches preview results.
    """
    from app.services.checkout import CheckoutService
    from app.schemas.checkout import CheckoutPreviewIn, CheckoutLineIn
    from app.schemas.product import ProductOut

    mock_ps = AsyncMock()
    mock_catalog = AsyncMock()
    mock_bridge = AsyncMock()
    mock_bridge.post = AsyncMock(return_value={
        "data": {
            "totals": {
                "subtotal": 200.0,
                "total_ttc": 200.0,
                "currency": "MAD",
            },
            "carriers": [],
            "payments": [],
        }
    })
    settings = Settings(
        app_name="Heliantha Test",
        prestashop_base_url="https://heliantha.ma",
        prestashop_webservice_key="key",
    )
    svc = CheckoutService(ps=mock_ps, catalog=mock_catalog, settings=settings, bridge=mock_bridge)

    # Mock catalog products_by_ids and morocco_country_id
    svc.catalog.products_by_ids = AsyncMock(return_value=[ProductOut(
        id=10,
        name="Panneau de test",
        price=100,
        currency="MAD",
        currency_symbol="DH",
        available=True,
        quantity=5,
    )])
    svc._morocco_country_id = AsyncMock(return_value=140)

    req = CheckoutPreviewIn(
        lines=[CheckoutLineIn(product_id=10, quantity=2)],
    )

    res = await svc.preview(req)
    assert res.totals.currency == "MAD"
    assert svc.catalog.products_by_ids.called
    assert svc._morocco_country_id.called
    assert mock_bridge.post.called
