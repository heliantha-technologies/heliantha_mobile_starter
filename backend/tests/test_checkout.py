import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.clients.bridge import BridgeHTTPError
from app.core.config import Settings
from app.schemas.checkout import CheckoutLineIn, CheckoutPreviewIn
from app.schemas.product import ProductOut
from app.services.catalog import CatalogService
from app.services.checkout import CheckoutService

pytestmark = pytest.mark.anyio


def _settings() -> Settings:
    return Settings(
        app_name="Heliantha Test",
        prestashop_base_url="https://heliantha.ma",
        prestashop_webservice_key="test-key",
    )


def _product(
    product_id: int,
    *,
    price: float = 100,
    quantity: int = 10,
    available: bool = True,
) -> ProductOut:
    return ProductOut(
        id=product_id,
        name=f"Produit {product_id}",
        price=price,
        currency="MAD",
        currency_symbol="DH",
        currency_id=1,
        available=available,
        quantity=quantity,
    )


def _bridge_preview(total: float = 350) -> dict:
    return {
        "data": {
            "totals": {
                "subtotal": total,
                "shipping": 0,
                "shipping_label": "Gratuit",
                "discounts": 0,
                "total_ttc": total,
                "currency": "MAD",
                "currency_symbol": "DH",
            },
            "carriers": [],
            "payments": [],
            "stock_ok": True,
        }
    }


async def test_preview_uses_one_grouped_catalog_lookup_and_bridge_totals():
    catalog = SimpleNamespace(
        products_by_ids=AsyncMock(
            return_value=[_product(index, price=70) for index in range(1, 6)]
        )
    )
    bridge = SimpleNamespace(post=AsyncMock(return_value=_bridge_preview(350)))
    service = CheckoutService(AsyncMock(), catalog, _settings(), bridge)
    service._morocco_country_id = AsyncMock(return_value=144)
    payload = CheckoutPreviewIn(
        lines=[CheckoutLineIn(product_id=index, quantity=1) for index in range(1, 6)],
        currency_id=1,
        language_id=3,
    )

    preview = await service.preview(payload)

    catalog.products_by_ids.assert_awaited_once_with(
        [1, 2, 3, 4, 5], language_id=3, currency_id=1
    )
    assert bridge.post.await_count == 1
    sent_lines = bridge.post.await_args.args[1]["lines"]
    assert [(line["product_id"], line["quantity"]) for line in sent_lines] == [
        (index, 1) for index in range(1, 6)
    ]
    assert preview.totals.total_ttc == 350
    assert preview.totals.taxes_included is True
    assert preview.stock_ok is True


async def test_stock_shortage_returns_line_details_without_calling_bridge():
    catalog = SimpleNamespace(
        products_by_ids=AsyncMock(
            side_effect=[
                [_product(7, quantity=0)],
                [_product(7, quantity=0)],
            ]
        )
    )
    bridge = SimpleNamespace(post=AsyncMock())
    service = CheckoutService(AsyncMock(), catalog, _settings(), bridge)
    service._morocco_country_id = AsyncMock(return_value=144)

    preview = await service.preview(
        CheckoutPreviewIn(lines=[CheckoutLineIn(product_id=7, quantity=2)])
    )

    assert catalog.products_by_ids.await_count == 2
    catalog.products_by_ids.assert_awaited_with(
        [7], language_id=None, currency_id=None, force_refresh=True
    )
    bridge.post.assert_not_awaited()
    assert preview.stock_ok is False
    assert preview.lines[0].available is False
    assert preview.lines[0].stock_quantity == 0
    assert preview.lines[0].stock_message == "Stock insuffisant : 0 disponible(s)."
    assert preview.message
    assert preview.totals.total_ttc == 0
    assert preview.totals.source == "catalog_stock_check"


async def test_bridge_stock_race_returns_explicit_affected_line():
    catalog = SimpleNamespace(products_by_ids=AsyncMock(return_value=[_product(8)]))
    bridge = SimpleNamespace(
        post=AsyncMock(
            side_effect=BridgeHTTPError(
                409,
                "Stock insuffisant ou produit refusé par le panier PrestaShop.",
                body=json.dumps(
                    {
                        "error": {
                            "detail": "product_id=8 product_attribute_id=0 requested=3 available=1"
                        }
                    }
                ),
                code="INSUFFICIENT_STOCK",
            )
        )
    )
    service = CheckoutService(AsyncMock(), catalog, _settings(), bridge)
    service._morocco_country_id = AsyncMock(return_value=144)

    preview = await service.preview(
        CheckoutPreviewIn(lines=[CheckoutLineIn(product_id=8, quantity=3)])
    )

    assert preview.stock_ok is False
    assert preview.lines[0].available is False
    assert preview.lines[0].stock_quantity == 1
    assert preview.lines[0].stock_message == (
        "Stock insuffisant : 1 disponible(s) pour 3 demandé(s)."
    )
    assert preview.totals.source == "prestashop_stock_conflict"
    assert preview.totals.total_ttc == 0


async def test_checkout_batch_lookup_reuses_fresh_detail_cache():
    CatalogService.clear_memory_caches()
    product = _product(9, price=125)
    key = "product:id=9:lang=3:currency=1"
    CatalogService._product_detail_cache[key] = (10**20, product, 10**20)
    ps = AsyncMock()
    try:
        catalog = CatalogService(ps, _settings())
        products = await catalog.products_by_ids(
            [9], language_id=3, currency_id=1
        )
        assert products == [product]
        ps.list_resource.assert_not_awaited()
    finally:
        CatalogService.clear_memory_caches()
