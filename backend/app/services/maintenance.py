"""Flask is the only source of truth, including verification of admin sessions."""
import asyncio
import time

import httpx


PUBLIC_MESSAGE = "Nous améliorons votre expérience solaire. Nous serons bientôt de retour."


def public_payload(state: dict) -> dict:
    """Only the effective visitor state may leave the maintenance service."""
    return {"maintenance": state["maintenance"], "message": PUBLIC_MESSAGE}


class MaintenanceUnavailable(Exception):
    pass


class MaintenanceService:
    def __init__(self, base_url: str):
        self.url = base_url.rstrip("/") + "/api/maintenance/status"
        self._client = None
        self._lock = asyncio.Lock()
        self._public_state = None
        self._checked_at = 0.0

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    async def status(self, cookie: str = "", *, fresh: bool = True) -> dict:
        # Only anonymous long polls share a one-second snapshot. Business requests
        # always verify the source before executing; no cached catalogue bypass.
        async with self._lock:
            if (not fresh and not cookie and self._public_state is not None
                    and time.monotonic() - self._checked_at < 1):
                return dict(self._public_state)
            if self._client is None:
                self._client = httpx.AsyncClient(timeout=2.0, follow_redirects=False)
            try:
                response = await self._client.get(
                    self.url,
                    headers={"Accept": "application/json", "Cache-Control": "no-cache",
                             "Cookie": cookie},
                )
                response.raise_for_status()
                state = response.json()
                if not isinstance(state, dict) or type(state.get("maintenance")) is not bool:
                    raise ValueError("Invalid maintenance status")
                # Accept an older Flask deployment during a rolling update, but
                # never forward its administrative fields to the visitor.
                if "enabled" in state or "admin_exempt" in state:
                    if (type(state.get("enabled")) is not bool
                            or type(state.get("admin_exempt")) is not bool
                            or state["maintenance"] != (state["enabled"] and not state["admin_exempt"])):
                        raise ValueError("Invalid maintenance status")
                # Never reuse an authenticated exemption for other visitors.
                if not cookie:
                    if state.get("admin_exempt"):
                        raise ValueError("Unexpected anonymous exemption")
                    self._public_state = public_payload(state)
                    self._checked_at = time.monotonic()
                return public_payload(state)
            except (httpx.HTTPError, ValueError, TypeError):
                # An unavailable control service cannot silently reopen checkout.
                if self._public_state and self._public_state["maintenance"]:
                    return dict(self._public_state)
                raise MaintenanceUnavailable() from None
