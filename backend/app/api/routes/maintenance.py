import asyncio
import time

from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse, Response

from app.services.maintenance import MaintenanceUnavailable, public_payload

router = APIRouter(tags=["Maintenance"])
HEADERS = {"Cache-Control": "private, no-store, max-age=0", "Vary": "Cookie",
           "X-Accel-Buffering": "no"}


def unavailable_response():
    return JSONResponse(status_code=503, headers={**HEADERS, "Retry-After": "5"}, content={
        "error_code": "maintenance_status_unavailable",
        "message": "La connexion est momentanément indisponible. Veuillez réessayer.",
    })


def maintenance_response(state):
    return JSONResponse(status_code=503, headers={**HEADERS, "Retry-After": "60"},
                        content={**public_payload(state), "error_code": "maintenance"})


@router.get("/maintenance/status")
async def status(request: Request, since: bool | None = None, wait: float = Query(default=0, ge=0, le=25)):
    """Long polling: changed state is returned without a page refresh.

    One source read/second is shared by anonymous watchers in each API worker.
    No permanently running task and no reverse-proxy streaming configuration.
    """
    deadline = time.monotonic() + wait
    cookie = request.headers.get("cookie", "")
    try:
        while True:
            state = await request.app.state.maintenance.status(cookie, fresh=since is None)
            if since is None or state["maintenance"] != since or time.monotonic() >= deadline:
                return JSONResponse(public_payload(state), headers=HEADERS)
            if await request.is_disconnected():
                return Response(status_code=204, headers=HEADERS)
            await asyncio.sleep(min(1, max(0, deadline - time.monotonic())))
    except MaintenanceUnavailable:
        return unavailable_response()
