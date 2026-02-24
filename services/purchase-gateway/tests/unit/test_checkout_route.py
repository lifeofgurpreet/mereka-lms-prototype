"""Unit tests for checkout API endpoints — validation, Stripe mocking, error paths."""
# @covers AC-001, AC-005

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.offering import Offering, OfferingType
from app.models.order import Order, OrderStatus
from app.routers.checkout import CheckoutRequest, _is_allowed_origin

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_offering(
    *,
    tenant_id: uuid.UUID | None = None,
    active: bool = True,
    price_cents: int = 9900,
) -> Offering:
    return Offering(
        id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        tenant_id=tenant_id or uuid.UUID(int=0),
        offering_type=OfferingType.course_seat,
        title="Test Course",
        price_cents=price_cents,
        currency="USD",
        stripe_price_id="price_test123",
        lms_resource_id="course-v1:Test+101+2024",
        active=active,
    )


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    return db


# ---------------------------------------------------------------------------
# _is_allowed_origin helper
# ---------------------------------------------------------------------------


def test_is_allowed_origin_accepts_configured_origin():
    """Known origins pass the origin check."""
    from app.config import settings

    url = settings.ALLOWED_ORIGINS[0] + "/success"
    assert _is_allowed_origin(url) is True


def test_is_allowed_origin_rejects_unknown_origin():
    """Unknown origins fail the origin check."""
    assert _is_allowed_origin("https://evil.example.com/redirect") is False


# ---------------------------------------------------------------------------
# CheckoutRequest validation
# ---------------------------------------------------------------------------


def test_checkout_request_rejects_disallowed_origin():
    """CheckoutRequest raises ValueError when success_url is from disallowed origin."""
    import pytest

    with pytest.raises(Exception):  # pydantic ValidationError
        CheckoutRequest(
            offering_uuid=uuid.UUID(int=1),
            buyer_email="buyer@example.com",
            success_url="https://evil.example.com/success",
            cancel_url="https://evil.example.com/cancel",
        )


# ---------------------------------------------------------------------------
# Checkout route — offering not found
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.settings")
@patch("app.routers.checkout.stripe")
async def test_create_checkout_offering_not_found(mock_stripe, mock_settings, mock_db, client):
    """create_checkout returns 404 when offering does not exist or is inactive."""
    from fastapi import HTTPException

    from app.routers.checkout import create_checkout

    mock_db.execute.return_value = _mock_select_result(None)
    mock_settings.STRIPE_SECRET_KEY = "sk_test_xxx"
    mock_settings.TENANT_ISOLATION_ENABLED = False
    mock_settings.ALLOWED_ORIGINS = [
        "https://academyv2.mereka.io",
        "https://apps.academyv2.mereka.io",
    ]

    request = MagicMock()
    request.offering_uuid = uuid.UUID(int=1)
    request.buyer_email = "buyer@example.com"
    request.tenant_id = None
    request.success_url = "https://academyv2.mereka.io/success"
    request.cancel_url = "https://academyv2.mereka.io/cancel"
    request.metadata = None

    with pytest.raises(HTTPException) as exc_info:
        await create_checkout(request, mock_db)

    assert exc_info.value.status_code == 404


# ---------------------------------------------------------------------------
# Checkout route — tenant isolation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.settings")
@patch("app.routers.checkout.stripe")
async def test_create_checkout_tenant_mismatch(mock_stripe, mock_settings, mock_db):
    """create_checkout returns 403 when offering belongs to a different tenant."""
    from fastapi import HTTPException

    from app.routers.checkout import create_checkout

    offering = _make_offering(tenant_id=uuid.UUID(int=99))
    mock_db.execute.return_value = _mock_select_result(offering)

    mock_settings.STRIPE_SECRET_KEY = "sk_test_xxx"
    mock_settings.TENANT_ISOLATION_ENABLED = True

    request = MagicMock()
    request.offering_uuid = offering.id
    request.buyer_email = "buyer@example.com"
    request.tenant_id = uuid.UUID(int=1)  # Different from offering's tenant
    request.success_url = "https://academyv2.mereka.io/success"
    request.cancel_url = "https://academyv2.mereka.io/cancel"
    request.metadata = None

    with pytest.raises(HTTPException) as exc_info:
        await create_checkout(request, mock_db)

    assert exc_info.value.status_code == 403


# ---------------------------------------------------------------------------
# Checkout route — Stripe error
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.settings")
@patch("app.routers.checkout.stripe")
async def test_create_checkout_stripe_error_returns_503(mock_stripe, mock_settings, mock_db):
    """create_checkout returns 503 when Stripe raises an error."""
    import stripe as stripe_lib
    from fastapi import HTTPException

    from app.routers.checkout import create_checkout

    offering = _make_offering(tenant_id=uuid.UUID(int=0))
    mock_db.execute.return_value = _mock_select_result(offering)

    mock_settings.STRIPE_SECRET_KEY = "sk_test_xxx"
    mock_settings.TENANT_ISOLATION_ENABLED = False

    mock_stripe.StripeError = stripe_lib.StripeError
    mock_stripe.checkout.Session.create.side_effect = stripe_lib.StripeError("Network error")

    request = MagicMock()
    request.offering_uuid = offering.id
    request.buyer_email = "buyer@example.com"
    request.tenant_id = uuid.UUID(int=0)
    request.success_url = "https://academyv2.mereka.io/success"
    request.cancel_url = "https://academyv2.mereka.io/cancel"
    request.metadata = None

    with pytest.raises(HTTPException) as exc_info:
        await create_checkout(request, mock_db)

    assert exc_info.value.status_code == 503


# ---------------------------------------------------------------------------
# Checkout route — happy path
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.checkout.settings")
@patch("app.routers.checkout.stripe")
async def test_create_checkout_happy_path(mock_stripe, mock_settings, mock_db):
    """create_checkout creates an order and returns checkout URL on success."""
    from app.routers.checkout import CheckoutResponse, create_checkout

    offering = _make_offering(tenant_id=uuid.UUID(int=0))
    mock_db.execute.return_value = _mock_select_result(offering)

    mock_settings.STRIPE_SECRET_KEY = "sk_test_xxx"
    mock_settings.TENANT_ISOLATION_ENABLED = False

    mock_session = MagicMock()
    mock_session.id = "cs_new123"
    mock_session.url = "https://checkout.stripe.com/pay/cs_new123"
    mock_stripe.checkout.Session.create.return_value = mock_session
    mock_stripe.StripeError = Exception  # won't be raised

    request = MagicMock()
    request.offering_uuid = offering.id
    request.buyer_email = "buyer@example.com"
    request.tenant_id = uuid.UUID(int=0)
    request.success_url = "https://academyv2.mereka.io/success"
    request.cancel_url = "https://academyv2.mereka.io/cancel"
    request.metadata = None

    response = await create_checkout(request, mock_db)

    assert isinstance(response, CheckoutResponse)
    assert response.checkout_url == "https://checkout.stripe.com/pay/cs_new123"
    assert response.session_id == "cs_new123"
    mock_db.add.assert_called_once()
    mock_db.commit.assert_awaited()


# ---------------------------------------------------------------------------
# Checkout status endpoint
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_checkout_status_order_not_found(mock_db):
    """checkout_status returns 404 when session_id is unknown."""
    from fastapi import HTTPException

    from app.routers.checkout import checkout_status

    mock_db.execute.return_value = _mock_select_result(None)

    with pytest.raises(HTTPException) as exc_info:
        await checkout_status("cs_unknown", mock_db)

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_checkout_status_returns_order_state(mock_db):
    """checkout_status returns order_id and current status."""
    from app.routers.checkout import checkout_status

    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_known123",
        status=OrderStatus.fulfilled,
        total_cents=9900,
        currency="USD",
    )
    mock_db.execute.return_value = _mock_select_result(order)

    result = await checkout_status("cs_known123", mock_db)

    assert result["status"] == "fulfilled"
    assert result["order_id"] == str(order.id)
