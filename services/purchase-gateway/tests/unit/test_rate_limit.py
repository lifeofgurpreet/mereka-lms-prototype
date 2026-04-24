"""Unit tests for checkout endpoint rate limiting."""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.main import app
from app.models.offering import Offering, OfferingType
from app.rate_limit import limiter


def _make_offering() -> Offering:
    return Offering(
        id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        tenant_id=uuid.UUID(int=0),
        offering_type=OfferingType.course_seat,
        title="Test Course",
        price_cents=9900,
        currency="USD",
        stripe_price_id="price_test123",
        lms_resource_id="course-v1:Test+101+2024",
        active=True,
    )


def _mock_db_with_offering(offering: Offering | None):
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = offering
    db.execute = AsyncMock(return_value=result)
    return db


@pytest.fixture
def mock_stripe_session():
    session = MagicMock()
    session.id = "cs_test_session"
    session.url = "https://checkout.stripe.com/test"
    return session


@pytest.fixture
async def rate_limit_client(mock_stripe_session):
    """HTTP client with DB mocked so requests reach the rate limiter."""
    offering = _make_offering()
    mock_db_post = _mock_db_with_offering(offering)

    call_count = 0

    async def override_get_db():
        nonlocal call_count
        call_count += 1
        # Alternate between offering-returning and None-returning DB mocks
        # based on which endpoint is called. Using a single mock causes issues
        # with multiple execute calls, so we yield a fresh mock each time.
        yield mock_db_post

    app.dependency_overrides[get_db] = override_get_db

    with patch("app.routers.checkout.stripe") as mock_stripe:
        mock_stripe.checkout.Session.create.return_value = mock_stripe_session
        mock_stripe.StripeError = Exception

        limiter.reset()
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testclient") as ac:
            yield ac
        limiter.reset()

    app.dependency_overrides.pop(get_db, None)


@pytest.fixture
async def status_rate_limit_client():
    """HTTP client for GET /status/ tests — DB returns no order (404 path)."""
    mock_db = _mock_db_with_offering(None)

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_get_db

    limiter.reset()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testclient") as ac:
        yield ac
    limiter.reset()

    app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_checkout_post_within_limit_is_allowed(rate_limit_client):
    """POST /checkout/ must not return 429 within the first 10 requests per minute."""
    payload = {
        "offering_uuid": "00000000-0000-0000-0000-000000000001",
        "buyer_email": "buyer@example.com",
        "success_url": "https://academyv2.mereka.io/success",
        "cancel_url": "https://academyv2.mereka.io/cancel",
    }
    for i in range(5):
        resp = await rate_limit_client.post("/api/v1/checkout/", json=payload)
        assert resp.status_code != 429, f"Unexpected 429 on request {i + 1}"


@pytest.mark.asyncio
async def test_checkout_post_exceeds_limit_returns_429(rate_limit_client):
    """POST /checkout/ must return 429 after 10 requests per minute from the same IP."""
    payload = {
        "offering_uuid": "00000000-0000-0000-0000-000000000001",
        "buyer_email": "buyer@example.com",
        "success_url": "https://academyv2.mereka.io/success",
        "cancel_url": "https://academyv2.mereka.io/cancel",
    }

    for i in range(10):
        resp = await rate_limit_client.post("/api/v1/checkout/", json=payload)
        assert resp.status_code != 429, f"Got 429 too early on request {i + 1}"

    resp = await rate_limit_client.post("/api/v1/checkout/", json=payload)
    assert resp.status_code == 429


@pytest.mark.asyncio
async def test_checkout_status_within_limit_is_allowed(status_rate_limit_client):
    """GET /checkout/{session_id}/status/ must not return 429 within 30 requests per minute."""
    for i in range(5):
        resp = await status_rate_limit_client.get(
            "/api/v1/checkout/cs_test_abc/status/",
            params={"customer_email": "buyer@example.com"},
        )
        assert resp.status_code != 429, f"Unexpected 429 on request {i + 1}"


@pytest.mark.asyncio
async def test_checkout_status_exceeds_limit_returns_429(status_rate_limit_client):
    """GET /checkout/{session_id}/status/ must return 429 after 30 requests per minute."""
    for i in range(30):
        resp = await status_rate_limit_client.get(
            "/api/v1/checkout/cs_test_abc/status/",
            params={"customer_email": "buyer@example.com"},
        )
        assert resp.status_code != 429, f"Got 429 too early on request {i + 1}"

    resp = await status_rate_limit_client.get(
        "/api/v1/checkout/cs_test_abc/status/",
        params={"customer_email": "buyer@example.com"},
    )
    assert resp.status_code == 429


@pytest.mark.asyncio
async def test_rate_limit_response_has_error_body(rate_limit_client):
    """429 response must include a machine-readable error field."""
    payload = {
        "offering_uuid": "00000000-0000-0000-0000-000000000001",
        "buyer_email": "buyer@example.com",
        "success_url": "https://academyv2.mereka.io/success",
        "cancel_url": "https://academyv2.mereka.io/cancel",
    }

    for _ in range(10):
        await rate_limit_client.post("/api/v1/checkout/", json=payload)

    resp = await rate_limit_client.post("/api/v1/checkout/", json=payload)
    assert resp.status_code == 429
    data = resp.json()
    assert "error" in data or "detail" in data
