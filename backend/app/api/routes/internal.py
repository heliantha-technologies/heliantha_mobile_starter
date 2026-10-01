import secrets

from fastapi import APIRouter, Depends, Header, HTTPException

from app.core.config import Settings, get_settings
from app.core.prestashop_cache import clear_prestashop_cache
from app.services.catalog import CatalogService

router = APIRouter(tags=["internal"])


@router.post("/api/internal/cache/clear", response_model=dict)
async def clear_cache(
    x_internal_cache_token: str = Header(default=""),
    settings: Settings = Depends(get_settings),
) -> dict:
    expected = settings.internal_cache_clear_token or settings.mobile_bridge_secret
    if not expected or not secrets.compare_digest(x_internal_cache_token, expected):
        raise HTTPException(status_code=403, detail="Forbidden")

    redis_deleted = clear_prestashop_cache()
    CatalogService.clear_memory_caches()

    return {
        "success": True,
        "data": {
            "redis_deleted": redis_deleted,
            "memory_cleared": True,
        },
        "meta": None,
        "error": None,
    }
