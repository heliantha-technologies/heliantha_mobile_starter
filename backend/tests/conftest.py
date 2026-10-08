"""External maintenance service is mocked for offline API regression tests."""
from unittest.mock import AsyncMock

import pytest


@pytest.fixture(autouse=True)
def available_maintenance_source(monkeypatch):
    from app.main import app
    source = AsyncMock()
    source.status.return_value = {
        "enabled": False, "maintenance": False, "admin_exempt": False,
    }
    monkeypatch.setattr(app.state, "maintenance", source)
    return source
