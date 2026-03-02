"""Tests for subscription lifecycle — creation, updates, cancellation, and webhook handling."""

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from app.models.subscription import Subscription, SubscriptionStatus
from app.services.subscription import (
    handle_invoice_paid,
    handle_invoice_payment_failed,
    handle_subscription_created,
    handle_subscription_deleted,
    handle_subscription_updated,
)
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
def mock_db():
    """Create a mock async database session."""
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = MagicMock()
    return db


@pytest.fixture
def stripe_subscription_event():
    """Base Stripe subscription event data."""
    return {
        "object": {
            "id": "sub_test123",
            "customer": "cus_test456",
            "status": "active",
            "current_period_start": 1700000000,
            "current_period_end": 1702592000,
            "quantity": 10,
            "metadata": {
                "tenant_id": "00000000-0000-0000-0000-000000000001",
                "offering_id": "00000000-0000-0000-0000-000000000002",
            },
            "items": {
                "data": [{"quantity": 10}],
            },
        }
    }


def _mock_select_result(subscription):
    """Create a mock query result that returns a subscription."""
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = subscription
    return mock_result


# --- Subscription Created ---


@pytest.mark.asyncio
async def test_handle_subscription_created(mock_db, stripe_subscription_event):
    """New subscription from webhook creates a local record."""
    # First query returns None (no existing subscription)
    mock_db.execute.return_value = _mock_select_result(None)

    await handle_subscription_created(stripe_subscription_event, mock_db)

    mock_db.add.assert_called_once()
    added_sub = mock_db.add.call_args[0][0]
    assert isinstance(added_sub, Subscription)
    assert added_sub.stripe_subscription_id == "sub_test123"
    assert added_sub.stripe_customer_id == "cus_test456"
    assert added_sub.status == SubscriptionStatus.active
    assert added_sub.seat_count == 10  # from .get("quantity", 10) on the sub object
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_handle_subscription_created_idempotent(mock_db, stripe_subscription_event):
    """Duplicate subscription creation is silently skipped."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_test123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.active,
        current_period_start=datetime(2023, 11, 15, tzinfo=UTC),
        current_period_end=datetime(2023, 12, 15, tzinfo=UTC),
        seat_count=10,
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    await handle_subscription_created(stripe_subscription_event, mock_db)

    mock_db.add.assert_not_called()


# --- Subscription Updated ---


@pytest.mark.asyncio
async def test_handle_subscription_updated(mock_db, stripe_subscription_event):
    """Subscription update syncs status and period."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_test123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.trialing,
        current_period_start=datetime(2023, 10, 1, tzinfo=UTC),
        current_period_end=datetime(2023, 11, 1, tzinfo=UTC),
        seat_count=5,
        grace_period_end=None,
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    await handle_subscription_updated(stripe_subscription_event, mock_db)

    assert existing.status == SubscriptionStatus.active
    assert existing.seat_count == 10
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_handle_subscription_updated_not_found(mock_db, stripe_subscription_event):
    """Update for unknown subscription is a no-op."""
    mock_db.execute.return_value = _mock_select_result(None)

    await handle_subscription_updated(stripe_subscription_event, mock_db)

    mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_handle_subscription_updated_clears_grace_period(mock_db, stripe_subscription_event):
    """Transition to active clears any grace_period_end."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_test123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.past_due,
        current_period_start=datetime(2023, 10, 1, tzinfo=UTC),
        current_period_end=datetime(2023, 11, 1, tzinfo=UTC),
        seat_count=5,
        grace_period_end=datetime(2023, 11, 8, tzinfo=UTC),
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    await handle_subscription_updated(stripe_subscription_event, mock_db)

    assert existing.status == SubscriptionStatus.active
    assert existing.grace_period_end is None


# --- Subscription Deleted ---


@pytest.mark.asyncio
async def test_handle_subscription_deleted(mock_db):
    """Deleted subscription is marked as canceled."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_del123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.active,
        current_period_start=datetime(2023, 11, 1, tzinfo=UTC),
        current_period_end=datetime(2023, 12, 1, tzinfo=UTC),
        seat_count=10,
        canceled_at=None,
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    event_data = {"object": {"id": "sub_del123"}}
    await handle_subscription_deleted(event_data, mock_db)

    assert existing.status == SubscriptionStatus.canceled
    assert existing.canceled_at is not None
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_handle_subscription_deleted_not_found(mock_db):
    """Deletion of unknown subscription is a no-op."""
    mock_db.execute.return_value = _mock_select_result(None)

    event_data = {"object": {"id": "sub_unknown"}}
    await handle_subscription_deleted(event_data, mock_db)

    mock_db.commit.assert_not_awaited()


# --- Invoice Paid ---


@pytest.mark.asyncio
async def test_handle_invoice_paid_renews_subscription(mock_db):
    """Successful invoice payment renews subscription period."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_inv123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.past_due,
        current_period_start=datetime(2023, 10, 1, tzinfo=UTC),
        current_period_end=datetime(2023, 11, 1, tzinfo=UTC),
        seat_count=10,
        grace_period_end=datetime(2023, 11, 8, tzinfo=UTC),
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    event_data = {
        "object": {
            "subscription": "sub_inv123",
            "lines": {
                "data": [{
                    "period": {
                        "start": 1701388800,  # 2023-12-01
                        "end": 1704067200,    # 2024-01-01
                    }
                }]
            },
        }
    }
    await handle_invoice_paid(event_data, mock_db)

    assert existing.status == SubscriptionStatus.active
    assert existing.grace_period_end is None
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_handle_invoice_paid_no_subscription(mock_db):
    """Invoice without subscription ID is ignored."""
    event_data = {"object": {"subscription": None}}
    await handle_invoice_paid(event_data, mock_db)
    mock_db.execute.assert_not_awaited()


# --- Invoice Payment Failed ---


@pytest.mark.asyncio
async def test_handle_invoice_payment_failed_sets_grace_period(mock_db):
    """Failed invoice payment sets past_due status and grace period."""
    existing = Subscription(
        id=uuid.uuid4(),
        stripe_subscription_id="sub_fail123",
        stripe_customer_id="cus_test456",
        tenant_id=uuid.UUID(int=1),
        offering_id=uuid.UUID(int=2),
        status=SubscriptionStatus.active,
        current_period_start=datetime(2023, 11, 1, tzinfo=UTC),
        current_period_end=datetime(2023, 12, 1, tzinfo=UTC),
        seat_count=10,
        grace_period_end=None,
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    event_data = {"object": {"subscription": "sub_fail123"}}
    await handle_invoice_payment_failed(event_data, mock_db)

    assert existing.status == SubscriptionStatus.past_due
    assert existing.grace_period_end is not None
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_handle_invoice_payment_failed_no_subscription(mock_db):
    """Non-subscription invoice failure is ignored."""
    event_data = {"object": {"subscription": None}}
    await handle_invoice_payment_failed(event_data, mock_db)
    mock_db.execute.assert_not_awaited()
