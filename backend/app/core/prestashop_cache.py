from __future__ import annotations

import json
import logging
from typing import Any

try:
    import redis
except ImportError:  # pragma: no cover - optional when tests run without Redis lib
    redis = None  # type: ignore[assignment]


logger = logging.getLogger(__name__)

PRESTASHOP_CACHE_PREFIX = "prestashop:cache:"
PRESTASHOP_CACHE_TTL_SECONDS = 900

_redis_client: Any | None = None


def _client() -> Any | None:
    global _redis_client
    if redis is None:
        return None
    if _redis_client is None:
        _redis_client = redis.Redis(
            host="127.0.0.1",
            port=6379,
            decode_responses=True,
            socket_connect_timeout=0.2,
            socket_timeout=0.2,
        )
    return _redis_client


def cache_key(resource: str, params: dict[str, Any]) -> str:
    normalized_params = json.dumps(
        params,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )
    return f"{PRESTASHOP_CACHE_PREFIX}{resource}:{normalized_params}"


def get_json(key: str) -> Any | None:
    client = _client()
    if client is None:
        return None
    try:
        cached = client.get(key)
        if cached is None:
            return None
        return json.loads(cached)
    except Exception as exc:
        logger.warning("Redis cache read failed for %s: %s", key, exc)
        return None


def set_json(
    key: str,
    value: Any,
    ttl_seconds: int = PRESTASHOP_CACHE_TTL_SECONDS,
) -> None:
    client = _client()
    if client is None:
        return
    try:
        client.setex(
            key,
            ttl_seconds,
            json.dumps(value, ensure_ascii=False, separators=(",", ":")),
        )
    except Exception as exc:
        logger.warning("Redis cache write failed for %s: %s", key, exc)


def clear_prestashop_cache() -> int:
    client = _client()
    if client is None:
        return 0
    deleted = 0
    try:
        cursor = 0
        pattern = f"{PRESTASHOP_CACHE_PREFIX}*"
        while True:
            cursor, keys = client.scan(cursor=cursor, match=pattern, count=500)
            if keys:
                deleted += int(client.delete(*keys))
            if cursor == 0:
                break
    except Exception as exc:
        logger.warning("Redis cache clear failed: %s", exc)
    return deleted
