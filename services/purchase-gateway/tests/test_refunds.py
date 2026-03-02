"""Tests for refund processing — full refund, partial refund, idempotency, enrollment revocation."""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import FulfillmentStatus, LineItem, Order, OrderStatus
from app.services.refund import process_refund, revoke_enrollment


@pytest.fixture
def mock_db():
    """Create a mock async database session."""
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    return db


def _make_order(
    *,
    status: OrderStatus = OrderStatus.fulfilled,
    buyer_user_id: int | None = 42,
    line_items: list | None = None,
) -> Order:
    """Create a test order with sensible defaults."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        buyer_user_id=buyer_user_id,
        stripe_checkout_session_id="cs_test",
        stripe_payment_intent_id="pi_test123",
        status=status,
        total_cents=5000,
        currency="USD",
    )
    if line_items is None:
        item = LineItem(
            id=uuid.uuid4(),
            order_id=order.id,
            offering_uuid=uuid.UUID(int=10),
            offering_type="course_seat",
            lms_resource_id="course-v1:Test+101+2024",
            quantity=1,
            unit_price_cents=5000,
            total_price_cents=5000,
            fulfillment_status=FulfillmentStatus.fulfilled,
        )
        order.line_items = [item]
    else:
        order.line_items = line_items
    return order


def _mock_select_result(order):
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = order
    return mock_result


def _refund_event(*, amount: int = 5000, amount_refunded: int = 5000) -> dict:
    """Create a charge.refunded event data payload."""
    return {
        "object": {
            "id": "ch_test123",
            "payment_intent": "pi_test123",
            "amount": amount,
            "amount_refunded": amount_refunded,
        }
    }


# --- Full Refund ---


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_full_refund_revokes_enrollments(mock_lms_cls, mock_db):
    """Full refund marks order as refunded and revokes enrollments."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    mock_lms.deactivate_enrollment = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    await process_refund(_refund_event(), mock_db)

    assert order.status == OrderStatus.refunded
    assert order.refunded_at is not None
    mock_lms.deactivate_enrollment.assert_awaited_once_with(
        "testuser", "course-v1:Test+101+2024"
    )
    # commit called at least once (for audit + status)
    mock_db.commit.assert_awaited()
    # audit log created
    mock_db.add.assert_called()


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_full_refund_no_lms_user(mock_lms_cls, mock_db):
    """Full refund with no buyer_user_id skips enrollment revocation."""
    order = _make_order(buyer_user_id=None)
    mock_db.execute.return_value = _mock_select_result(order)

    mock_lms = MagicMock()
    mock_lms_cls.return_value = mock_lms

    await process_refund(_refund_event(), mock_db)

    assert order.status == OrderStatus.refunded
    mock_lms.deactivate_enrollment.assert_not_called()


# --- Partial Refund ---


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_partial_refund_no_enrollment_revoke(mock_lms_cls, mock_db):
    """Partial refund changes status but does not revoke enrollments."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    mock_lms = MagicMock()
    mock_lms_cls.return_value = mock_lms

    event = _refund_event(amount=5000, amount_refunded=2000)
    await process_refund(event, mock_db)

    assert order.status == OrderStatus.partially_refunded
    assert order.refunded_at is not None
    mock_lms.deactivate_enrollment.assert_not_called()


# --- Idempotency ---


@pytest.mark.asyncio
async def test_refund_idempotent_already_refunded(mock_db):
    """Processing a refund for an already-refunded order is a no-op."""
    order = _make_order(status=OrderStatus.refunded)
    mock_db.execute.return_value = _mock_select_result(order)

    await process_refund(_refund_event(), mock_db)

    # No audit log created, no commit
    mock_db.add.assert_not_called()
    mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_refund_order_not_found(mock_db):
    """Refund for unknown payment intent is a no-op."""
    mock_db.execute.return_value = _mock_select_result(None)

    await process_refund(_refund_event(), mock_db)

    mock_db.add.assert_not_called()
    mock_db.commit.assert_not_awaited()


# --- Enrollment Revocation ---


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_revoke_enrollment_success(mock_lms_cls):
    """Single enrollment revocation calls LMS deactivate API."""
    mock_lms = MagicMock()
    mock_lms.deactivate_enrollment = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    result = await revoke_enrollment("testuser", "course-v1:Test+101+2024")

    assert result is True
    mock_lms.deactivate_enrollment.assert_awaited_once_with(
        "testuser", "course-v1:Test+101+2024"
    )


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_revoke_enrollment_failure(mock_lms_cls):
    """Failed enrollment revocation returns False."""
    mock_lms = MagicMock()
    mock_lms.deactivate_enrollment = AsyncMock(return_value=False)
    mock_lms_cls.return_value = mock_lms

    result = await revoke_enrollment("testuser", "course-v1:Test+101+2024")

    assert result is False


# --- Multiple Line Items ---


@pytest.mark.asyncio
@patch("app.services.refund.LMSClient")
async def test_full_refund_multiple_items(mock_lms_cls, mock_db):
    """Full refund revokes all enrollments across multiple line items."""
    order_id = uuid.uuid4()
    items = [
        LineItem(
            id=uuid.uuid4(),
            order_id=order_id,
            offering_uuid=uuid.UUID(int=10),
            offering_type="course_seat",
            lms_resource_id="course-v1:Test+101+2024",
            quantity=1,
            unit_price_cents=2500,
            total_price_cents=2500,
            fulfillment_status=FulfillmentStatus.fulfilled,
        ),
        LineItem(
            id=uuid.uuid4(),
            order_id=order_id,
            offering_uuid=uuid.UUID(int=11),
            offering_type="course_seat",
            lms_resource_id="course-v1:Test+102+2024",
            quantity=1,
            unit_price_cents=2500,
            total_price_cents=2500,
            fulfillment_status=FulfillmentStatus.fulfilled,
        ),
    ]
    order = _make_order(line_items=items)

    mock_db.execute.return_value = _mock_select_result(order)

    mock_lms = MagicMock()
    mock_lms.get_user_by_email = AsyncMock(return_value={"username": "testuser", "id": 42})
    mock_lms.deactivate_enrollment = AsyncMock(return_value=True)
    mock_lms_cls.return_value = mock_lms

    await process_refund(_refund_event(), mock_db)

    assert order.status == OrderStatus.refunded
    assert mock_lms.deactivate_enrollment.await_count == 2
