import json
import sqlite3
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_bridge_client, get_checkout_service
from app.clients.bridge import BridgeHTTPError
from app.core.config import get_settings
from app.core.security import create_access_token
from app.main import app


PAYLOAD = {
    "mode": "guest",
    "idempotency_key": "checkout-retry-test-123",
    "lines": [{"product_id": 42, "quantity": 2}],
    "guest": {
        "title": "Mme", "firstname": "Sara", "lastname": "Test",
        "email": "sara@example.com",
    },
    "payment_module": "ps_wirepayment",
}


class PersistedCheckoutBridge:
    """The existing bridge checks its persisted key before any order creation."""

    def __init__(self, database, *, lose_response=False, plural_resources=False):
        self.database = database
        self.lose_response = lose_response
        self.plural_resources = plural_resources
        self.creations = 0
        self.reads = []
        database.execute("CREATE TABLE orders (id INTEGER PRIMARY KEY, key TEXT UNIQUE, payload TEXT)")

    async def post(self, endpoint, body):
        assert endpoint == "checkout?action=confirm"
        row = self.database.execute("SELECT id FROM orders WHERE key = ?", (body["idempotency_key"],)).fetchone()
        if row:
            raise BridgeHTTPError(
                409, "Cette confirmation a déjà été traitée.", code="DUPLICATE_CHECKOUT",
                body=json.dumps({"success": False, "error": {"code": "DUPLICATE_CHECKOUT", "order_id": row[0]}}),
            )
        self.creations += 1
        order = {"id": 123, "id_customer": 9, "reference": "SOLAR123", "total_paid_tax_incl": "45000.00", "module": "ps_wirepayment"}
        self.database.execute("INSERT INTO orders VALUES (?, ?, ?)", (123, body["idempotency_key"], json.dumps(order)))
        self.database.commit()
        if self.lose_response:
            self.lose_response = False
            raise httpx.ReadTimeout("response lost after order commit")
        return {"data": {"order_id": 123, "reference": "SOLAR123", "total": 45000, "currency": "MAD"}}

    async def get_resource(self, resource, resource_id):
        self.reads.append((resource, resource_id))
        if resource == "orders":
            row = self.database.execute("SELECT payload FROM orders WHERE id = ?", (resource_id,)).fetchone()
            value = json.loads(row[0])
        else:
            assert resource == "customers" and resource_id == 9
            value = {"id": 9, "is_guest": 1, "email": "sara@example.com", "firstname": "Sara", "lastname": "Test"}
        return {resource: [value]} if self.plural_resources else {resource[:-1]: value}


@pytest.fixture
def checkout_client():
    service = AsyncMock()
    service._morocco_country_id.return_value = 144
    settings = get_settings().model_copy(update={"checkout_write_enabled": True})
    overrides = dict(app.dependency_overrides)
    app.dependency_overrides[get_checkout_service] = lambda: service
    app.dependency_overrides[get_settings] = lambda: settings
    client = TestClient(app)
    try:
        yield client, service, settings
    finally:
        client.close()
        app.dependency_overrides.clear()
        app.dependency_overrides.update(overrides)


@pytest.mark.parametrize("lose_response", [False, True])
@pytest.mark.parametrize("logged_in", [False, True])
@pytest.mark.parametrize("plural_resources", [False, True])
def test_network_replay_returns_same_order_without_writes(checkout_client, tmp_path, caplog, lose_response, logged_in, plural_resources):
    client, service, settings = checkout_client
    database = sqlite3.connect(tmp_path / "orders.sqlite", check_same_thread=False)
    bridge = PersistedCheckoutBridge(database, lose_response=lose_response, plural_resources=plural_resources)
    service.ps = bridge
    app.dependency_overrides[get_bridge_client] = lambda: bridge
    payload = {**PAYLOAD, "mode": "login" if logged_in else "guest"}
    headers = {}
    if logged_in:
        token = create_access_token(customer_id=9, email="sara@example.com", settings=settings)
        headers["Authorization"] = f"Bearer {token}"
    try:
        with caplog.at_level("INFO"):
            first = client.post("/v1/checkout/confirm", json=payload, headers=headers)
            before = database.execute("SELECT * FROM orders").fetchall()
            second = client.post("/v1/checkout/confirm", json=payload, headers=headers)
        assert first.status_code == (504 if lose_response else 200)
        assert second.status_code == 200
        response = second.json()
        assert response["status"] == "success"
        assert response["order_id"] == 123
        assert response["reference"] == "SOLAR123"
        assert response["is_duplicate_safe"] is True
        assert response["message"] == "Commande confirmée"
        assert response["data"]["reference"] == "SOLAR123"
        assert response["data"]["total"] == 45000
        assert bridge.creations == 1
        assert database.execute("SELECT * FROM orders").fetchall() == before
        assert "Idempotent checkout hit: order SOLAR123 returned safely" in caplog.text
        assert "sara@example.com" not in caplog.text
    finally:
        database.close()


@pytest.mark.parametrize("logged_in", [False, True])
def test_duplicate_cannot_expose_another_customers_order(checkout_client, logged_in):
    client, service, settings = checkout_client
    bridge = AsyncMock()
    bridge.post.side_effect = BridgeHTTPError(409, "Confirmation déjà traitée.", code="DUPLICATE_CHECKOUT",
        body=json.dumps({"error": {"code": "DUPLICATE_CHECKOUT", "order_id": 123}}))
    service.ps.get_resource.side_effect = [
        {"order": {"id": 123, "id_customer": 10, "reference": "PRIVATE"}},
        {"customer": {"id": 10, "is_guest": 1, "email": "other@example.com"}},
    ] if not logged_in else [
        {"customer": {"id": 9, "firstname": "Sara", "lastname": "Test"}},
        {"order": {"id": 123, "id_customer": 10, "reference": "PRIVATE"}},
    ]
    app.dependency_overrides[get_bridge_client] = lambda: bridge
    headers = {}
    if logged_in:
        headers["Authorization"] = "Bearer " + create_access_token(customer_id=9, email="sara@example.com", settings=settings)
    response = client.post("/v1/checkout/confirm", json=PAYLOAD, headers=headers)
    assert response.status_code == 403
    assert "PRIVATE" not in response.text


@pytest.mark.parametrize("code, body", [
    ("INSUFFICIENT_STOCK", {"error": {"code": "INSUFFICIENT_STOCK", "order_id": 123}}),
    ("DUPLICATE_CHECKOUT", {"error": {"code": "DUPLICATE_CHECKOUT"}}),
    ("DUPLICATE_CHECKOUT", {"error": {"code": "DUPLICATE_CHECKOUT", "order_id": "invalid"}}),
])
def test_only_a_valid_duplicate_is_resumed(checkout_client, code, body):
    client, service, _ = checkout_client
    bridge = AsyncMock()
    bridge.post.side_effect = BridgeHTTPError(409, "Veuillez vérifier votre commande.", code=code, body=json.dumps(body))
    app.dependency_overrides[get_bridge_client] = lambda: bridge
    response = client.post("/v1/checkout/confirm", json=PAYLOAD)
    assert response.status_code == 409
    service.ps.get_resource.assert_not_awaited()
