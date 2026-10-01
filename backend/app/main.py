from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    addresses,
    auth,
    catalog,
    checkout,
    favorites,
    health,
    internal,
    notifications,
    orders,
)
from app.clients.bridge import PrestaShopBridgeClient
from app.clients.prestashop import PrestaShopClient
from app.core.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "CHECKOUT_WRITE_ENABLED loaded = %s",
        settings.checkout_write_enabled,
    )
    try:
        PrestaShopClient(settings)._shared_client()
    except Exception:
        pass
    try:
        PrestaShopBridgeClient(settings)._shared_client()
    except Exception:
        pass
    yield
    await PrestaShopClient.close_shared_client()
    await PrestaShopBridgeClient.close_shared_client()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
    description=(
        "API intermédiaire sécurisée entre l'application Flutter Heliantha "
        "et la boutique PrestaShop."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "X-Requested-With",
        "X-Idempotency-Key",
        "X-Webhook-Secret",
        "If-None-Match",
    ],
    expose_headers=["ETag", "Cache-Control", "Content-Length"],
)

app.include_router(health.router)
app.include_router(internal.router)
app.include_router(addresses.router, prefix=settings.api_prefix)
app.include_router(catalog.router, prefix=settings.api_prefix)
app.include_router(checkout.router, prefix=settings.api_prefix)
app.include_router(auth.router, prefix=settings.api_prefix)
app.include_router(orders.router, prefix=settings.api_prefix)
app.include_router(notifications.router, prefix=settings.api_prefix)
app.include_router(favorites.router, prefix=settings.api_prefix)


@app.get("/")
async def root() -> dict:
    return {
        "name": settings.app_name,
        "docs": "/docs",
        "health": "/health",
    }
