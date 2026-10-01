from __future__ import annotations

from time import monotonic
from typing import Any

from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings
from app.core.single_flight import single_flight
from app.schemas.product import (
    CategoryOut,
    ProductFeatureOut,
    ProductOut,
)
from app.schemas.store import CurrencyOut
from app.services.store_context import StoreContextService
from app.services.normalizers import (
    localized,
    to_bool,
    to_float,
    to_int,
    unwrap_collection,
    unwrap_single,
)


PRODUCT_LIST_DISPLAY = (
    "["
    "id,"
    "id_category_default,"
    "id_default_image,"
    "id_manufacturer,"
    "reference,"
    "price,"
    "quantity,"
    "active,"
    "available_for_order,"
    "name,"
    "description_short"
    "]"
)

CATEGORY_LIST_DISPLAY = "[id,id_parent,name,active,position]"
CATEGORY_CACHE_TTL_SECONDS = 300
CATEGORY_PRODUCT_CACHE_TTL_SECONDS = 300
PRODUCT_CACHE_TTL_SECONDS = 20
SEARCH_CACHE_TTL_SECONDS = 25
PRODUCT_STALE_TTL_SECONDS = 30
PRODUCT_DETAIL_CACHE_TTL_SECONDS = 20
HIDDEN_CATEGORY_IDS = {1, 2}
PRODUCT_ID_BATCH_SIZE = 80


class CatalogService:
    _category_rows_cache: dict[int, tuple[float, list[dict[str, Any]]]] = {}
    _category_product_ids_cache: dict[int, tuple[float, list[int]]] = {}
    _products_cache: dict[
        str,
        tuple[float, float, list[ProductOut], dict[str, Any]],
    ] = {}
    _product_detail_cache: dict[
        str,
        tuple[float, ProductOut],
    ] = {}

    def __init__(
        self,
        ps: PrestaShopClient,
        settings: Settings,
        store_context: StoreContextService | None = None,
    ):
        self.ps = ps
        self.settings = settings
        self.store_context = store_context or StoreContextService(
            ps,
            settings,
        )

    @classmethod
    def clear_memory_caches(cls) -> None:
        cls._category_rows_cache.clear()
        cls._category_product_ids_cache.clear()
        cls._products_cache.clear()
        cls._product_detail_cache.clear()

    # ---------------------------------------------------------
    # CATEGORIES
    # ---------------------------------------------------------

    async def categories(
        self,
        limit: int = 100,
        language_id: int | None = None,
    ) -> list[CategoryOut]:

        effective_language_id = self._language_id(language_id)
        rows = await self._active_category_rows(
            effective_language_id,
        )

        result: list[CategoryOut] = []

        for row in rows:
            category_id = to_int(
                row.get("id"),
            )

            if category_id in HIDDEN_CATEGORY_IDS:
                continue

            name = localized(
                row.get("name"),
                effective_language_id,
            ).strip()

            if not category_id:
                continue

            if not name:
                continue

            result.append(
                CategoryOut(
                    id=category_id,
                    name=name,
                    active=True,
                )
            )

            if len(result) >= limit:
                break

        return result

    # ---------------------------------------------------------
    # LISTE PRODUITS
    # ---------------------------------------------------------

    async def products(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        category_id: int | None = None,
        q: str | None = None,
        language_id: int | None = None,
        currency_id: int | None = None,
    ) -> tuple[list[ProductOut], dict[str, Any]]:

        effective_language_id = self._language_id(language_id)
        query = q.strip() if q and q.strip() else None
        cache_key = self._products_cache_key(
            page=page,
            page_size=page_size,
            category_id=category_id,
            query=query,
            language_id=effective_language_id,
            currency_id=currency_id,
        )
        cached = self._read_products_cache(cache_key)
        if cached is not None:
            return cached

        async def _fetch():
            cached_inner = self._read_products_cache(cache_key)
            if cached_inner is not None:
                return cached_inner

            offset = max(
                0,
                (page - 1) * page_size,
            )

            if query:
                products, meta = await self._products_for_search(
                    query=query,
                    category_id=category_id,
                    page=page,
                    page_size=page_size,
                    language_id=effective_language_id,
                    currency_id=currency_id,
                )
                return self._write_products_cache(
                    cache_key,
                    products,
                    meta,
                    SEARCH_CACHE_TTL_SECONDS,
                )

            if category_id is not None:
                products, meta = await self._products_for_category(
                    category_id=category_id,
                    page=page,
                    page_size=page_size,
                    language_id=effective_language_id,
                    currency_id=currency_id,
                )
                return self._write_products_cache(
                    cache_key,
                    products,
                    meta,
                    PRODUCT_CACHE_TTL_SECONDS,
                )

            filters: dict[str, str] = {
                "active": "[1]",
            }

            payload = await self.ps.list_resource(
                "products",
                display=PRODUCT_LIST_DISPLAY,
                filters=filters,
                limit=f"{offset},{page_size}",
                sort="[id_DESC]",
                params={"language": effective_language_id},
            )

            rows = unwrap_collection(
                payload,
                "products",
            )

            stock_by_product = await self._stock_for_products(
                [to_int(row.get("id")) for row in rows],
            )
            currency = await self.store_context.currency_for(currency_id)
            products: list[ProductOut] = []

            for row in rows:
                product = await self._product_from_row(
                    row,
                    stock=stock_by_product.get(to_int(row.get("id"))),
                    language_id=effective_language_id,
                    currency_id=currency_id,
                    currency=currency,
                )

                products.append(product)

            return self._write_products_cache(
                cache_key,
                products,
                {
                    "page": page,
                    "page_size": page_size,
                    "returned": len(products),
                },
                PRODUCT_CACHE_TTL_SECONDS,
            )

        return await single_flight.execute(f"products:{cache_key}", _fetch)

    async def products_by_ids(
        self,
        product_ids: list[int],
        *,
        language_id: int | None = None,
        currency_id: int | None = None,
    ) -> list[ProductOut]:
        clean_ids = [
            product_id
            for product_id in dict.fromkeys(product_ids)
            if product_id
        ]
        if not clean_ids:
            return []

        effective_language_id = self._language_id(language_id)
        payload = await self.ps.list_resource(
            "products",
            display=PRODUCT_LIST_DISPLAY,
            filters={
                "id": "[" + "|".join(str(product_id) for product_id in clean_ids) + "]",
                "active": "[1]",
            },
            limit=f"0,{len(clean_ids)}",
            params={"language": effective_language_id},
        )
        rows = unwrap_collection(payload, "products")
        stock_by_product = await self._stock_for_products(
            [to_int(row.get("id")) for row in rows],
        )
        currency = await self.store_context.currency_for(currency_id)

        products = [
            await self._product_from_row(
                row,
                stock=stock_by_product.get(to_int(row.get("id"))),
                language_id=effective_language_id,
                currency_id=currency_id,
                currency=currency,
            )
            for row in rows
        ]
        by_id = {product.id: product for product in products}
        return [by_id[product_id] for product_id in clean_ids if product_id in by_id]

    async def category_ids_for_product(
        self,
        product_id: int,
        *,
        language_id: int | None = None,
    ) -> set[int]:
        effective_language_id = self._language_id(language_id)
        payload = await self.ps.get_resource(
            "products",
            product_id,
            params={"language": effective_language_id},
        )
        row = unwrap_single(payload, "products")
        if not row and isinstance(payload, dict):
            row = payload.get("product", {})

        category_ids: set[int] = set()
        default_category = to_int(row.get("id_category_default"))
        if default_category:
            category_ids.add(default_category)

        associations = row.get("associations")
        if isinstance(associations, dict):
            categories = associations.get("categories")
            if isinstance(categories, dict):
                categories = categories.get("category", categories)
            if isinstance(categories, dict):
                categories = [categories]
            if isinstance(categories, list):
                for category in categories:
                    if not isinstance(category, dict):
                        continue
                    category_id = to_int(category.get("id"))
                    if category_id:
                        category_ids.add(category_id)

        return category_ids

    async def _products_for_category(
        self,
        *,
        category_id: int,
        page: int,
        page_size: int,
        language_id: int,
        currency_id: int | None,
    ) -> tuple[list[ProductOut], dict[str, Any]]:

        offset = max(
            0,
            (page - 1) * page_size,
        )

        category_ids = await self._category_with_descendants(
            category_id,
            language_id,
        )
        product_ids = await self._product_ids_for_categories(
            category_ids,
            language_id,
        )

        if not product_ids:
            return [], {
                "page": page,
                "page_size": page_size,
                "returned": 0,
            }

        rows = await self._product_rows_for_ids(
            product_ids,
            language_id=language_id,
        )

        rows.sort(
            key=lambda row: to_int(row.get("id")),
            reverse=True,
        )

        page_rows = rows[offset: offset + page_size]
        stock_by_product = await self._stock_for_products(
            [to_int(row.get("id")) for row in page_rows],
        )
        currency = await self.store_context.currency_for(currency_id)
        products = [
            await self._product_from_row(
                row,
                stock=stock_by_product.get(to_int(row.get("id"))),
                language_id=language_id,
                currency_id=currency_id,
                currency=currency,
            )
            for row in page_rows
        ]

        return products, {
            "page": page,
            "page_size": page_size,
            "returned": len(products),
        }

    async def _products_for_search(
        self,
        *,
        query: str,
        category_id: int | None,
        page: int,
        page_size: int,
        language_id: int,
        currency_id: int | None,
    ) -> tuple[list[ProductOut], dict[str, Any]]:

        offset = max(
            0,
            (page - 1) * page_size,
        )

        search_product_ids = await self._search_product_ids(
            query=query,
            language_id=language_id,
        )

        if category_id is not None:
            category_ids = await self._category_with_descendants(
                category_id,
                language_id,
            )
            category_product_ids = set(
                await self._product_ids_for_categories(
                    category_ids,
                    language_id,
                )
            )
            product_ids = [
                product_id
                for product_id in search_product_ids
                if product_id in category_product_ids
            ]
        else:
            product_ids = search_product_ids

        if not product_ids:
            return [], {
                "page": page,
                "page_size": page_size,
                "returned": 0,
            }

        rows = await self._product_rows_for_ids(
            product_ids,
            language_id=language_id,
        )
        rows = self._filter_rows_matching_query(
            rows,
            query,
            language_id,
        )

        by_id = {
            to_int(row.get("id")): row
            for row in rows
        }
        ordered_rows = [
            by_id[product_id]
            for product_id in product_ids
            if product_id in by_id
        ]

        page_rows = ordered_rows[offset: offset + page_size]
        stock_by_product = await self._stock_for_products(
            [to_int(row.get("id")) for row in page_rows],
        )
        currency = await self.store_context.currency_for(currency_id)
        products = [
            await self._product_from_row(
                row,
                stock=stock_by_product.get(to_int(row.get("id"))),
                language_id=language_id,
                currency_id=currency_id,
                currency=currency,
            )
            for row in page_rows
        ]

        return products, {
            "page": page,
            "page_size": page_size,
            "returned": len(products),
        }

    async def _search_product_ids(
        self,
        *,
        query: str,
        language_id: int,
    ) -> list[int]:

        payload = await self.ps.search(
            query=query,
            language_id=language_id,
        )

        rows = unwrap_collection(payload, "products")

        if not rows and isinstance(payload, dict):
            products = payload.get("product")
            if isinstance(products, list):
                rows = [
                    row for row in products
                    if isinstance(row, dict)
                ]
            elif isinstance(products, dict):
                rows = [products]

        product_ids: list[int] = []
        seen: set[int] = set()

        for row in rows:
            product_id = (
                to_int(row.get("id_product"))
                or to_int(row.get("id"))
            )

            if not product_id or product_id in seen:
                continue

            seen.add(product_id)
            product_ids.append(product_id)

        return product_ids

    def _filter_rows_matching_query(
        self,
        rows: list[dict[str, Any]],
        query: str,
        language_id: int,
    ) -> list[dict[str, Any]]:

        terms = [
            term.lower()
            for term in query.replace("-", " ").split()
            if term.strip()
        ]

        if not terms:
            return rows

        filtered: list[dict[str, Any]] = []

        for row in rows:
            haystack = " ".join(
                [
                    localized(row.get("name"), language_id),
                    str(row.get("reference") or ""),
                    localized(row.get("description_short"), language_id),
                ]
            ).lower()

            if all(term in haystack for term in terms):
                filtered.append(row)

        return filtered

    async def _active_category_rows(
        self,
        language_id: int,
    ) -> list[dict[str, Any]]:
        now = monotonic()
        cached = self.__class__._category_rows_cache.get(language_id)

        if cached and cached[0] > now:
            return list(cached[1])

        async def _fetch() -> list[dict[str, Any]]:
            now_inner = monotonic()
            cached_inner = self.__class__._category_rows_cache.get(language_id)
            if cached_inner and cached_inner[0] > now_inner:
                return list(cached_inner[1])

            payload = await self.ps.list_resource(
                "categories",
                display=CATEGORY_LIST_DISPLAY,
                limit="0,1000",
                params={"language": language_id},
            )

            rows = [
                row for row in unwrap_collection(payload, "categories")
                if to_bool(row.get("active"), True)
            ]

            self.__class__._category_rows_cache[language_id] = (
                now_inner + CATEGORY_CACHE_TTL_SECONDS,
                rows,
            )
            return list(rows)

        return await single_flight.execute(f"categories:{language_id}", _fetch)

    async def _category_with_descendants(
        self,
        category_id: int,
        language_id: int,
    ) -> list[int]:

        rows = await self._active_category_rows(language_id)
        children_by_parent: dict[int, list[int]] = {}

        for row in rows:
            child_id = to_int(row.get("id"))
            parent_id = to_int(row.get("id_parent"))

            if not child_id:
                continue

            children_by_parent.setdefault(
                parent_id,
                [],
            ).append(child_id)

        result: list[int] = []
        seen: set[int] = set()
        pending = [category_id]

        while pending:
            current = pending.pop(0)

            if current in seen:
                continue

            seen.add(current)
            result.append(current)
            pending.extend(
                children_by_parent.get(current, [])
            )

        return result

    async def _product_ids_for_categories(
        self,
        category_ids: list[int],
        language_id: int,
    ) -> list[int]:

        product_ids: list[int] = []
        seen: set[int] = set()

        for category_id in category_ids:
            for product_id in await self._product_ids_for_category(
                category_id,
                language_id,
            ):
                if product_id in seen:
                    continue

                seen.add(product_id)
                product_ids.append(product_id)

        return product_ids

    async def _product_ids_for_category(
        self,
        category_id: int,
        language_id: int,
    ) -> list[int]:

        now = monotonic()
        cached = self.__class__._category_product_ids_cache.get(
            category_id,
        )

        if cached and cached[0] > now:
            return list(cached[1])

        payload = await self.ps.get_resource(
            "categories",
            category_id,
            params={"language": language_id},
        )

        row = unwrap_single(payload, "categories")

        if not row and isinstance(payload, dict):
            row = payload.get("category", {})

        product_ids = self._product_ids_from_category_row(
            row,
        )

        self.__class__._category_product_ids_cache[category_id] = (
            now + CATEGORY_PRODUCT_CACHE_TTL_SECONDS,
            product_ids,
        )

        return list(product_ids)

    def _product_ids_from_category_row(
        self,
        row: dict[str, Any],
    ) -> list[int]:

        associations = row.get("associations")

        if not isinstance(associations, dict):
            return []

        products = associations.get("products")

        if isinstance(products, dict):
            products = products.get("product", products)

        if isinstance(products, dict):
            products = [products]

        if not isinstance(products, list):
            return []

        output: list[int] = []

        for product in products:
            if not isinstance(product, dict):
                continue

            product_id = to_int(product.get("id"))

            if product_id:
                output.append(product_id)

        return output

    async def _product_rows_for_ids(
        self,
        product_ids: list[int],
        *,
        language_id: int,
    ) -> list[dict[str, Any]]:

        rows: list[dict[str, Any]] = []

        for index in range(
            0,
            len(product_ids),
            PRODUCT_ID_BATCH_SIZE,
        ):
            batch = product_ids[
                index: index + PRODUCT_ID_BATCH_SIZE
            ]

            filters: dict[str, str] = {
                "active": "[1]",
                "id": (
                    "["
                    + "|".join(str(product_id) for product_id in batch)
                    + "]"
                ),
            }

            payload = await self.ps.list_resource(
                "products",
                display=PRODUCT_LIST_DISPLAY,
                filters=filters,
                limit=f"0,{len(batch)}",
                sort="[id_DESC]",
                params={"language": language_id},
            )

            rows.extend(
                unwrap_collection(payload, "products")
            )

        return rows

    # ---------------------------------------------------------
    # FICHE PRODUIT
    # ---------------------------------------------------------

    async def product(
        self,
        product_id: int,
        language_id: int | None = None,
        currency_id: int | None = None,
    ) -> ProductOut:

        effective_language_id = self._language_id(language_id)
        cache_key = (
            f"product:id={product_id}:lang={effective_language_id}:"
            f"currency={currency_id or ''}"
        )
        cached = self.__class__._product_detail_cache.get(cache_key)
        if cached and cached[0] > monotonic():
            return cached[1]

        async def _fetch() -> ProductOut:
            cached_inner = self.__class__._product_detail_cache.get(cache_key)
            if cached_inner and cached_inner[0] > monotonic():
                return cached_inner[1]

            payload = await self.ps.get_resource(
                "products",
                product_id,
                params={"language": effective_language_id},
            )

            row = unwrap_single(
                payload,
                "products",
            )
            if not row and isinstance(payload, dict):
                row = payload.get("product", {})

            if not row:
                raise ValueError("Produit introuvable.")

            product = await self._product_from_row(
                row,
                detailed=True,
                stock=(
                    await self._stock_for_products([product_id])
                ).get(product_id),
                language_id=effective_language_id,
                currency_id=currency_id,
            )

            self.__class__._product_detail_cache[cache_key] = (
                monotonic() + PRODUCT_DETAIL_CACHE_TTL_SECONDS,
                product,
            )
            return product

        return await single_flight.execute(f"product:{cache_key}", _fetch)

    # ---------------------------------------------------------
    # NORMALISATION PRODUIT
    # ---------------------------------------------------------

    async def _product_from_row(
        self,
        row: dict[str, Any],
        detailed: bool = False,
        stock: dict[str, Any] | None = None,
        language_id: int | None = None,
        currency_id: int | None = None,
        currency: CurrencyOut | None = None,
    ) -> ProductOut:

        effective_language_id = self._language_id(language_id)

        product_id = to_int(
            row.get("id"),
        )

        if stock is None:
            stock = await self._stock_for_product(product_id)

        quantity = (
            to_int(stock.get("quantity"))
            if stock and stock.get("quantity") is not None
            else None
        )
        out_of_stock = (
            to_int(stock.get("out_of_stock"), 0)
            if stock
            else 0
        )

        main_image_id = self._main_image_id(
            row,
        )

        image_url: str | None = None

        if main_image_id:
            image_url = (
                f"/v1/products/"
                f"{product_id}/image"
                f"?image_id={main_image_id}"
            )

        features: list[
            ProductFeatureOut
        ] = []

        if detailed:
            features = (
                await self._features_for_product(
                    row,
                )
            )

        description_short = localized(
            row.get("description_short"),
            effective_language_id,
        ).strip()

        description: str | None = None
        technical_details: str | None = None

        if detailed:
            description_value = localized(
                row.get("description"),
                effective_language_id,
            ).strip()

            split_content = self._split_product_content(
                description_short=description_short,
                description=description_value,
            )
            description = split_content["description"]
            technical_details = split_content["technical_details"]

        price = to_float(
            row.get("price"),
        )
        if currency is None:
            currency = await self.store_context.currency_for(currency_id)

        if currency is not None:
            price = price * currency.conversion_rate

        return ProductOut(
            id=product_id,

            name=localized(
                row.get("name"),
                effective_language_id,
            ).strip(),

            reference=(
                str(
                    row.get("reference")
                    or ""
                ).strip()
                or None
            ),

            price=price,

            currency=currency.iso_code if currency else "MAD",

            currency_symbol=currency.symbol if currency else "MAD",

            currency_id=currency.id if currency else None,

            available=self._available(
                available_for_order=row.get("available_for_order"),
                quantity=quantity,
                out_of_stock=out_of_stock,
            ),

            quantity=quantity,

            description_short=(
                description_short
                or None
            ),

            description=description,

            technical_details=technical_details,

            category_id=(
                to_int(
                    row.get(
                        "id_category_default"
                    )
                )
                or None
            ),

            image_url=image_url,

            features=features,
        )

    def _split_product_content(
        self,
        *,
        description_short: str,
        description: str,
    ) -> dict[str, str | None]:
        description_part = description_short or None
        technical_part: str | None = None

        if description:
            split = self._split_html_at_technical_heading(description)
            if split is not None:
                before, technical = split
                if not description_part and before.strip():
                    description_part = before.strip()
                technical_part = technical.strip() or None
            elif self._html_starts_with_technical_heading(description):
                technical_part = description
            elif not description_part:
                description_part = description

        return {
            "description": description_part,
            "technical_details": technical_part,
        }

    def _split_html_at_technical_heading(
        self,
        html: str,
    ) -> tuple[str, str] | None:
        import re

        heading_pattern = re.compile(
            r"<h[1-4]\b[^>]*>.*?</h[1-4]>",
            re.IGNORECASE | re.DOTALL,
        )
        for match in heading_pattern.finditer(html):
            if self._is_technical_heading(match.group(0)):
                return html[: match.start()], html[match.start() :]
        return None

    def _html_starts_with_technical_heading(
        self,
        html: str,
    ) -> bool:
        import re

        match = re.match(
            r"\s*<h[1-4]\b[^>]*>.*?</h[1-4]>",
            html,
            re.IGNORECASE | re.DOTALL,
        )
        return bool(match and self._is_technical_heading(match.group(0)))

    def _is_technical_heading(
        self,
        heading_html: str,
    ) -> bool:
        import re
        from html import unescape

        text = unescape(re.sub(r"<[^>]+>", " ", heading_html))
        text = re.sub(r"\s+", " ", text).strip().lower()
        technical_titles = (
            "fiche technique",
            "caractéristiques techniques",
            "caracteristiques techniques",
            "spécifications techniques",
            "specifications techniques",
            "spécifications",
            "specifications",
        )
        return any(title in text for title in technical_titles)

    # ---------------------------------------------------------
    # STOCK
    # ---------------------------------------------------------

    async def _stock_for_product(
        self,
        product_id: int,
    ) -> dict[str, Any] | None:
        return (
            await self._stock_for_products([product_id])
        ).get(product_id)

    async def _stock_for_products(
        self,
        product_ids: list[int],
    ) -> dict[int, dict[str, Any]]:

        clean_ids = [
            product_id
            for product_id in dict.fromkeys(product_ids)
            if product_id
        ]

        if not clean_ids:
            return {}

        try:
            payload = (
                await self.ps.list_resource(
                    "stock_availables",
                    display=(
                        "["
                        "id_product,"
                        "id_product_attribute,"
                        "quantity,"
                        "out_of_stock"
                        "]"
                    ),
                    filters={
                        "id_product":
                            "["
                            + "|".join(str(product_id) for product_id in clean_ids)
                            + "]"
                    },
                    limit=f"0,{max(100, len(clean_ids) * 4)}",
                )
            )

            rows = unwrap_collection(
                payload,
                "stock_availables",
            )

            if not rows:
                return {}

            general: dict[int, dict[str, Any]] = {}
            variants: dict[int, dict[str, Any]] = {}

            for row in rows:
                product_id = to_int(row.get("id_product"))
                attribute_id = to_int(
                    row.get(
                        "id_product_attribute"
                    )
                )
                quantity = to_int(row.get("quantity"))
                out_of_stock = to_int(row.get("out_of_stock"), 0)

                if not product_id:
                    continue

                if attribute_id == 0:
                    general[product_id] = {
                        "quantity": quantity,
                        "out_of_stock": out_of_stock,
                    }
                    continue

                current = variants.setdefault(
                    product_id,
                    {
                        "quantity": 0,
                        "out_of_stock": out_of_stock,
                    },
                )
                current["quantity"] += quantity

            output: dict[int, dict[str, Any]] = {}

            for product_id in clean_ids:
                if product_id in general:
                    output[product_id] = general[product_id]
                elif product_id in variants:
                    output[product_id] = variants[product_id]

            return output

        except Exception:
            return {}

    def _available(
        self,
        *,
        available_for_order: Any,
        quantity: int | None,
        out_of_stock: int,
    ) -> bool:
        if not to_bool(available_for_order, True):
            return False

        if quantity is None:
            return True

        if quantity > 0:
            return True

        if out_of_stock == 1:
            return True

        return False

    def _language_id(
        self,
        language_id: int | None,
    ) -> int:
        return language_id or self.settings.prestashop_language_id

    def _products_cache_key(
        self,
        *,
        page: int,
        page_size: int,
        category_id: int | None,
        query: str | None,
        language_id: int,
        currency_id: int | None,
    ) -> str:
        return (
            f"products:page={page}:size={page_size}:"
            f"category={category_id or ''}:q={query or ''}:"
            f"lang={language_id}:currency={currency_id or ''}"
        )

    def _read_products_cache(
        self,
        key: str,
    ) -> tuple[list[ProductOut], dict[str, Any]] | None:
        cached = self.__class__._products_cache.get(key)

        if not cached:
            return None

        fresh_until, stale_until, products, meta = cached
        now = monotonic()

        if stale_until <= now:
            self.__class__._products_cache.pop(key, None)
            return None

        state = "hit" if fresh_until > now else "stale"
        output_meta = dict(meta)
        output_meta["cache"] = state

        return list(products), output_meta

    def _write_products_cache(
        self,
        key: str,
        products: list[ProductOut],
        meta: dict[str, Any],
        ttl_seconds: int,
    ) -> tuple[list[ProductOut], dict[str, Any]]:
        output_meta = dict(meta)
        output_meta["cache"] = "miss"
        now = monotonic()
        self.__class__._products_cache[key] = (
            now + ttl_seconds,
            now + PRODUCT_STALE_TTL_SECONDS,
            list(products),
            dict(meta),
        )

        return products, output_meta

    # ---------------------------------------------------------
    # IMAGE PRINCIPALE
    # ---------------------------------------------------------

    def _main_image_id(
        self,
        row: dict[str, Any],
    ) -> int | None:

        # Pour les listes produits, PrestaShop nous
        # fournit directement id_default_image.
        default_image = to_int(
            row.get("id_default_image"),
        )

        if default_image:
            return default_image

        # Sur une fiche produit complète,
        # les associations peuvent être présentes.
        associations = row.get(
            "associations"
        )

        if not isinstance(
            associations,
            dict,
        ):
            return None

        images = associations.get(
            "images"
        )

        if isinstance(images, list):
            if images:
                return (
                    to_int(
                        images[0].get("id")
                    )
                    or None
                )

        if isinstance(images, dict):
            nested = images.get(
                "image"
            )

            if isinstance(
                nested,
                list,
            ):
                if nested:
                    return (
                        to_int(
                            nested[0].get("id")
                        )
                        or None
                    )

            if isinstance(
                nested,
                dict,
            ):
                return (
                    to_int(
                        nested.get("id")
                    )
                    or None
                )

        return None

    # ---------------------------------------------------------
    # CARACTERISTIQUES PRODUIT
    # ---------------------------------------------------------

    async def _features_for_product(
        self,
        row: dict[str, Any],
    ) -> list[ProductFeatureOut]:

        associations = row.get(
            "associations"
        )

        if not isinstance(
            associations,
            dict,
        ):
            return []

        product_features = (
            associations.get(
                "product_features"
            )
        )

        if isinstance(
            product_features,
            dict,
        ):
            product_features = (
                product_features.get(
                    "product_feature",
                    product_features,
                )
            )

        if isinstance(
            product_features,
            dict,
        ):
            product_features = [
                product_features
            ]

        if not isinstance(
            product_features,
            list,
        ):
            return []

        output: list[
            ProductFeatureOut
        ] = []

        for link in product_features:

            if not isinstance(
                link,
                dict,
            ):
                continue

            feature_id = to_int(
                link.get("id"),
            )

            value_id = to_int(
                link.get(
                    "id_feature_value"
                ),
            )

            if (
                not feature_id
                or not value_id
            ):
                continue

            try:
                feature_payload = (
                    await self.ps.get_resource(
                        "product_features",
                        feature_id,
                    )
                )

                value_payload = (
                    await self.ps.get_resource(
                        "product_feature_values",
                        value_id,
                    )
                )

                feature_row = (
                    feature_payload.get(
                        "product_feature",
                        {},
                    )
                    if isinstance(
                        feature_payload,
                        dict,
                    )
                    else {}
                )

                value_row = (
                    value_payload.get(
                        "product_feature_value",
                        {},
                    )
                    if isinstance(
                        value_payload,
                        dict,
                    )
                    else {}
                )

                name = localized(
                    feature_row.get("name"),
                    self.settings
                    .prestashop_language_id,
                ).strip()

                value = localized(
                    value_row.get("value"),
                    self.settings
                    .prestashop_language_id,
                ).strip()

                if name and value:
                    output.append(
                        ProductFeatureOut(
                            name=name,
                            value=value,
                        )
                    )

            except Exception:
                continue

        return output
