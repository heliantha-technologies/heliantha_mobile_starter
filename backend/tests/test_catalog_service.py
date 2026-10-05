from app.services.catalog import CatalogService

import pytest

pytestmark = pytest.mark.anyio


class DummySettings:
    prestashop_language_id = 3


class FakePrestaShopClient:
    def __init__(self):
        self.calls = []

    async def list_resource(
        self,
        resource,
        *,
        display=None,
        filters=None,
        limit=None,
        sort=None,
        params=None,
    ):
        self.calls.append(
            (
                "list",
                resource,
                filters or {},
            )
        )

        if resource == "categories":
            return {
                "categories": [
                    {
                        "id": "1",
                        "id_parent": "0",
                        "active": "1",
                        "name": {"language": [{"id": "3", "value": "Racine"}]},
                    },
                    {
                        "id": "2",
                        "id_parent": "1",
                        "active": "1",
                        "name": {"language": [{"id": "3", "value": "Accueil"}]},
                    },
                    {
                        "id": "9",
                        "id_parent": "2",
                        "active": "1",
                        "name": {"language": [{"id": "3", "value": "Batterie"}]},
                    },
                    {
                        "id": "26",
                        "id_parent": "9",
                        "active": "1",
                        "name": {"language": [{"id": "3", "value": "Lithium"}]},
                    },
                    {
                        "id": "27",
                        "id_parent": "9",
                        "active": "1",
                        "name": {"language": [{"id": "3", "value": "Gel"}]},
                    },
                ]
            }

        if resource == "products":
            ids = {
                int(item)
                for item in filters["id"].strip("[]").split("|")
                if item
            } if filters and "id" in filters else None
            products = [
                {
                    "id": "101",
                    "id_category_default": "2",
                    "id_default_image": "501",
                    "reference": "BAT-LITH",
                    "price": "1200",
                    "quantity": "7",
                    "active": "1",
                    "available_for_order": "1",
                    "name": {"language": [{"id": "3", "value": "Batterie lithium"}]},
                    "description_short": "",
                },
                {
                    "id": "102",
                    "id_category_default": "27",
                    "id_default_image": "502",
                    "reference": "BAT-GEL",
                    "price": "900",
                    "quantity": "0",
                    "active": "1",
                    "available_for_order": "1",
                    "name": {"language": [{"id": "3", "value": "Batterie gel"}]},
                    "description_short": "",
                },
            ]
            rows = [
                product for product in products
                if ids is None or int(product["id"]) in ids
            ]
            rows.sort(key=lambda row: int(row["id"]), reverse=True)
            if limit:
                offset, count = map(int, limit.split(","))
                rows = rows[offset:offset + count]
            return {"products": rows}

        if resource == "stock_availables":
            return {
                "stock_availables": [
                    {
                        "id_product": "101",
                        "id_product_attribute": "0",
                        "quantity": "7",
                        "out_of_stock": "0",
                    },
                    {
                        "id_product": "102",
                        "id_product_attribute": "0",
                        "quantity": "0",
                        "out_of_stock": "0",
                    },
                    {
                        "id_product": "100",
                        "id_product_attribute": "0",
                        "quantity": "4",
                        "out_of_stock": "0",
                    },
                ]
            }

        return {}

    async def get_resource(self, resource, resource_id, *, params=None):
        self.calls.append(
            (
                "get",
                resource,
                resource_id,
            )
        )

        category_products = {
            9: [{"id": "101"}],
            26: [{"id": "101"}],
            27: [{"id": "102"}],
        }

        return {
            "category": {
                "id": str(resource_id),
                "associations": {
                    "products": {
                        "product": category_products.get(resource_id, [])
                    }
                },
            }
        }

    async def search(self, *, query, language_id):
        self.calls.append(
            (
                "search",
                "search",
                {
                    "query": query,
                    "language": language_id,
                },
            )
        )
        return {
            "products": [
                {"id_product": "102"},
                {"id_product": "101"},
            ]
        }


def clear_catalog_cache():
    CatalogService.clear_memory_caches()


async def test_parent_category_includes_descendant_products():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    products, meta = await service.products(
        page=1,
        page_size=30,
        category_id=9,
    )

    assert meta["returned"] == 2
    assert [product.id for product in products] == [102, 101]
    assert {
        call for call in ps.calls if call[0] == "get" and call[1] == "categories"
    } == {
        ("get", "categories", 9),
        ("get", "categories", 26),
        ("get", "categories", 27),
    }
    assert len(
        [
            call
            for call in ps.calls
            if call[0] == "list" and call[1] == "stock_availables"
        ]
    ) == 1


async def test_quantity_comes_from_batch_stock_lookup():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    product = await service._product_from_row(
        {
            "id": "100",
            "id_category_default": "9",
            "price": "10",
            "quantity": "0",
            "available_for_order": "1",
            "name": {"language": [{"id": "3", "value": "Produit"}]},
        }
    )

    assert product.quantity == 4
    assert any(call[1] == "stock_availables" for call in ps.calls)


async def test_categories_hide_root_and_home():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    categories = await service.categories()

    assert [category.id for category in categories] == [9, 26, 27]


async def test_search_uses_full_product_resource_instead_of_capped_autocomplete():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    products, meta = await service.products(
        page=1,
        page_size=30,
        q="batterie",
        language_id=3,
    )

    assert meta["returned"] == 2
    assert [product.id for product in products] == [102, 101]
    assert ("list", "products", {"active": "[1]"}) in ps.calls
    assert not any(call[0] == "search" for call in ps.calls)
    assert meta["has_more"] is False


async def test_search_filters_irrelevant_native_results():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    products, meta = await service.products(
        page=1,
        page_size=30,
        q="terme-inexistant",
        language_id=3,
    )

    assert meta["returned"] == 0
    assert products == []


async def test_product_content_uses_short_description_as_commercial_description():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    content = service._split_product_content(
        description_short="<h3>Description :</h3><p>Texte commercial.</p>",
        description=(
            "<h3>Fiche Technique - Trina Solar 400 W</h3>"
            "<ul><li><strong>Pmax :</strong> 400 W</li></ul>"
        ),
    )

    assert content["description"] == (
        "<h3>Description :</h3><p>Texte commercial.</p>"
    )
    assert "Fiche Technique" in content["technical_details"]
    assert "Pmax" in content["technical_details"]


async def test_product_content_splits_long_description_at_technical_heading():
    clear_catalog_cache()
    ps = FakePrestaShopClient()
    service = CatalogService(ps, DummySettings())

    content = service._split_product_content(
        description_short="",
        description=(
            "<h3>Description</h3><p>Texte commercial.</p>"
            "<h3>Caractéristiques techniques</h3>"
            "<p><strong>Vmp :</strong> 31.1 V</p>"
        ),
    )

    assert content["description"] == "<h3>Description</h3><p>Texte commercial.</p>"
    assert content["technical_details"].startswith(
        "<h3>Caractéristiques techniques</h3>"
    )
    assert "Vmp" in content["technical_details"]
