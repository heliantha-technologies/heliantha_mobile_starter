from unittest.mock import AsyncMock

import pytest

from app.schemas.product import ProductOut
from app.schemas.store import CurrencyOut
from app.services import catalog as catalog_module
from app.services.catalog import CatalogService


pytestmark = pytest.mark.anyio


class DummySettings:
    prestashop_language_id = 3


def make_service(monkeypatch):
    now = [100.0]
    unavailable = [True]
    monkeypatch.setattr(catalog_module, "monotonic", lambda: now[0])
    monkeypatch.setattr(
        catalog_module, "redis_unavailable", lambda: unavailable[0]
    )
    ps = AsyncMock()
    ps.get_resource.return_value = {"product": {"id": "42"}}
    service = CatalogService(ps, DummySettings())
    service._stock_for_products = AsyncMock(return_value={})
    service._product_from_row = AsyncMock(
        return_value=ProductOut(id=42, name="Produit")
    )
    service.store_context.currency_for = AsyncMock(
        return_value=CurrencyOut(
            id=2, name="Dirham", iso_code="MAD", symbol="MAD"
        )
    )
    CatalogService.clear_memory_caches()
    return service, ps, now, unavailable


async def test_detail_cache_falls_back_for_15_minutes_without_redis(monkeypatch):
    service, ps, now, _ = make_service(monkeypatch)

    await service.product(42)
    now[0] = 999.0
    await service.product(42)
    ps.list_resource.return_value = {"products": [{"id": "42"}]}
    await service.products_by_ids([42])
    assert ps.get_resource.await_count == 1
    assert ps.list_resource.await_count == 1

    now[0] = 1000.0
    await service.product(42)
    assert ps.get_resource.await_count == 2
    CatalogService.clear_memory_caches()


async def test_detail_cache_returns_to_20_seconds_when_redis_recovers(monkeypatch):
    service, ps, now, unavailable = make_service(monkeypatch)

    await service.product(42)
    now[0] = 121.0
    unavailable[0] = False
    await service.product(42)
    assert ps.get_resource.await_count == 2

    unavailable[0] = True
    now[0] = 500.0
    await service.product(42)
    assert ps.get_resource.await_count == 2

    unavailable[0] = False
    await service.product(42)
    assert ps.get_resource.await_count == 3
    CatalogService.clear_memory_caches()
