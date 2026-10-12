from __future__ import annotations

import json
import logging
from time import monotonic
from typing import Any

try:
    import redis
except ImportError:  # pragma: no cover - optional when tests run without Redis lib
    redis = None  # type: ignore[assignment]


logger = logging.getLogger(__name__)

PRESTASHOP_CACHE_PREFIX = "prestashop:cache:"
PRESTASHOP_CACHE_TTL_SECONDS = 900
REDIS_FAILURE_COOLDOWN_SECONDS = 30

_redis_client: Any | None = None
_failed_client: Any | None = None
_retry_after = 0.0


def redis_unavailable() -> bool:
    """Report a missing Redis dependency or a client with a known failure."""
    return redis is None or (
        _redis_client is not None and _redis_client is _failed_client
    )


def _client(*, force: bool = False) -> Any | None:
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
    if (
        not force
        and _redis_client is _failed_client
        and monotonic() < _retry_after
    ):
        return None
    return _redis_client


def _mark_failure(client: Any, operation: str, exc: Exception) -> None:
    global _failed_client, _retry_after
    _failed_client = client
    _retry_after = monotonic() + REDIS_FAILURE_COOLDOWN_SECONDS
    logger.warning(
        "Redis cache %s failed; retry in %ds: %s",
        operation,
        REDIS_FAILURE_COOLDOWN_SECONDS,
        exc,
    )


def _mark_success(client: Any) -> None:
    global _failed_client, _retry_after
    if _failed_client is client:
        _failed_client = None
        _retry_after = 0.0


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
    except Exception as exc:
        _mark_failure(client, "read", exc)
        return None
    _mark_success(client)
    if cached is None:
        return None
    try:
        return json.loads(cached)
    except (TypeError, ValueError) as exc:
        logger.warning("Redis cache invalid JSON for %s: %s", key, exc)
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
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError) as exc:
        logger.warning("Redis cache cannot serialize %s: %s", key, exc)
        return
    try:
        client.setex(
            key,
            ttl_seconds,
            encoded,
        )
    except Exception as exc:
        _mark_failure(client, "write", exc)
    else:
        _mark_success(client)


def clear_prestashop_cache() -> int:
    # Cache invalidation must still try Redis during a temporary cooldown.
    client = _client(force=True)
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
        _mark_failure(client, "clear", exc)
    else:
        _mark_success(client)
    return deleted
