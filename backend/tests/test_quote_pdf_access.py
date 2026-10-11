import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers import devis


@pytest.fixture
def pdf_upstream(monkeypatch):
    seen = []
    original_client = httpx.AsyncClient

    def handler(request):
        seen.append(request)
        if request.url.params.get("token") == "valid-quote-1" and request.url.path == "/devis/1/document.pdf":
            return httpx.Response(200, content=b"%PDF-1.4 test", headers={"Content-Type": "application/pdf"})
        if request.headers.get("cookie") == "session=verified-admin":
            return httpx.Response(200, content=b"%PDF-admin", headers={"Content-Type": "application/pdf"})
        return httpx.Response(403, json={"detail": "forbidden"})

    monkeypatch.setattr(devis.httpx, "AsyncClient", lambda **kwargs: original_client(
        transport=httpx.MockTransport(handler), **kwargs,
    ))
    return seen


def test_pdf_without_token_is_forbidden_before_upstream_call(pdf_upstream):
    response = TestClient(app).get("/v1/devis/1/pdf")
    assert response.status_code == 403
    assert response.json() == {"detail": devis.PDF_ACCESS_DENIED}
    assert pdf_upstream == []


def test_valid_token_is_forwarded_and_pdf_returned(pdf_upstream):
    response = TestClient(app).get("/v1/devis/1/pdf?token=valid-quote-1")
    assert response.status_code == 200
    assert response.content == b"%PDF-1.4 test"
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["cache-control"].startswith("private, no-store")
    assert response.headers["referrer-policy"] == "no-referrer"
    assert pdf_upstream[0].url.params["token"] == "valid-quote-1"


@pytest.mark.parametrize("path,headers", [
    ("/v1/devis/1/pdf?token=invalid", {}),
    ("/v1/devis/2/pdf?token=valid-quote-1", {}),
    ("/v1/devis/1/pdf", {"Cookie": "session=forged-admin"}),
])
def test_invalid_quote_token_or_session_is_forbidden(pdf_upstream, path, headers):
    response = TestClient(app).get(path, headers=headers)
    assert response.status_code == 403
    assert response.json() == {"detail": devis.PDF_ACCESS_DENIED}
    assert len(pdf_upstream) == 1


def test_admin_session_must_be_accepted_by_flask(pdf_upstream):
    response = TestClient(app).get("/v1/devis/1/pdf", headers={"Cookie": "session=verified-admin"})
    assert response.status_code == 200
    assert pdf_upstream[0].headers["cookie"] == "session=verified-admin"
    assert "token" not in pdf_upstream[0].url.params


def test_client_jwt_does_not_authorize_quote_pdf(pdf_upstream):
    response = TestClient(app).get("/v1/devis/1/pdf", headers={"Authorization": "Bearer client-jwt"})
    assert response.status_code == 403
    assert pdf_upstream == []


def test_quote_identifier_cannot_inject_upstream_query(pdf_upstream):
    response = TestClient(app).get("/v1/devis/1%3Fother/pdf?token=valid-quote-1")
    assert response.status_code == 400
    assert pdf_upstream == []


@pytest.mark.parametrize("upstream_status,content_type,expected", [
    (302, "text/html", 403),
    (401, "application/json", 403),
    (404, "application/json", 404),
    (500, "application/json", 502),
    (200, "text/html", 502),
])
def test_proxy_rejects_login_redirects_and_non_pdf_responses(monkeypatch, upstream_status, content_type, expected):
    original_client = httpx.AsyncClient
    monkeypatch.setattr(devis.httpx, "AsyncClient", lambda **kwargs: original_client(
        transport=httpx.MockTransport(lambda request: httpx.Response(
            upstream_status, content=b"upstream", headers={"Content-Type": content_type, "Location": "/login"},
        )), **kwargs,
    ))
    response = TestClient(app).get("/v1/devis/1/pdf?token=private-token")
    assert response.status_code == expected
    assert "private-token" not in response.text


def test_upstream_network_error_does_not_expose_private_token(monkeypatch, caplog):
    original_client = httpx.AsyncClient

    def handler(request):
        raise httpx.ConnectError(str(request.url), request=request)

    monkeypatch.setattr(devis.httpx, "AsyncClient", lambda **kwargs: original_client(
        transport=httpx.MockTransport(handler), **kwargs,
    ))
    response = TestClient(app).get("/v1/devis/1/pdf?token=private-token")
    assert response.status_code == 502
    assert "private-token" not in response.text
    assert "private-token" not in caplog.text
