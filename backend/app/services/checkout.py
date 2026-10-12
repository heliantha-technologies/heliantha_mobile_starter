from __future__ import annotations

import asyncio
import json
import re
from typing import Any

from app.clients.bridge import (
    BridgeHTTPError,
    BridgeUnavailable,
    PrestaShopBridgeClient,
)
from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings
from app.schemas.checkout import (
    CheckoutCarrierOut,
    CheckoutFieldOut,
    CheckoutLineIn,
    CheckoutLineOut,
    CheckoutPaymentOut,
    CheckoutPreviewIn,
    CheckoutPreviewOut,
    CheckoutTotalsOut,
)
from app.services.catalog import CatalogService
from app.services.geo import get_morocco_country_id
from app.services.normalizers import (
    localized,
    to_float,
    to_int,
    unwrap_collection,
)


COUNTRY_DISPLAY = "[id,name,iso_code,active,deleted]"


class CheckoutService:
    def __init__(
        self,
        ps: PrestaShopClient,
        catalog: CatalogService,
        settings: Settings,
        bridge: PrestaShopBridgeClient | None = None,
    ):
        self.ps = ps
        self.catalog = catalog
        self.settings = settings
        self.bridge = bridge

    async def preview(
        self,
        payload: CheckoutPreviewIn,
        *,
        customer_id: int | None = None,
    ) -> CheckoutPreviewOut:
        products, morocco_country_id = await asyncio.gather(
            self.catalog.products_by_ids(
                [line.product_id for line in payload.lines],
                language_id=payload.language_id,
                currency_id=payload.currency_id,
            ),
            self._morocco_country_id(),
        )
        products_by_id = {product.id: product for product in products}
        lines = [
            self._line_out(line, products_by_id.get(line.product_id))
            for line in payload.lines
        ]
        unavailable = any(
            not line.available and line.product_attribute_id == 0
            for line in lines
        )
        if unavailable:
            # A fresh grouped read avoids blocking a product that was recently
            # restocked while still returning line-level diagnostics.
            products = await self.catalog.products_by_ids(
                [line.product_id for line in payload.lines],
                language_id=payload.language_id,
                currency_id=payload.currency_id,
                force_refresh=True,
            )
            products_by_id = {product.id: product for product in products}
            lines = [
                self._line_out(line, products_by_id.get(line.product_id))
                for line in payload.lines
            ]
        preview = CheckoutPreviewOut(
            modes=["guest", "login"],
            personal_fields=self._personal_fields(),
            address_fields=self._address_fields(),
            required_consents=self._required_consents(),
            lines=lines,
            totals=CheckoutTotalsOut(
                subtotal=0,
                shipping=None,
                shipping_label="",
                discounts=0.0,
                total_ttc=0,
                taxes_included=True,
                currency="",
                currency_symbol="",
                source="prestashop_bridge_required",
            ),
            carriers=[],
            payments=[],
            selected_carrier_id=None,
            stock_ok=all(line.available for line in lines),
            write_enabled=self.settings.checkout_write_enabled,
            bridge_required=[
                "Bridge PrestaShop requis pour panier, livraison, paiement, taxes et total TTC.",
            ],
        )

        if not preview.stock_ok:
            currency = next((line.currency for line in lines), "MAD")
            currency_symbol = next(
                (line.currency_symbol for line in lines), currency
            )
            preview.message = (
                "Un ou plusieurs produits ne sont plus disponibles dans les "
                "quantités demandées. Ajustez les lignes avant de continuer."
            )
            preview.totals = CheckoutTotalsOut(
                subtotal=sum(line.total for line in lines if line.available),
                shipping=None,
                shipping_label="À recalculer après correction du stock",
                discounts=0,
                total_ttc=0,
                taxes_included=True,
                currency=currency,
                currency_symbol=currency_symbol,
                source="catalog_stock_check",
            )
            return preview

        if self.bridge is None:
            raise BridgeUnavailable("Bridge PrestaShop requis pour le checkout.")

        try:
            result = await self.bridge.post(
                "checkout?action=preview",
                {
                    **payload.model_dump(mode="json"),
                    "morocco_country_id": morocco_country_id,
                    **({"customer_id": customer_id} if customer_id else {}),
                },
            )
        except BridgeUnavailable:
            raise
        except BridgeHTTPError as exc:
            if exc.code != "INSUFFICIENT_STOCK":
                raise
            return self._stock_conflict_preview(preview, exc)

        data = result.get("data", result)
        if isinstance(data, dict):
            preview = self._merge_bridge_preview(preview, data)

        return preview

    def _stock_conflict_preview(
        self,
        preview: CheckoutPreviewOut,
        error: BridgeHTTPError,
    ) -> CheckoutPreviewOut:
        detail = ""
        try:
            body = json.loads(error.body or "{}")
            detail = str((body.get("error") or {}).get("detail") or "")
        except (TypeError, ValueError, AttributeError):
            pass
        product_id_match = re.search(r"product_id=(\d+)", detail)
        requested_match = re.search(r"requested=(\d+)", detail)
        available_match = re.search(r"available=(-?\d+)", detail)
        product_id = int(product_id_match.group(1)) if product_id_match else None
        requested = int(requested_match.group(1)) if requested_match else None
        available = int(available_match.group(1)) if available_match else None
        affected_product_id = product_id
        if affected_product_id is None and preview.lines:
            affected_product_id = preview.lines[0].product_id
        preview.lines = [
            line.model_copy(
                update={
                    "available": False,
                    "stock_quantity": available,
                    "stock_message": (
                        f"Stock insuffisant : {available} disponible(s)"
                        + (
                            f" pour {requested} demandé(s)."
                            if requested is not None
                            else "."
                        )
                        if available is not None
                        else error.detail
                    ),
                }
            )
            if line.product_id == affected_product_id
            else line
            for line in preview.lines
        ]
        preview.stock_ok = False
        preview.message = (
            "Le stock a changé pendant la vérification. "
            "Ajustez la quantité puis relancez l’aperçu."
        )
        preview.totals = CheckoutTotalsOut(
            subtotal=sum(line.total for line in preview.lines if line.available),
            shipping=None,
            shipping_label="À recalculer après correction du stock",
            discounts=0,
            total_ttc=0,
            taxes_included=True,
            currency=preview.totals.currency,
            currency_symbol=preview.totals.currency_symbol,
            source="prestashop_stock_conflict",
        )
        return preview

    def _merge_bridge_preview(
        self,
        preview: CheckoutPreviewOut,
        data: dict[str, Any],
    ) -> CheckoutPreviewOut:
        totals = data.get("totals")
        if isinstance(totals, dict):
            preview.totals = CheckoutTotalsOut(
                subtotal=to_float(totals.get("subtotal")),
                shipping=(
                    to_float(totals.get("shipping"))
                    if totals.get("shipping") is not None
                    else None
                ),
                shipping_label=str(totals.get("shipping_label") or ""),
                discounts=to_float(totals.get("discounts")),
                total_ttc=to_float(totals.get("total_ttc")),
                taxes_included=True,
                currency=str(totals.get("currency") or preview.totals.currency),
                currency_symbol=str(
                    totals.get("currency_symbol")
                    or preview.totals.currency_symbol
                ),
                source="prestashop_cart",
            )

        carriers = data.get("delivery_options") or data.get("carriers")
        if isinstance(carriers, list):
            preview.carriers = [
                CheckoutCarrierOut(
                    id=to_int(row.get("carrier_id") or row.get("id")),
                    name=str(row.get("name") or ""),
                    delay=str(row.get("delay") or "") or None,
                    price=(
                        to_float(row.get("price"))
                        if row.get("price") is not None
                        else None
                    ),
                    price_label=str(
                        row.get("formatted_price")
                        or row.get("price_label")
                        or ""
                    )
                    or None,
                )
                for row in carriers
                if isinstance(row, dict)
                and to_int(row.get("carrier_id") or row.get("id"))
            ]
        selected_carrier_id = to_int(data.get("selected_carrier_id"))
        if selected_carrier_id:
            preview.selected_carrier_id = selected_carrier_id

        payments = data.get("payments")
        if isinstance(payments, list):
            preview.payments = [
                CheckoutPaymentOut(
                    module=str(row.get("module") or ""),
                    name=str(row.get("name") or ""),
                )
                for row in payments
                if isinstance(row, dict) and row.get("module")
            ]

        if data.get("stock_ok") is not None:
            preview.stock_ok = bool(data.get("stock_ok")) and preview.stock_ok

        return preview

    def _line_out(
        self,
        line: CheckoutLineIn,
        product: Any,
    ) -> CheckoutLineOut:
        if product is None:
            return CheckoutLineOut(
                product_id=line.product_id,
                product_attribute_id=line.product_attribute_id,
                name="Produit indisponible",
                quantity=line.quantity,
                unit_price=0,
                total=0,
                currency="MAD",
                currency_symbol="MAD",
                available=False,
                stock_quantity=None,
                stock_message="Produit introuvable dans PrestaShop.",
            )

        enough_stock = (
            line.product_attribute_id != 0
            or product.quantity is None
            or product.quantity >= line.quantity
        )
        available = product.available and enough_stock
        stock_message = None
        if not product.available:
            stock_message = "Produit indisponible à la commande."
        elif not enough_stock:
            stock_message = f"Stock insuffisant : {product.quantity} disponible(s)."

        return CheckoutLineOut(
            product_id=product.id,
            product_attribute_id=line.product_attribute_id,
            name=product.name,
            quantity=line.quantity,
            unit_price=product.price,
            total=product.price * line.quantity,
            currency=product.currency,
            currency_symbol=product.currency_symbol,
            available=available,
            stock_quantity=product.quantity,
            stock_message=stock_message,
        )

    async def _carriers(
        self,
        language_id: int | None,
    ) -> list[CheckoutCarrierOut]:
        try:
            payload = await self.ps.list_resource(
                "carriers",
                display="[id,name,delay,active,deleted]",
                filters={"active": "[1]", "deleted": "[0]"},
                limit="0,20",
            )
        except Exception:
            return []

        rows = unwrap_collection(payload, "carriers")
        carriers: list[CheckoutCarrierOut] = []
        for row in rows:
            carrier_id = to_int(row.get("id"))
            if not carrier_id:
                continue
            name = localized(
                row.get("name"),
                language_id or self.settings.prestashop_language_id,
            ).strip()
            if not name:
                continue
            carriers.append(
                CheckoutCarrierOut(
                    id=carrier_id,
                    name=name,
                    delay=localized(
                        row.get("delay"),
                        language_id or self.settings.prestashop_language_id,
                    ).strip()
                    or None,
                    price=None,
                    price_label="Calculé par PrestaShop",
                )
            )
        return carriers

    async def _payments(self) -> list[CheckoutPaymentOut]:
        # Le Webservice PrestaShop ne fournit pas de liste fiable des moyens de
        # paiement disponibles par panier. Cette donnée doit venir du bridge.
        return []

    def _personal_fields(self) -> list[CheckoutFieldOut]:
        return [
            CheckoutFieldOut(name="title", label="Titre", options=["M.", "Mme"]),
            CheckoutFieldOut(name="firstname", label="Prénom"),
            CheckoutFieldOut(name="lastname", label="Nom"),
            CheckoutFieldOut(name="email", label="E-mail", type="email"),
            CheckoutFieldOut(
                name="create_account",
                label="Créer votre compte",
                required=False,
                type="checkbox",
            ),
            CheckoutFieldOut(
                name="password",
                label="Mot de passe",
                required=False,
                type="password",
            ),
        ]

    def _address_fields(self) -> list[CheckoutFieldOut]:
        return [
            CheckoutFieldOut(name="firstname", label="Prénom"),
            CheckoutFieldOut(name="lastname", label="Nom"),
            CheckoutFieldOut(name="address1", label="Adresse"),
            CheckoutFieldOut(
                name="address2",
                label="Complément d'adresse",
                required=False,
            ),
            CheckoutFieldOut(name="postcode", label="Code postal", required=False),
            CheckoutFieldOut(name="city", label="Ville"),
            CheckoutFieldOut(name="phone", label="Téléphone", required=False),
        ]

    async def _morocco_country_id(self) -> int:
        try:
            return await get_morocco_country_id(self.ps, self.settings.prestashop_language_id)
        except Exception as exc:
            raise BridgeHTTPError(502, "Pays Maroc introuvable dans PrestaShop.") from exc

    def _required_consents(self) -> list[CheckoutFieldOut]:
        return [
            CheckoutFieldOut(
                name="terms",
                label="J'accepte les conditions générales de vente",
                type="checkbox",
            )
        ]

