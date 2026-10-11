"""Validate HTTP authorities before request URLs or business middleware are used."""
import ipaddress
import os
import re
from collections.abc import Iterable

from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send


DEFAULT_TRUSTED_HOSTS = (
    "localhost", "127.0.0.1", "::1", "heliantha.ma", "www.heliantha.ma",
    "app.heliantha.ma", "api.heliantha.ma",
)
_LABEL = re.compile(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", re.ASCII)
_PORT = re.compile(r"[0-9]{1,5}", re.ASCII)


def _authority_host(authority: str) -> str | None:
    """Parse an ASCII Host authority without accepting URL syntax or wildcards."""
    if (not authority or not authority.isascii()
            or any(ord(char) <= 32 or ord(char) == 127 for char in authority)
            or any(char in authority for char in "/\\?#@%*")):
        return None

    port = None
    if authority.startswith("["):
        closing = authority.find("]")
        if closing < 0:
            return None
        host = authority[1:closing]
        suffix = authority[closing + 1:]
        if suffix:
            if not suffix.startswith(":"):
                return None
            port = suffix[1:]
        try:
            host = str(ipaddress.IPv6Address(host))
        except ValueError:
            return None
    else:
        if authority.count(":") > 1:
            return None  # IPv6 authorities must use brackets.
        host, separator, trailing_port = authority.partition(":")
        if separator:
            port = trailing_port
        host = host.lower()
        if len(host) > 253 or any(_LABEL.fullmatch(label) is None for label in host.split(".")):
            return None
        if re.fullmatch(r"[0-9.]+", host) and "." in host:
            try:
                host = str(ipaddress.IPv4Address(host))
            except ValueError:
                return None

    if port is not None and (_PORT.fullmatch(port) is None or not 1 <= int(port) <= 65535):
        return None
    return host


def _trusted_host(value: str) -> str:
    # Configuration accepts a bare IPv6 address; HTTP Host still needs brackets.
    if "%" not in value:
        try:
            return str(ipaddress.IPv6Address(value))
        except ValueError:
            pass
    parsed = _authority_host(value)
    if parsed is None:
        raise ValueError("TRUSTED_HOSTS doit contenir des hôtes valides sans joker.")
    return parsed


def configured_trusted_hosts(app_env: str) -> tuple[str, ...]:
    configured = os.getenv("TRUSTED_HOSTS")
    if configured is not None:
        hosts = tuple(_trusted_host(value.strip()) for value in configured.split(","))
        return tuple(dict.fromkeys(hosts))
    hosts = DEFAULT_TRUSTED_HOSTS
    if app_env.strip().lower() == "development":
        hosts += ("testserver",)
    return hosts


def route_path(scope: Scope) -> str:
    """Return the app path for either ASGI convention around a mounted root."""
    path = scope.get("path", "")
    root_path = scope.get("root_path", "").rstrip("/")
    if root_path and (path == root_path or path.startswith(root_path + "/")):
        path = path[len(root_path):]
    return path or "/"


class HostValidationMiddleware:
    def __init__(self, app: ASGIApp, allowed_hosts: Iterable[str]):
        self.app = app
        self.allowed_hosts = frozenset(_trusted_host(value) for value in allowed_hosts)

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        authorities = [value for name, value in scope.get("headers", []) if name.lower() == b"host"]
        host = None
        if len(authorities) == 1:
            try:
                host = _authority_host(authorities[0].decode("ascii"))
            except UnicodeDecodeError:
                pass
        if host is None or host not in self.allowed_hosts:
            response = JSONResponse(
                {"detail": "Host invalide"}, status_code=400,
                headers={"Cache-Control": "private, no-store, max-age=0"},
            )
            await response(scope, receive, send)
            return
        await self.app(scope, receive, send)
