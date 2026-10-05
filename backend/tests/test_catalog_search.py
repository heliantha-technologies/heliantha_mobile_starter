import asyncio
from types import SimpleNamespace

import pytest
from starlette.testclient import TestClient

from app.api.deps import get_catalog_service
from app.main import app
from app.services.catalog import CatalogService, SEARCH_INDEX_DISPLAY
from app.services.catalog_search import normalize_catalog_search


pytestmark = pytest.mark.anyio


def product(product_id, name, *, reference="", description="", active=True):
    return {
        "id": str(product_id), "name": name, "reference": reference,
        "description_short": description, "price": "100", "quantity": "5",
        "active": "1" if active else "0", "available_for_order": "1",
    }


class CatalogClient:
    prestashop_calls = 0
    prestashop_time_ms = 0

    def __init__(self, rows):
        self.rows = rows
        self.calls = []
        self.fail_scan = False
        self.category_memberships = {}

    def reset_perf(self):
        pass

    async def list_resource(self, resource, **options):
        self.calls.append((resource, options))
        # Yield so concurrent searches overlap when testing shared scans.
        await asyncio.sleep(0)
        if resource == "products":
            if self.fail_scan and options.get("display") == SEARCH_INDEX_DISPLAY:
                raise RuntimeError("simulated catalogue outage")
            rows = [row for row in self.rows if row["active"] == "1"]
            ids = options.get("filters", {}).get("id")
            if ids:
                ids = set(ids.strip("[]").split("|"))
                rows = [row for row in rows if row["id"] in ids]
            rows.sort(key=lambda row: int(row["id"]), reverse=True)
            offset, count = map(int, options["limit"].split(","))
            return {"products": rows[offset:offset + count]}
        if resource == "stock_availables":
            return {"stock_availables": [
                {"id_product": row["id"], "id_product_attribute": "0", "quantity": "5"}
                for row in self.rows
            ]}
        if resource == "categories":
            return {"categories": [
                {"id": "9", "id_parent": "2", "active": "1", "name": "Batteries"},
                {"id": "26", "id_parent": "9", "active": "1", "name": "Lithium"},
            ]}
        return {resource: []}

    async def get_resource(self, resource, resource_id, **options):
        assert resource == "categories"
        return {"category": {"id": str(resource_id), "associations": {
            "products": [{"id": str(i)} for i in self.category_memberships.get(resource_id, [])],
        }}}


@pytest.fixture
def make_catalog():
    CatalogService.clear_memory_caches()

    def create(rows):
        client = CatalogClient(rows)
        settings = SimpleNamespace(prestashop_language_id=3, prestashop_base_url="test-shop")
        return CatalogService(client, settings), client

    yield create
    CatalogService.clear_memory_caches()


@pytest.mark.parametrize("left,right", [
    ("câble", "cable"), ("3,6 kW", "3.6kW"), ("10mm²", "10mm2"),
    ("ÉLECTROGÈNE", "electrogene"), ("715 W", "715W"),
])
def test_query_normalization_equivalence(left, right):
    assert normalize_catalog_search(left) == normalize_catalog_search(right)


def test_decimal_power_stays_attached_to_its_unit():
    assert normalize_catalog_search("3,6 kW") == "3.6kw"


@pytest.mark.parametrize("query,expected", [
    ("câble", [315]), ("cable", [315]), ("10mm²", [315]), ("10mm2", [315]),
    ("3,6 kW", [340]), ("3.6kW", [340]), ("PV18-3624 ECO", [340]),
    ("batterie deye", [330, 328]), ("DEYE batterie", [330, 328]),
    ("JA", [339]), ("batterie incompatible", []),
])
async def test_realistic_queries_match_all_terms(make_catalog, query, expected):
    catalog, _ = make_catalog([
        product(315, "Câble KBE 10mm²"),
        product(340, "Onduleur MUST 3.6kW", reference="PV18-3624 ECO"),
        product(339, "Panneau JA Solar 715 W"),
        product(330, "Batterie lithium", reference="DEYE SE-F5"),
        product(328, "Batterie DEYE SE-F12"),
        product(341, "Batterie DEYE inactive", active=False),
    ])
    items, meta = await catalog.products(q=query)
    assert [item.id for item in items] == expected
    assert meta["total"] == len(expected)
    assert meta["has_more"] is False


async def test_search_scans_beyond_one_hundred_and_paginates_without_duplicates(make_catalog):
    catalog, client = make_catalog([
        product(i, f"Batterie {'DEYE' if i <= 2 else 'solaire'} {i}")
        for i in range(1, 126)
    ])
    ids = []
    for page in range(1, 6):
        items, meta = await catalog.products(q="batterie", page=page)
        ids.extend(item.id for item in items)
        assert meta["page_size"] == 30
        assert meta["total"] == 125
        assert meta["has_more"] is (page < 5)
        assert len(items) == (30 if page < 5 else 5)
    assert ids == list(range(125, 0, -1))
    assert {1, 2}.issubset(ids)  # DEYE remains available on later pages.
    scans = [options for resource, options in client.calls
             if resource == "products" and options["display"] == SEARCH_INDEX_DISPLAY]
    assert [options["limit"] for options in scans] == ["0,100", "100,100"]


@pytest.mark.parametrize("query", [None, "batterie"])
async def test_last_full_page_and_empty_next_page_have_no_more(make_catalog, query):
    catalog, _ = make_catalog([product(i, "Batterie") for i in range(1, 61)])
    first, first_meta = await catalog.products(q=query)
    last, last_meta = await catalog.products(q=query, page=2)
    empty, empty_meta = await catalog.products(q=query, page=3)
    assert len(first) == len(last) == 30
    assert first_meta["has_more"] is True
    assert last_meta["has_more"] is False
    assert empty == [] and empty_meta["has_more"] is False


async def test_concurrent_queries_share_the_complete_index(make_catalog):
    catalog, client = make_catalog([product(1, "Batterie DEYE"), product(2, "Câble")])
    results = await asyncio.gather(catalog.products(q="batterie"), catalog.products(q="cable"))
    assert [[item.id for item in items] for items, _ in results] == [[1], [2]]
    assert sum(options.get("display") == SEARCH_INDEX_DISPLAY
               for _, options in client.calls) == 1


async def test_category_search_includes_descendants_beyond_first_ten_hits(make_catalog):
    catalog, client = make_catalog([product(i, "Batterie DEYE") for i in range(1, 41)])
    client.category_memberships = {9: [1], 26: [2]}
    items, meta = await catalog.products(q="batterie", category_id=9, page_size=1)
    last, last_meta = await catalog.products(q="batterie", category_id=9, page_size=1, page=2)
    assert [item.id for item in items] == [2]
    assert [item.id for item in last] == [1]
    assert meta["total"] == 2 and meta["has_more"] is True
    assert last_meta["has_more"] is False


async def test_index_cache_separates_languages_and_expires(make_catalog, monkeypatch):
    catalog, client = make_catalog([product(1, {"language": [
        {"id": "3", "value": "Batterie"}, {"id": "4", "value": "Battery"},
    ]})])
    clock = 1000
    monkeypatch.setattr("app.services.catalog.monotonic", lambda: clock)
    french, _ = await catalog.products(q="batterie", language_id=3)
    english, _ = await catalog.products(q="battery", language_id=4)
    assert [item.id for item in french] == [item.id for item in english] == [1]
    assert sum(options.get("display") == SEARCH_INDEX_DISPLAY
               for _, options in client.calls) == 2
    client.rows.append(product(2, "Batterie DEYE"))
    clock += 61
    refreshed, _ = await catalog.products(q="batterie", language_id=3)
    assert [item.id for item in refreshed] == [2, 1]


async def test_failed_scan_is_not_cached_and_retry_recovers(make_catalog):
    catalog, client = make_catalog([product(1, "Batterie DEYE")])
    client.fail_scan = True
    with pytest.raises(RuntimeError, match="outage"):
        await catalog.products(q="batterie")
    client.fail_scan = False
    items, meta = await catalog.products(q="batterie")
    assert [item.id for item in items] == [1]
    assert meta["has_more"] is False


def test_products_route_exposes_pagination_and_preserves_legacy_data(make_catalog):
    catalog, _ = make_catalog([product(i, "Batterie DEYE") for i in range(1, 32)])
    app.dependency_overrides[get_catalog_service] = lambda: catalog
    try:
        with TestClient(app) as client:
            first = client.get("/v1/products", params={"q": "batterie"})
            last = client.get("/v1/products", params={"q": "batterie", "page": 2})
        assert first.status_code == last.status_code == 200
        assert len(first.json()["items"]) == 30
        assert first.json()["items"] == first.json()["data"]
        assert first.json()["page"] == 1 and first.json()["has_more"] is True
        assert last.json()["page"] == 2 and last.json()["has_more"] is False
        assert last.json()["items"][0]["id"] == 1
    finally:
        app.dependency_overrides.pop(get_catalog_service, None)
