import pytest
from httpx import ASGITransport, AsyncClient
from starlette.requests import Request

from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def fake_request():
    """Minimal Starlette Request for unit tests that call rate-limited endpoints directly."""
    scope = {"type": "http", "method": "GET", "path": "/", "headers": [], "query_string": b""}
    return Request(scope)
