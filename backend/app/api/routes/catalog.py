import hashlib
import logging
from time import monotonic

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response

from app.api.deps import (
    get_catalog_service,
    get_home_slides_service,
    get_ps_client,
    get_store_context_service,
)
from app.clients.prestashop import PrestaShopClient, PrestaShopError
from app.core.single_flight import single_flight
from app.services.catalog import CatalogService
from app.services.home_slides import HomeSlidesService
from app.services.store_context import StoreContextService

router = APIRouter(tags=["catalogue"])
logger = logging.getLogger("heliantha.perf")


@router.get("/home/slides", response_model=dict)
async def home_slides(
    service: HomeSlidesService = Depends(get_home_slides_service),
) -> dict:
    service.catalog.ps.reset_perf()
    start = monotonic()
    try:
        slides = await service.slides()
        _log_perf(
            "home_slides",
            start,
            service.catalog.ps,
            cache="",
        )
        return {
            "success": True,
            "data": [slide.model_dump() for slide in slides],
            "meta": {"total": len(slides)},
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/home")
async def home(
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        categories = await catalog.categories(limit=12)
        products, meta = await catalog.products(page=1, page_size=12)
        _log_perf(
            "home",
            start,
            catalog.ps,
            cache=str(meta.get("cache", "")),
        )
        return {
            "success": True,
            "data": {
                "categories": [x.model_dump() for x in categories],
                "products": [x.model_dump() for x in products],
            },
            "meta": meta,
            "error": None,
        }
    except (PrestaShopError, ValueError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/categories", response_model=dict)
async def categories(
    language_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        rows = await catalog.categories(language_id=language_id)
        _log_perf("categories", start, catalog.ps, cache="")
        return {
            "success": True,
            "data": [x.model_dump() for x in rows],
            "meta": {"total": len(rows)},
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/products", response_model=dict)
async def products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=100),
    category: int | None = Query(default=None, ge=1),
    q: str | None = Query(default=None, max_length=120),
    language_id: int | None = Query(default=None, ge=1),
    currency_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        rows, meta = await catalog.products(
            page=page,
            page_size=page_size,
            category_id=category,
            q=q,
            language_id=language_id,
            currency_id=currency_id,
        )
        _log_perf(
            "products",
            start,
            catalog.ps,
            cache=str(meta.get("cache", "")),
        )
        items = [x.model_dump() for x in rows]
        return {
            "success": True,
            "items": items,
            "page": meta["page"],
            "has_more": meta["has_more"],
            # Preserve the existing envelope for other catalogue consumers.
            "data": items,
            "meta": meta,
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/products/{product_id}", response_model=dict)
async def product(
    product_id: int,
    language_id: int | None = Query(default=None, ge=1),
    currency_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        row = await catalog.product(
            product_id,
            language_id=language_id,
            currency_id=currency_id,
        )
        _log_perf("product_detail", start, catalog.ps, cache="")
        return {
            "success": True,
            "data": row.model_dump(),
            "meta": None,
            "error": None,
        }
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/store-context", response_model=dict)
async def store_context(
    service: StoreContextService = Depends(get_store_context_service),
) -> dict:
    service.ps.reset_perf()
    start = monotonic()
    try:
        context = await service.context()
        _log_perf("store_context", start, service.ps, cache="")
        return {
            "success": True,
            "data": context.model_dump(),
            "meta": None,
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


IMAGE_CACHE_TTL_SECONDS = 300
IMAGE_CACHE_MAX_ENTRIES = 100
_image_cache: dict[str, tuple[float, bytes, str, str]] = {}


@router.get("/products/{product_id}/image")
async def product_image(
    request: Request,
    product_id: int,
    image_id: int | None = None,
    ps: PrestaShopClient = Depends(get_ps_client),
) -> Response:
    ps.reset_perf()
    start = monotonic()
    path = (
        f"images/products/{product_id}/{image_id}"
        if image_id
        else f"images/products/{product_id}"
    )

    now = monotonic()
    cached = _image_cache.get(path)

    # 1. Vérification Cache Mémoire local
    if cached and cached[0] > now:
        _, content, content_type, etag = cached
        if_none_match = request.headers.get("if-none-match")
        if if_none_match and if_none_match.strip('"') == etag.strip('"'):
            _log_perf("product_image", start, ps, cache="hit-304")
            return Response(
                status_code=304,
                headers={
                    "ETag": etag,
                    "Cache-Control": "public, max-age=300",
                },
            )
        _log_perf("product_image", start, ps, cache="hit-200")
        return Response(
            content=content,
            media_type=content_type,
            headers={
                "ETag": etag,
                "Cache-Control": "public, max-age=300",
                "Content-Length": str(len(content)),
            },
        )

    # 2. Coalescing anti-stampede lors d'un cache miss
    async def _fetch() -> tuple[float, bytes, str, str]:
        now_inner = monotonic()
        cached_inner = _image_cache.get(path)
        if cached_inner and cached_inner[0] > now_inner:
            return cached_inner

        content, content_type, headers = await ps.get_binary(path)
        if not content or not content_type.lower().startswith("image/"):
            raise PrestaShopError(
                f"Image PrestaShop invalide pour {path}: "
                f"content_type={content_type!r} bytes={len(content)}"
            )
        sha1 = headers.get("content-sha1")
        if not sha1:
            sha1 = hashlib.sha1(content).hexdigest()
        etag = f'"{sha1}"'

        # Éviction LRU si limite atteinte
        if len(_image_cache) >= IMAGE_CACHE_MAX_ENTRIES:
            oldest = min(_image_cache.keys(), key=lambda k: _image_cache[k][0])
            _image_cache.pop(oldest, None)

        entry = (now_inner + IMAGE_CACHE_TTL_SECONDS, content, content_type, etag)
        _image_cache[path] = entry
        return entry

    try:
        _, content, content_type, etag = await single_flight.execute(f"image:{path}", _fetch)
    except PrestaShopError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    if_none_match = request.headers.get("if-none-match")
    if if_none_match and if_none_match.strip('"') == etag.strip('"'):
        _log_perf("product_image", start, ps, cache="miss-304")
        return Response(
            status_code=304,
            headers={
                "ETag": etag,
                "Cache-Control": "public, max-age=300",
            },
        )

    _log_perf("product_image", start, ps, cache="miss-200")
    return Response(
        content=content,
        media_type=content_type,
        headers={
            "ETag": etag,
            "Cache-Control": "public, max-age=300",
            "Content-Length": str(len(content)),
        },
    )


def _log_perf(
    name: str,
    start: float,
    ps: PrestaShopClient,
    *,
    cache: str,
) -> None:
    total_ms = (monotonic() - start) * 1000
    prestashop_ms = ps.prestashop_time_ms
    normalize_ms = max(0.0, total_ms - prestashop_ms)
    cache_part = f" cache={cache}" if cache else ""
    logger.warning(
        "PERF %s total=%dms prestashop=%dms normalize=%dms calls=%d%s",
        name,
        round(total_ms),
        round(prestashop_ms),
        round(normalize_ms),
        ps.prestashop_calls,
        cache_part,
    )
