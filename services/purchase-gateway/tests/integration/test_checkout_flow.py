"""Integration tests for checkout flow — offering lookup, Stripe mocking, status endpoint."""
# @covers AC-001, AC-005
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.offering import Offering, OfferingType
from app.models.order import Order, OrderStatus

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
OFFERING_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


def _make_offering(**overrides) -> Offering:
    defaults = dict(
        id=OFFERING_ID,
        tenant_id=TENANT_ID,
        offering_type=OfferingType.course_seat,
        title="Test Course",
        price_cents=9900,
        currency="USD",
        stripe_price_id="price_test_123",
        lms_resource_id="course-v1:Test+101+2024",
        active=True,
        metadata_json=None,
        created_at=datetime(2024, 1, 1, tzinfo=UTC),
        updated_at=datetime(2024, 1, 1, tzinfo=UTC),
    )
    defaults.update(overrides)
    return Offering(**defaults)


def _make_order(session_id: str = "cs_test_checkout", status: OrderStatus = OrderStatus.pending):
    return Order(
        id=uuid.uuid4(),
        tenant_id=TENANT_ID,
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=session_id,
        status=status,
        total_cents=9900,
        currency="USD",
    )


def _mock_select_result(obj):
    r = MagicMock()
    r.scalar_one_or_none.return_value = obj
    return r


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


CHECKOUT_PAYLOAD = {
    "offering_uuid": str(OFFERING_ID),
    "buyer_email": "buyer@example.com",
    "tenant_id": str(TENANT_ID),
    "success_url": "https://academyv2.mereka.io/success",
    "cancel_url": "https://academyv2.mereka.io/cancel",
}


# ---------------------------------------------------------------------------
# Checkout — offering not found
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.stripe")
async def test_checkout_inactive_offering_returns_404(mock_stripe, client):
    """POST /checkout/ with inactive offering → 404."""
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(None)
    mock_db.commit = AsyncMock()

    _override_db(mock_db)
    try:
        resp = await client.post("/api/v1/checkout/", json=CHECKOUT_PAYLOAD)
    finally:
        _clear_overrides()

    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Checkout — tenant mismatch
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.stripe")
@patch("app.routers.checkout.settings")
async def test_checkout_wrong_tenant_returns_403(mock_settings, mock_stripe, client):
    """POST /checkout/ with offering belonging to different tenant → 403."""
    other_tenant = uuid.UUID("00000000-0000-0000-0000-000000000099")
    offering = _make_offering(tenant_id=other_tenant)

    mock_settings.TENANT_ISOLATION_ENABLED = True
    mock_settings.ALLOWED_ORIGINS = [
        "https://academyv2.mereka.io",
        "https://apps.academyv2.mereka.io",
    ]

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(offering)
    mock_db.commit = AsyncMock()

    _override_db(mock_db)
    try:
        resp = await client.post("/api/v1/checkout/", json=CHECKOUT_PAYLOAD)
    finally:
        _clear_overrides()

    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Checkout — Stripe call mocked, happy path
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.asyncio")
@patch("app.routers.checkout.stripe")
@patch("app.routers.checkout.settings")
async def test_checkout_happy_path_calls_stripe(
    mock_settings, mock_stripe, mock_asyncio, client
):
    """POST /checkout/ with valid offering → calls Stripe and returns checkout_url."""
    offering = _make_offering(tenant_id=TENANT_ID)

    mock_settings.TENANT_ISOLATION_ENABLED = False
    mock_settings.ALLOWED_ORIGINS = [
        "https://academyv2.mereka.io",
        "https://apps.academyv2.mereka.io",
    ]

    mock_session = MagicMock()
    mock_session.id = "cs_live_abc123"
    mock_session.url = "https://checkout.stripe.com/pay/cs_live_abc123"


    async def _fake_to_thread(fn, *args, **kwargs):
        return fn(*args, **kwargs)

    mock_asyncio.to_thread = _fake_to_thread
    mock_stripe.checkout.Session.create.return_value = mock_session
    mock_stripe.StripeError = Exception  # won't be raised

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(offering)
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()

    _override_db(mock_db)
    try:
        resp = await client.post("/api/v1/checkout/", json=CHECKOUT_PAYLOAD)
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    data = resp.json()
    assert data["checkout_url"] == "https://checkout.stripe.com/pay/cs_live_abc123"
    assert data["session_id"] == "cs_live_abc123"
    assert "order_id" in data


@pytest.mark.asyncio
@patch("app.routers.checkout.asyncio")
@patch("app.routers.checkout.stripe")
@patch("app.routers.checkout.settings")
async def test_checkout_session_id_is_not_pending_placeholder(
    mock_settings, mock_stripe, mock_asyncio, client
):
    """After Stripe responds, order.stripe_checkout_session_id is the real Stripe session ID."""
    import stripe as stripe_lib

    offering = _make_offering(tenant_id=TENANT_ID)

    mock_settings.TENANT_ISOLATION_ENABLED = False
    mock_settings.ALLOWED_ORIGINS = [
        "https://academyv2.mereka.io",
        "https://apps.academyv2.mereka.io",
    ]

    mock_session = MagicMock()
    mock_session.id = "cs_real_session_id"
    mock_session.url = "https://checkout.stripe.com/pay/cs_real_session_id"

    async def _fake_to_thread(fn, *args, **kwargs):
        return fn(*args, **kwargs)

    mock_asyncio.to_thread = _fake_to_thread
    mock_stripe.checkout.Session.create.return_value = mock_session
    mock_stripe.StripeError = stripe_lib.StripeError

    added_orders = []

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(offering)
    mock_db.commit = AsyncMock()
    # Use MagicMock (not AsyncMock) for .add so side_effect runs synchronously
    mock_db.add = MagicMock(side_effect=lambda obj: added_orders.append(obj))

    _override_db(mock_db)
    try:
        resp = await client.post("/api/v1/checkout/", json=CHECKOUT_PAYLOAD)
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert len(added_orders) == 1
    order = added_orders[0]
    # The session ID must be the real Stripe ID, not the pending placeholder
    assert not order.stripe_checkout_session_id.startswith("pending-")
    assert order.stripe_checkout_session_id == "cs_real_session_id"


# ---------------------------------------------------------------------------
# Checkout status endpoint
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_checkout_status_unknown_session_returns_404(client):
    """GET /checkout/{session_id}/status/ for unknown session → 404."""
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(None)

    _override_db(mock_db)
    try:
        resp = await client.get("/api/v1/checkout/unknown_session_id/status/")
    finally:
        _clear_overrides()

    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_checkout_status_returns_order_status(client):
    """GET /checkout/{session_id}/status/ returns order_id and current status."""
    order = _make_order("cs_known_session", status=OrderStatus.fulfilled)

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(order)

    _override_db(mock_db)
    try:
        resp = await client.get("/api/v1/checkout/cs_known_session/status/")
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "fulfilled"
    assert "order_id" in data


@pytest.mark.asyncio
async def test_checkout_status_pending_order(client):
    """GET /checkout/{session_id}/status/ returns 'pending' for a pending order."""
    order = _make_order("cs_pending_session", status=OrderStatus.pending)

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(order)

    _override_db(mock_db)
    try:
        resp = await client.get("/api/v1/checkout/cs_pending_session/status/")
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json()["status"] == "pending"
