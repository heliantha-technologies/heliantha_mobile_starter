from __future__ import annotations

import json
from unittest.mock import AsyncMock

import pytest

from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings
from app.core import prestashop_cache

pytestmark = pytest.mark.anyio


class FakeRedis:
    def __init__(self):
        self.values: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self.values.get(key)

    def setex(self, key: str, ttl: int, value: str) -> None:
        self.values[key] = value


class FlakyRedis(FakeRedis):
    def __init__(self):
        super().__init__()
        self.fail = True
        self.read_attempts = 0

    def get(self, key: str) -> str | None:
        self.read_attempts += 1
        if self.fail:
            raise TimeoutError("Redis unavailable")
        return super().get(key)


class FakeResponse:
    status_code = 200
    headers = {"content-type": "application/json"}
    text = ""

    def __init__(self, payload: dict):
        self._payload = payload

    def json(self) -> dict:
        return self._payload


def _settings() -> Settings:
    return Settings(
        app_env="development",
        jwt_secret="secret_for_testing_purposes_only_32_chars!",
        prestashop_base_url="https://heliantha.ma",
        prestashop_webservice_key="key",
    )


async def test_get_request_uses_redis_cache(monkeypatch):
    fake_redis = FakeRedis()
    monkeypatch.setattr(prestashop_cache, "_redis_client", fake_redis)
    monkeypatch.setattr(prestashop_cache, "redis", object())

    client = PrestaShopClient(_settings())
    http = AsyncMock()
    http.request = AsyncMock(
        return_value=FakeResponse({"products": [{"id": 10}]})
    )
    monkeypatch.setattr(client, "_shared_client", lambda: http)

    first = await client._request("GET", "products", params={"limit": "0,1"})
    second = await client._request("GET", "products", params={"limit": "0,1"})

    assert first == second == {"products": [{"id": 10}]}
    assert http.request.call_count == 1
    assert list(fake_redis.values.values()) == [
        json.dumps({"products": [{"id": 10}]}, ensure_ascii=False, separators=(",", ":"))
    ]


async def test_non_get_request_bypasses_redis_cache(monkeypatch):
    fake_redis = FakeRedis()
    monkeypatch.setattr(prestashop_cache, "_redis_client", fake_redis)
    monkeypatch.setattr(prestashop_cache, "redis", object())

    client = PrestaShopClient(_settings())
    http = AsyncMock()
    http.request = AsyncMock(
        return_value=FakeResponse({"ok": True})
    )
    monkeypatch.setattr(client, "_shared_client", lambda: http)

    first = await client._request("POST", "orders", params={"x": "1"})
    second = await client._request("POST", "orders", params={"x": "1"})

    assert first == second == {"ok": True}
    assert http.request.call_count == 2
    assert fake_redis.values == {}


async def test_sensitive_get_request_bypasses_redis_cache(monkeypatch):
    fake_redis = FakeRedis()
    monkeypatch.setattr(prestashop_cache, "_redis_client", fake_redis)
    monkeypatch.setattr(prestashop_cache, "redis", object())

    client = PrestaShopClient(_settings())
    http = AsyncMock()
    http.request = AsyncMock(
        return_value=FakeResponse({"orders": [{"id": 10}]})
    )
    monkeypatch.setattr(client, "_shared_client", lambda: http)

    first = await client._request("GET", "orders", params={"filter[id_customer]": "1"})
    second = await client._request("GET", "orders", params={"filter[id_customer]": "1"})

    assert first == second == {"orders": [{"id": 10}]}
    assert http.request.call_count == 2
    assert fake_redis.values == {}


async def test_redis_timeout_is_skipped_until_retry_then_cache_recovers(monkeypatch):
    fake_redis = FlakyRedis()
    now = [100.0]
    monkeypatch.setattr(prestashop_cache, "_redis_client", fake_redis)
    monkeypatch.setattr(prestashop_cache, "_failed_client", None)
    monkeypatch.setattr(prestashop_cache, "_retry_after", 0.0)
    monkeypatch.setattr(prestashop_cache, "monotonic", lambda: now[0])
    monkeypatch.setattr(prestashop_cache, "redis", object())

    client = PrestaShopClient(_settings())
    http = AsyncMock()
    http.request = AsyncMock(
        return_value=FakeResponse({"products": [{"id": 10}]})
    )
    monkeypatch.setattr(client, "_shared_client", lambda: http)

    await client._request("GET", "products/10")
    await client._request("GET", "products/10")
    assert prestashop_cache.redis_unavailable() is True
    assert fake_redis.read_attempts == 1
    assert http.request.call_count == 2

    fake_redis.fail = False
    now[0] += prestashop_cache.REDIS_FAILURE_COOLDOWN_SECONDS + 1
    await client._request("GET", "products/10")
    await client._request("GET", "products/10")
    assert prestashop_cache.redis_unavailable() is False
    assert fake_redis.read_attempts == 3
    assert http.request.call_count == 3
