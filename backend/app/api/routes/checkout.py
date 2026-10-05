import json
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.deps import get_bridge_client, get_checkout_service
from app.clients.bridge import (
    BridgeHTTPError,
    BridgeUnavailable,
    PrestaShopBridgeClient,
)
from app.clients.prestashop import PrestaShopError
from app.core.config import Settings, get_settings
from app.core.security import decode_access_token
from app.schemas.checkout import CheckoutConfirmIn, CheckoutPreviewIn
from app.services.checkout import CheckoutService
from app.services.normalizers import unwrap_collection

router = APIRouter(tags=["checkout"])
optional_bearer = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)


def _handle_checkout_exception(exc: Exception, operation: str) -> HTTPException:
    """Mappe proprement les erreurs upstream et inattendues sans fuite de secrets ni stack trace."""
    if isinstance(exc, HTTPException):
        return exc

    if isinstance(exc, BridgeUnavailable):
        logger.warning("checkout %s bridge indisponible : %s", operation, exc)
        return HTTPException(
            status_code=501,
            detail="Le service de commande nécessite le pont serveur PrestaShop.",
        )

    if isinstance(exc, BridgeHTTPError):
        logger.warning(
            "checkout %s bridge HTTP %s code=%s detail=%s",
            operation,
            exc.status_code,
            getattr(exc, "code", None),
            exc.detail,
        )
        # Conserver le code HTTP métier (409 stock/doublon, 422 validation, 403 interdit, 404 introuvable)
        if exc.status_code in {400, 401, 403, 404, 409, 422}:
            return HTTPException(status_code=exc.status_code, detail=exc.detail)
        # Erreur interne 5xx retournée par PrestaShop
        return HTTPException(
            status_code=502,
            detail="Le serveur PrestaShop a retourné une erreur interne.",
        )

    if isinstance(exc, httpx.TimeoutException):
        logger.warning("checkout %s timeout upstream : %s", operation, exc)
        return HTTPException(
            status_code=504,
            detail="Délai d'attente dépassé avec PrestaShop. Veuillez réessayer.",
        )

    if isinstance(exc, httpx.RequestError):
        logger.warning("checkout %s erreur réseau upstream : %s", operation, exc)
        return HTTPException(
            status_code=503,
            detail="Impossible de joindre le serveur PrestaShop. Service temporairement indisponible.",
        )

    if isinstance(exc, PrestaShopError):
        logger.warning("checkout %s PrestaShopError : %s", operation, exc)
        return HTTPException(
            status_code=502,
            detail="Erreur de communication avec le catalogue PrestaShop.",
        )

    logger.exception("checkout %s erreur inattendue type=%s", operation, type(exc).__name__)
    return HTTPException(
        status_code=502,
        detail="Une erreur inattendue est survenue lors de la commande. Veuillez réessayer.",
    )


def _safe_confirm_log(body: dict) -> dict:
    return {
        "line_count": len(body.get("lines") or []),
        "lines": [
            {
                "product_id": line.get("product_id"),
                "product_attribute_id": line.get("product_attribute_id"),
                "quantity": line.get("quantity"),
            }
            for line in (body.get("lines") or [])
            if isinstance(line, dict)
        ],
        "mode": body.get("mode"),
        "customer_id": body.get("customer_id"),
        "address_id": body.get("address_id"),
        "has_address": isinstance(body.get("address"), dict),
        "carrier_id": body.get("carrier_id"),
        "payment_module": body.get("payment_module"),
        "has_idempotency_key": bool(body.get("idempotency_key")),
    }


def _checkout_resource_row(raw: object, resource: str, resource_id: int) -> dict:
    if isinstance(raw, dict):
        row = raw.get(resource[:-1], raw)
        if isinstance(row, dict) and str(row.get("id")) == str(resource_id):
            return row
        for row in unwrap_collection(raw, resource):
            if str(row.get("id")) == str(resource_id):
                return row
    raise HTTPException(502, "Nous n’avons pas pu retrouver la confirmation. Veuillez réessayer.")


async def _resume_duplicate_checkout(
    exc: BridgeHTTPError,
    body: dict,
    service: CheckoutService,
) -> dict | None:
    """Resume the bridge's durable key/order lookup without writing to PrestaShop."""
    if exc.status_code != 409:
        return None
    try:
        response = json.loads(exc.body or "{}")
    except (TypeError, ValueError):
        return None
    error = response.get("error") if isinstance(response, dict) else None
    if not isinstance(error, dict):
        return None
    if (error.get("code") or exc.code) != "DUPLICATE_CHECKOUT":
        return None
    try:
        order_id = int(error.get("order_id") or 0)
    except (TypeError, ValueError):
        return None
    if order_id <= 0:
        return None

    # The order ID comes from the private bridge, never from the caller.
    raw = await service.ps.get_resource("orders", order_id)
    order = _checkout_resource_row(raw, "orders", order_id)
    customer_id = int(order.get("id_customer") or 0)
    if body.get("customer_id"):
        belongs_to_customer = customer_id == int(body["customer_id"])
    else:
        guest_email = str((body.get("guest") or {}).get("email") or "").strip().casefold()
        belongs_to_customer = False
        if guest_email and customer_id > 0:
            raw_customer = await service.ps.get_resource("customers", customer_id)
            customer = _checkout_resource_row(raw_customer, "customers", customer_id)
            belongs_to_customer = (
                isinstance(customer, dict)
                and str(customer.get("is_guest")) in {"1", "True"}
                and str(customer.get("email") or "").strip().casefold() == guest_email
            )
    if not belongs_to_customer:
        raise HTTPException(403, "Cette confirmation ne correspond pas à votre commande.")
    reference = str(order.get("reference") or "").strip()
    if not reference:
        raise HTTPException(502, "La référence de votre commande est momentanément indisponible. Veuillez réessayer.")

    confirmation = {
        "status": "success",
        "order_id": order_id,
        "reference": reference,
        "is_duplicate_safe": True,
        "message": "Commande confirmée",
        "total": float(order.get("total_paid_tax_incl") or order.get("total_paid") or 0),
        "payment_module": order.get("module"),
    }
    logger.info("Idempotent checkout hit: order %s returned safely", reference)
    return {
        **confirmation,
        "success": True,
        "data": confirmation,
        "meta": None,
        "error": None,
    }


@router.post("/checkout/preview", response_model=dict)
async def checkout_preview(
    payload: CheckoutPreviewIn,
    service: CheckoutService = Depends(get_checkout_service),
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
    settings: Settings = Depends(get_settings),
) -> dict:
    try:
        customer_id: int | None = None
        if credentials:
            identity = decode_access_token(credentials.credentials, settings)
            customer_id = int(identity["sub"])
        preview = await service.preview(payload, customer_id=customer_id)
        return {
            "success": True,
            "data": preview.model_dump(),
            "meta": None,
            "error": None,
        }
    except Exception as exc:
        raise _handle_checkout_exception(exc, "preview") from exc



@router.post("/checkout/confirm", response_model=dict)
async def checkout_confirm(
    payload: CheckoutConfirmIn,
    settings: Settings = Depends(get_settings),
    service: CheckoutService = Depends(get_checkout_service),
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
) -> dict:
    if not settings.checkout_write_enabled:
        raise HTTPException(
            status_code=423,
            detail=(
                "CHECKOUT_WRITE_ENABLED=false : la création réelle de "
                "commande PrestaShop est désactivée."
            ),
    )

    try:
        body = payload.model_dump(mode="json")
        if credentials:
            identity = decode_access_token(credentials.credentials, settings)
            body["customer_id"] = int(identity["sub"])
        morocco_country_id = await service._morocco_country_id()
        body["morocco_country_id"] = morocco_country_id

        # Mode login : s'assurer que firstname et lastname ne sont jamais vides
        if body.get("mode") == "login" or body.get("customer_id"):
            cid = body.get("customer_id")
            cust_firstname = ""
            cust_lastname = ""
            if cid:
                try:
                    cust_raw = await service.ps.get_resource("customers", int(cid))
                    cust_data = cust_raw.get("customer", cust_raw) if isinstance(cust_raw, dict) else {}
                    cust_firstname = str(cust_data.get("firstname") or "").strip()
                    cust_lastname = str(cust_data.get("lastname") or "").strip()
                except Exception as ce:
                    logger.warning("Impossible de charger le customer pour compléter le checkout: %s", ce)

            if not body.get("address") and body.get("address_id"):
                try:
                    addr_raw = await service.ps.get_resource("addresses", int(body["address_id"]))
                    addr_data = addr_raw.get("address", addr_raw) if isinstance(addr_raw, dict) else {}
                    if addr_data:
                        fn = str(addr_data.get("firstname") or "").strip() or cust_firstname or "Client"
                        ln = str(addr_data.get("lastname") or "").strip() or cust_lastname or "Heliantha"
                        body["address"] = {
                            "firstname": fn,
                            "lastname": ln,
                            "address1": str(addr_data.get("address1") or "").strip(),
                            "address2": str(addr_data.get("address2") or "").strip(),
                            "postcode": str(addr_data.get("postcode") or "").strip(),
                            "city": str(addr_data.get("city") or "").strip(),
                            "phone": str(addr_data.get("phone") or addr_data.get("phone_mobile") or "").strip(),
                            "country_id": morocco_country_id,
                        }
                except Exception as e:
                    logger.warning("Impossible de pré-remplir l'adresse pour checkout/confirm : %s", e)
            elif body.get("address") and isinstance(body["address"], dict):
                addr = body["address"]
                if not addr.get("firstname") and cust_firstname:
                    addr["firstname"] = cust_firstname
                if not addr.get("lastname") and cust_lastname:
                    addr["lastname"] = cust_lastname


        logger.info(
            "Checkout confirm payload sanitized=%s write_enabled=%s",
            _safe_confirm_log(body),
            settings.checkout_write_enabled,
        )
        result = await bridge.post(
            "checkout?action=confirm",
            body,
        )


    except BridgeUnavailable as exc:
        raise HTTPException(status_code=501, detail=str(exc)) from exc
    except BridgeHTTPError as exc:
        try:
            resumed = await _resume_duplicate_checkout(exc, body, service)
        except Exception as recovery_error:
            raise _handle_checkout_exception(recovery_error, "confirm recovery") from recovery_error
        if resumed is not None:
            return resumed
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except Exception as exc:
        raise _handle_checkout_exception(exc, "confirm") from exc

    return {
        "success": True,
        "data": result.get("data", result),
        "meta": None,
        "error": None,
    }
