"""Flask is the only source of truth, including verification of admin sessions."""
import asyncio
import time

import httpx


PUBLIC_MESSAGE = "Nous améliorons votre expérience solaire. Nous serons bientôt de retour."
CACHE_TTL_SECONDS = 15.0


def public_payload(state: dict) -> dict:
    """Only the effective visitor state may leave the maintenance service."""
    return {"maintenance": state["maintenance"], "message": PUBLIC_MESSAGE}


class MaintenanceUnavailable(Exception):
    pass


class MaintenanceService:
    def __init__(self, base_url: str):
        self.url = base_url.rstrip("/") + "/api/maintenance/status"
        self._client = None
        self._public_state = None
        self._checked_at = 0.0
        self._pending: dict[str, asyncio.Task] = {}

    async def close(self):
        pending = list(self._pending.values())
        for task in pending:
            task.cancel()
        if pending:
            await asyncio.gather(*pending, return_exceptions=True)
        self._pending.clear()
        if self._client:
            await self._client.aclose()
            self._client = None

    async def status(self, cookie: str = "", *, fresh: bool = True,
                     max_age: float | None = None) -> dict:
        """Share public business checks for 15 seconds, or force a source read.

        Status watchers can request a one-second snapshot with ``max_age=1``.
        Cookie exemptions always require Flask verification and are never cached.
        """
        ttl = max_age if max_age is not None else (0.0 if fresh else CACHE_TTL_SECONDS)
        if (not cookie and self._public_state is not None
                and time.monotonic() - self._checked_at < ttl):
            return dict(self._public_state)

        # No lock encloses network I/O. Anonymous visitors share one refresh;
        # each distinct cookie remains isolated from other sessions and visitors.
        task = self._pending.get(cookie)
        if task is None:
            task = asyncio.create_task(self._read_source(cookie))
            self._pending[cookie] = task

            def finished(done):
                if self._pending.get(cookie) is done:
                    self._pending.pop(cookie, None)
                # A disconnected waiter must not leave an unobserved exception.
                if not done.cancelled():
                    done.exception()

            task.add_done_callback(finished)
        # Cancelling one HTTP request must not cancel a shared source refresh.
        return dict(await asyncio.shield(task))

    async def _read_source(self, cookie: str) -> dict:
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
            # Preserve the last verified public state during a source outage.
            # An exemption from a cookie response can never become that fallback.
            if self._public_state is not None:
                if not cookie:
                    self._checked_at = time.monotonic()
                return dict(self._public_state)
            raise MaintenanceUnavailable() from None
