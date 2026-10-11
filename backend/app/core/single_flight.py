from __future__ import annotations

import asyncio
from typing import Any, Awaitable, Callable, TypeVar

T = TypeVar("T")


class SingleFlight:
    """
    Coordonnateur anti-cache-stampede (coalescing) en memoire.
    Empeche le declenchement simultane de multiples requetes identiques vers PrestaShop
    lors d'un cache miss concurrent sur les ressources publiques.
    """

    def __init__(self) -> None:
        self._in_flight: dict[str, asyncio.Future] = {}
        self._lock: asyncio.Lock | None = None

    def _get_lock(self) -> asyncio.Lock:
        if self._lock is None:
            self._lock = asyncio.Lock()
        return self._lock

    async def execute(self, key: str, fn: Callable[[], Awaitable[T]]) -> T:
        lock = self._get_lock()
        is_leader = False
        future: asyncio.Future

        async with lock:
            if key in self._in_flight:
                future = self._in_flight[key]
            else:
                is_leader = True
                loop = asyncio.get_running_loop()
                future = loop.create_future()
                self._in_flight[key] = future

        if not is_leader:
            return await future

        try:
            result = await fn()
            if not future.done():
                future.set_result(result)
            return result
        except BaseException as exc:
            if not future.done():
                future.set_exception(exc)
                # The leader also raises directly; with no followers this
                # future would otherwise report an unobserved exception.
                future.exception()
            raise
        finally:
            async with lock:
                self._in_flight.pop(key, None)


single_flight = SingleFlight()
