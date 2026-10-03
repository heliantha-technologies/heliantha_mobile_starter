import logging
from typing import Any, Literal, Optional

import httpx
from fastapi import APIRouter, Body, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field, ValidationError

router = APIRouter(
    prefix="/v1/devis",
    tags=["Devis & Simulateur Solaire"],
)

FLASK_INTERNAL_URL = "http://127.0.0.1:8012"
PROJECT_TYPE_MAPPING = {
    "autoconsommation": "photovoltaic",
    "on_grid": "photovoltaic",
    "ongrid": "photovoltaic",
    "pv": "photovoltaic",
    "photovoltaic": "photovoltaic",
    "hybride": "hybrid",
    "batterie": "hybrid",
    "batteries": "hybrid",
    "stockage": "hybrid",
    "hybrid": "hybrid",
    "pompage": "pumping",
    "pompe": "pumping",
    "pumping": "pumping",
}
logger = logging.getLogger(__name__)


class ContactInfo(BaseModel):
    name: str = Field(..., description="Nom du client.")
    phone: str = Field(..., description="Telephone du client.")
    city: Optional[str] = Field(default="", description="Ville du client.")

    model_config = ConfigDict(extra="ignore")


class PhotovoltaicInput(BaseModel):
    monthly_consumption_kwh: float = Field(
        ...,
        description="Consommation mensuelle en kWh.",
        examples=[420.0],
    )
    meter_type: Literal["monophase", "triphase"] = Field(
        default="monophase",
        description="Type de compteur.",
    )
    phase: Literal["1", "3"] = Field(
        default="1",
        description="Nombre de phases.",
    )

    model_config = ConfigDict(
        extra="ignore",
        json_schema_extra={
            "example": {
                "monthly_consumption_kwh": 420.0,
                "meter_type": "monophase",
                "phase": "1",
            }
        },
    )


class HybridInput(BaseModel):
    monthly_consumption_kwh: float = Field(
        ...,
        description="Consommation mensuelle en kWh.",
        examples=[520.0],
    )

    model_config = ConfigDict(
        extra="ignore",
        json_schema_extra={"example": {"monthly_consumption_kwh": 520.0}},
    )


class PumpingInput(BaseModel):
    pump_existing: bool = Field(
        default=False,
        description="True si la pompe existe deja.",
    )
    existing_pump_cv: Optional[float] = Field(
        default=None,
        description="Puissance de la pompe existante en CV.",
    )
    flow_m3_h: float = Field(
        ...,
        description="Debit horaire souhaite en m3/h.",
        examples=[6.0],
    )
    hmt_m: float = Field(
        ...,
        description="Hauteur manometrique totale en metres.",
        examples=[45.0],
    )

    model_config = ConfigDict(
        extra="ignore",
        json_schema_extra={
            "example": {
                "pump_existing": False,
                "flow_m3_h": 6.0,
                "hmt_m": 45.0,
            }
        },
    )


class QuoteRequest(BaseModel):
    project_type: str = Field(
        ...,
        description="Type de projet. Alias acceptes, puis normalises pour Flask.",
        examples=["photovoltaic", "hybrid", "pumping"],
    )
    data: dict[str, Any] = Field(
        ...,
        description=(
            "Donnees du projet. Elles sont nettoyees selon le type avant appel Flask."
        ),
    )
    contact: Optional[ContactInfo] = None

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "project_type": "photovoltaic",
                    "data": {
                        "monthly_consumption_kwh": 420.0,
                        "meter_type": "monophase",
                        "phase": "1",
                    },
                    "contact": {
                        "name": "Client PV",
                        "phone": "0600000000",
                        "city": "Casablanca",
                    },
                },
                {
                    "project_type": "hybrid",
                    "data": {"monthly_consumption_kwh": 520.0},
                },
                {
                    "project_type": "pumping",
                    "data": {
                        "pump_existing": False,
                        "flow_m3_h": 6.0,
                        "hmt_m": 45.0,
                    },
                },
            ]
        }
    )


def _upstream_error_detail(response: httpx.Response) -> Any:
    try:
        return response.json()
    except ValueError:
        body = response.text.strip()
        return body or "Le moteur solaire a retourne une erreur sans detail."


def _upstream_status_code(status_code: int) -> int:
    if 400 <= status_code < 500:
        return status_code
    return 502


def _normalize_project_type(project_type: Any) -> str:
    if not isinstance(project_type, str):
        raise HTTPException(
            status_code=400,
            detail="Type de projet invalide : project_type doit etre une chaine de caracteres.",
        )

    project_type_key = project_type.strip().lower().replace("-", "_")
    project_type_key = "_".join(project_type_key.split())
    normalized = PROJECT_TYPE_MAPPING.get(project_type_key)
    if normalized:
        return normalized

    accepted_types = ", ".join(sorted(PROJECT_TYPE_MAPPING))
    raise HTTPException(
        status_code=400,
        detail=(
            "Type de projet non reconnu. Types acceptes : "
            f"{accepted_types}."
        ),
    )


def _is_missing(value: Any) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def _to_float(value: Any, field_name: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Champ invalide : {field_name} doit etre numerique.",
        ) from exc


def _data_validation_error(project_type: str, exc: ValidationError) -> HTTPException:
    return HTTPException(
        status_code=400,
        detail={
            "message": f"Donnees invalides pour le projet {project_type}.",
            "errors": exc.errors(),
        },
    )


def _normalize_meter_data(data: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(data)
    if not _is_missing(normalized.get("meter_type")):
        normalized["meter_type"] = str(normalized["meter_type"]).strip().lower()
    if not _is_missing(normalized.get("phase")):
        normalized["phase"] = str(normalized["phase"]).strip()
    return normalized


def _ensure_monthly_consumption(data: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(data)
    if _is_missing(normalized.get("monthly_consumption_kwh")) and not _is_missing(
        normalized.get("monthly_bill")
    ):
        monthly_bill = _to_float(normalized["monthly_bill"], "monthly_bill")
        normalized["monthly_consumption_kwh"] = round(monthly_bill / 1.15, 2)
    return normalized


def _normalize_photovoltaic_data(data: dict[str, Any]) -> dict[str, Any]:
    prepared = _normalize_meter_data(_ensure_monthly_consumption(data))
    try:
        model = PhotovoltaicInput.model_validate(prepared)
    except ValidationError as exc:
        raise _data_validation_error("photovoltaic", exc) from exc
    return model.model_dump()


def _normalize_hybrid_data(data: dict[str, Any]) -> dict[str, Any]:
    prepared = _ensure_monthly_consumption(data)
    try:
        model = HybridInput.model_validate(prepared)
    except ValidationError as exc:
        raise _data_validation_error("hybrid", exc) from exc
    return model.model_dump()


def _normalize_pumping_data(data: dict[str, Any]) -> dict[str, Any]:
    prepared = dict(data)
    if _is_missing(prepared.get("flow_m3_h")):
        if not _is_missing(prepared.get("flow_rate")):
            prepared["flow_m3_h"] = prepared["flow_rate"]
        elif not _is_missing(prepared.get("flow_m3_day")):
            prepared["flow_m3_h"] = round(
                _to_float(prepared["flow_m3_day"], "flow_m3_day") / 6,
                2,
            )
    if _is_missing(prepared.get("hmt_m")):
        if not _is_missing(prepared.get("total_head_m")):
            prepared["hmt_m"] = prepared["total_head_m"]
        elif not _is_missing(prepared.get("profondeur")):
            prepared["hmt_m"] = prepared["profondeur"]

    try:
        model = PumpingInput.model_validate(prepared)
    except ValidationError as exc:
        raise _data_validation_error("pumping", exc) from exc
    return model.model_dump(exclude_none=True)


def _normalize_project_data(project_type: str, data: dict[str, Any]) -> dict[str, Any]:
    if project_type == "photovoltaic":
        return _normalize_photovoltaic_data(data)
    if project_type == "hybrid":
        return _normalize_hybrid_data(data)
    if project_type == "pumping":
        return _normalize_pumping_data(data)
    raise HTTPException(status_code=400, detail="Type de projet non supporte.")


def _build_flask_payload(payload: QuoteRequest) -> dict[str, Any]:
    project_type = _normalize_project_type(payload.project_type)
    normalized_payload: dict[str, Any] = {
        "project_type": project_type,
        "data": _normalize_project_data(project_type, payload.data),
    }
    if payload.contact is not None:
        normalized_payload["contact"] = payload.contact.model_dump(exclude_none=True)
    return normalized_payload


@router.post("/calculer", response_model=None)
async def calculer_devis(
    payload: QuoteRequest = Body(...),
) -> Any:
    normalized_payload = _build_flask_payload(payload)
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{FLASK_INTERNAL_URL}/api/calculate",
                json=normalized_payload,
            )
    except httpx.TimeoutException as exc:
        logger.warning("Timeout du moteur solaire lors du calcul devis : %s", exc)
        raise HTTPException(
            status_code=502,
            detail="Le moteur de dimensionnement solaire n'a pas repondu dans le delai imparti.",
        ) from exc
    except httpx.RequestError as exc:
        logger.warning("Erreur reseau vers le moteur solaire lors du calcul devis : %s", exc)
        raise HTTPException(
            status_code=502,
            detail="Impossible de joindre le moteur de dimensionnement solaire.",
        ) from exc

    if response.status_code != 200:
        content_type = response.headers.get("content-type", "").split(";")[0].lower()
        raise HTTPException(
            status_code=response.status_code,
            detail=response.json() if content_type == "application/json" else response.text,
        )

    try:
        return response.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="La reponse du moteur solaire n'est pas un JSON valide.",
        ) from exc


@router.get("/{quote_id}/pdf")
async def telecharger_pdf_devis(quote_id: int) -> Response:
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{FLASK_INTERNAL_URL}/devis/{quote_id}/pdf",
            )
    except httpx.TimeoutException as exc:
        logger.warning("Timeout du moteur solaire lors du PDF devis %s : %s", quote_id, exc)
        raise HTTPException(
            status_code=502,
            detail="Le moteur solaire n'a pas renvoye le PDF dans le delai imparti.",
        ) from exc
    except httpx.RequestError as exc:
        logger.warning("Erreur reseau vers le moteur solaire lors du PDF devis %s : %s", quote_id, exc)
        raise HTTPException(
            status_code=502,
            detail="Impossible de joindre le moteur solaire pour recuperer le PDF.",
        ) from exc

    if response.status_code == 200:
        return Response(
            content=response.content,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'inline; filename="Devis_Heliantha_{quote_id}.pdf"',
            },
        )

    if response.status_code == 404:
        raise HTTPException(
            status_code=404,
            detail=f"Devis {quote_id} introuvable.",
        )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=_upstream_status_code(response.status_code),
            detail=_upstream_error_detail(response),
        )

    raise HTTPException(
        status_code=502,
        detail=f"Reponse inattendue du moteur solaire : HTTP {response.status_code}.",
    )
