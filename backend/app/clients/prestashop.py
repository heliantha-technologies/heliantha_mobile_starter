import asyncio
import logging
from time import monotonic
from typing import Any
from urllib.parse import urljoin

import httpx

from app.core.config import Settings
from app.core.prestashop_cache import cache_key, get_json, set_json


logger = logging.getLogger(__name__)

CACHEABLE_GET_RESOURCES = {
    "categories",
    "currencies",
    "languages",
    "product_feature_values",
    "product_features",
    "products",
    "search",
    "stock_availables",
}


class PrestaShopError(RuntimeError):
    pass


class PrestaShopClient:
    _client: httpx.AsyncClient | None = None
    _client_loop: asyncio.AbstractEventLoop | None = None

    def __init__(self, settings: Settings):
        self.settings = settings
        self.base_url = settings.prestashop_base_url.rstrip("/") + "/"
        self.api_url = urljoin(self.base_url, "api/")
        self.auth = httpx.BasicAuth(settings.prestashop_webservice_key, "")
        self.prestashop_calls = 0
        self.prestashop_time_ms = 0.0

    def _check_config(self) -> None:
        if not self.settings.prestashop_webservice_key:
            raise PrestaShopError(
                "PRESTASHOP_WEBSERVICE_KEY n'est pas configurée."
            )

    async def _request(
        self,
        method: str,
        resource: str,
        *,
        params: dict[str, Any] | None = None,
    ) -> Any:
        self._check_config()
        url = urljoin(self.api_url, resource.lstrip("/"))
        merged_params = {"output_format": "JSON"}
        if params:
            merged_params.update(params)

        redis_cache_key: str | None = None
        if method.upper() == "GET" and self._is_cacheable_get_resource(resource):
            redis_cache_key = cache_key(resource, merged_params)
            cached = get_json(redis_cache_key)
            if cached is not None:
                return cached

        client = self._shared_client()
        start = monotonic()
        response = await client.request(method, url, params=merged_params)
        self.prestashop_calls += 1
        self.prestashop_time_ms += (monotonic() - start) * 1000

        if response.status_code >= 400:
            body = response.text[:800]
            raise PrestaShopError(
                f"PrestaShop {response.status_code} sur {resource}: {body}"
            )

        content_type = response.headers.get("content-type", "")
        if "json" not in content_type.lower():
            raise PrestaShopError(
                "PrestaShop n'a pas renvoyé du JSON. "
                "Vérifier output_format=JSON et la configuration Webservice."
            )
        payload = response.json()
        if redis_cache_key is not None:
            set_json(redis_cache_key, payload)
        return payload

    async def list_resource(
        self,
        resource: str,
        *,
        display: str | None = None,
        filters: dict[str, str] | None = None,
        limit: str | None = None,
        sort: str | None = None,
        params: dict[str, Any] | None = None,
    ) -> Any:
        request_params: dict[str, Any] = {}
        if display:
            request_params["display"] = display
        if filters:
            for key, value in filters.items():
                filter_key = key if key.startswith("filter[") else f"filter[{key}]"
                request_params[filter_key] = value
        if limit:
            request_params["limit"] = limit
        if sort:
            request_params["sort"] = sort
        if params:
            request_params.update(params)
        if resource == "orders":
            logger.info(
                "PrestaShop list_resource resource=%s params=%s",
                resource,
                request_params,
            )
        return await self._request("GET", resource, params=request_params)

    async def get_resource(
        self,
        resource: str,
        resource_id: int,
        *,
        params: dict[str, Any] | None = None,
    ) -> Any:
        return await self._request(
            "GET",
            f"{resource}/{resource_id}",
            params=params,
        )

    async def search(
        self,
        *,
        query: str,
        language_id: int,
    ) -> Any:
        return await self._request(
            "GET",
            "search",
            params={
                "query": query,
                "language": language_id,
            },
        )

    async def get_binary(
        self,
        path: str,
        *,
        headers: dict[str, str] | None = None,
    ) -> tuple[bytes, str, dict[str, str]]:
        self._check_config()
        url = urljoin(self.api_url, path.lstrip("/"))
        client = self._shared_client()
        start = monotonic()
        response = await client.get(url, headers=headers)
        self.prestashop_calls += 1
        self.prestashop_time_ms += (monotonic() - start) * 1000
        if response.status_code >= 400:
            raise PrestaShopError(
                f"Image PrestaShop introuvable ({response.status_code})."
            )
        resp_headers = {k.lower(): v for k, v in response.headers.items()}
        return (
            response.content,
            resp_headers.get("content-type", "image/jpeg"),
            resp_headers,
        )

    def reset_perf(self) -> None:
        self.prestashop_calls = 0
        self.prestashop_time_ms = 0.0

    def _is_cacheable_get_resource(self, resource: str) -> bool:
        root_resource = resource.lstrip("/").split("/", 1)[0]
        return root_resource in CACHEABLE_GET_RESOURCES

    def _shared_client(self) -> httpx.AsyncClient:
        self._check_config()
        try:
            current_loop = asyncio.get_running_loop()
        except RuntimeError:
            current_loop = None

        if (
            self.__class__._client is None
            or self.__class__._client.is_closed
            or (current_loop is not None and self.__class__._client_loop != current_loop)
        ):
            self.__class__._client = httpx.AsyncClient(
                auth=self.auth,
                timeout=httpx.Timeout(
                    self.settings.prestashop_timeout_seconds,
                    connect=5.0,
                    read=self.settings.prestashop_timeout_seconds,
                    write=10.0,
                    pool=5.0,
                ),
                follow_redirects=True,
                limits=httpx.Limits(
                    max_connections=20,
                    max_keepalive_connections=10,
                    keepalive_expiry=30.0,
                ),
            )
            self.__class__._client_loop = current_loop
        return self.__class__._client

    @classmethod
    async def close_shared_client(cls) -> None:
        if cls._client is not None and not cls._client.is_closed:
            await cls._client.aclose()
        cls._client = None
        cls._client_loop = None
