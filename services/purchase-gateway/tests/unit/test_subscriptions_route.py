"""Unit tests for subscription API endpoints — auth, validation, CRUD, list."""
# @covers AC-022, AC-023
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subscription import Subscription, SubscriptionStatus
from app.routers.subscriptions import (
    CreateSubscriptionRequest,
    UpdateSubscriptionRequest,
    create_subscription_endpoint,
    get_subscription,
    list_subscriptions,
    update_subscription,
)

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------


TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
OFFERING_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
SUB_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    db.refresh = AsyncMock()
    return db


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_subscription(**overrides) -> Subscription:
    defaults = {
        "id": SUB_ID,
        "tenant_id": TENANT_ID,
        "offering_id": OFFERING_ID,
        "enterprise_customer_uuid": None,
        "stripe_subscription_id": "sub_test123",
        "stripe_customer_id": "cus_test456",
        "status": SubscriptionStatus.active,
        "current_period_start": datetime(2024, 1, 1, tzinfo=UTC),
        "current_period_end": datetime(2024, 2, 1, tzinfo=UTC),
        "grace_period_end": None,
        "canceled_at": None,
        "seat_count": 5,
    }
    defaults.update(overrides)
    return Subscription(**defaults)


# ---------------------------------------------------------------------------
# create_subscription_endpoint — requires auth
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_subscription_disabled_feature_flag(mock_db):
    """create_subscription_endpoint returns 403 when ENABLE_ENTERPRISE_SUBSCRIPTIONS=False."""
    with patch("app.routers.subscriptions.settings") as mock_settings:
        mock_settings.ENABLE_ENTERPRISE_SUBSCRIPTIONS = False

        request_body = CreateSubscriptionRequest(
            tenant_id=TENANT_ID,
            offering_id=OFFERING_ID,
            stripe_customer_id="cus_test",
            seat_count=1,
        )

        with pytest.raises(HTTPException) as exc_info:
            await create_subscription_endpoint(request_body, mock_db, _="test-api-key")

    assert exc_info.value.status_code == 403
    assert "disabled" in exc_info.value.detail


@pytest.mark.asyncio
async def test_create_subscription_seat_count_zero_raises_422():
    """CreateSubscriptionRequest with seat_count=0 fails Pydantic validation."""
    with pytest.raises(ValidationError):
        CreateSubscriptionRequest(
            tenant_id=TENANT_ID,
            offering_id=OFFERING_ID,
            stripe_customer_id="cus_test",
            seat_count=0,
        )


@pytest.mark.asyncio
async def test_create_subscription_seat_count_negative_raises_422():
    """CreateSubscriptionRequest with negative seat_count fails Pydantic validation."""
    with pytest.raises(ValidationError):
        CreateSubscriptionRequest(
            tenant_id=TENANT_ID,
            offering_id=OFFERING_ID,
            stripe_customer_id="cus_test",
            seat_count=-1,
        )


@pytest.mark.asyncio
@patch("app.routers.subscriptions.create_subscription")
async def test_create_subscription_propagates_value_error_as_400(mock_create, mock_db):
    """ValueError from create_subscription service → 400 HTTP error."""
    mock_create.side_effect = ValueError("Offering not found")

    with patch("app.routers.subscriptions.settings") as mock_settings:
        mock_settings.ENABLE_ENTERPRISE_SUBSCRIPTIONS = True

        request_body = CreateSubscriptionRequest(
            tenant_id=TENANT_ID,
            offering_id=OFFERING_ID,
            stripe_customer_id="cus_test",
            seat_count=5,
        )

        with pytest.raises(HTTPException) as exc_info:
            await create_subscription_endpoint(request_body, mock_db, _="test-api-key")

    assert exc_info.value.status_code == 400
    assert "Offering not found" in exc_info.value.detail


@pytest.mark.asyncio
@patch("app.routers.subscriptions.create_subscription")
async def test_create_subscription_success(mock_create, mock_db):
    """create_subscription_endpoint returns the subscription on success."""
    sub = _make_subscription()
    mock_create.return_value = sub

    with patch("app.routers.subscriptions.settings") as mock_settings:
        mock_settings.ENABLE_ENTERPRISE_SUBSCRIPTIONS = True

        request_body = CreateSubscriptionRequest(
            tenant_id=TENANT_ID,
            offering_id=OFFERING_ID,
            stripe_customer_id="cus_test",
            seat_count=5,
        )

        result = await create_subscription_endpoint(request_body, mock_db, _="test-api-key")

    assert result.stripe_subscription_id == "sub_test123"
    assert result.seat_count == 5


# ---------------------------------------------------------------------------
# update_subscription — requires auth
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_update_subscription_not_found_returns_404(mock_db):
    """update_subscription returns 404 when the subscription does not exist."""
    mock_db.execute.return_value = _mock_select_result(None)

    request = MagicMock()
    request.state = MagicMock(spec=[])

    with pytest.raises(HTTPException) as exc_info:
        await update_subscription(
            uuid.uuid4(),
            UpdateSubscriptionRequest(cancel=True),
            request,
            mock_db,
            _="api-key",
        )

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
@patch("app.routers.subscriptions.stripe_lib")
async def test_update_subscription_cancel(mock_stripe, mock_db):
    """update_subscription with cancel=True calls Stripe and marks subscription canceled."""
    sub = _make_subscription()
    mock_db.execute.return_value = _mock_select_result(sub)

    mock_stripe.Subscription.modify.return_value = MagicMock()

    request = MagicMock()
    request.state = MagicMock(spec=[])

    async def _fake_refresh(obj):
        pass

    mock_db.refresh.side_effect = _fake_refresh

    with patch("app.routers.subscriptions.settings") as mock_settings:
        mock_settings.STRIPE_SECRET_KEY = "sk_test_xxx"

        await update_subscription(
            SUB_ID,
            UpdateSubscriptionRequest(cancel=True),
            request,
            mock_db,
            _="api-key",
        )

    assert sub.status == SubscriptionStatus.canceled
    assert sub.canceled_at is not None
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_update_subscription_seat_count_zero_raises_422():
    """UpdateSubscriptionRequest with seat_count=0 fails validation."""
    with pytest.raises(ValidationError):
        UpdateSubscriptionRequest(seat_count=0)


# ---------------------------------------------------------------------------
# get_subscription — no auth required
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_subscription_not_found_returns_404(mock_db):
    """get_subscription returns 404 when the subscription does not exist."""
    mock_db.execute.return_value = _mock_select_result(None)

    request = MagicMock()
    request.state = MagicMock(spec=[])

    with pytest.raises(HTTPException) as exc_info:
        await get_subscription(uuid.uuid4(), request, mock_db)

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_get_subscription_returns_subscription(mock_db):
    """get_subscription returns the subscription when found."""
    sub = _make_subscription()
    mock_db.execute.return_value = _mock_select_result(sub)

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await get_subscription(SUB_ID, request, mock_db)

    assert result.id == SUB_ID
    assert result.stripe_subscription_id == "sub_test123"


@pytest.mark.asyncio
async def test_get_subscription_tenant_mismatch_returns_404(mock_db):
    """get_subscription returns 404 when tenant in request.state does not match."""
    sub = _make_subscription(tenant_id=uuid.UUID(int=99))
    mock_db.execute.return_value = _mock_select_result(sub)

    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = uuid.UUID(int=1)  # Different tenant

    with pytest.raises(HTTPException) as exc_info:
        await get_subscription(SUB_ID, request, mock_db)

    assert exc_info.value.status_code == 404


# ---------------------------------------------------------------------------
# list_subscriptions — no auth required
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_subscriptions_returns_all(mock_db):
    """list_subscriptions returns all subscriptions without filters."""
    subs = [_make_subscription(), _make_subscription(id=uuid.uuid4())]
    mock_db.execute.return_value = _mock_scalars_result(subs)

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await list_subscriptions(
        request=request,
        db=mock_db,
        tenant_id=None,
        status=None,
        limit=50,
        offset=0,
    )

    assert result == subs


@pytest.mark.asyncio
async def test_list_subscriptions_filters_by_status(mock_db):
    """list_subscriptions with status filter returns matching subscriptions."""
    sub = _make_subscription(status=SubscriptionStatus.past_due)
    mock_db.execute.return_value = _mock_scalars_result([sub])

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await list_subscriptions(
        request=request,
        db=mock_db,
        tenant_id=None,
        status="past_due",
        limit=50,
        offset=0,
    )

    assert result == [sub]
