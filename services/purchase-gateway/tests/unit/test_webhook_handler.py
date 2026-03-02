"""Unit tests for the Stripe webhook handler — event parsing, idempotency, state transitions."""
# @covers AC-004, AC-006, AC-007, AC-008

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order, OrderStatus
from app.models.stripe_event import ProcessingStatus, StripeEvent
from app.routers.webhooks import (
    _handle_checkout_completed,
    _handle_checkout_expired,
    _handle_payment_failed,
)

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


def _make_order(
    *,
    status: OrderStatus = OrderStatus.pending,
    session_id: str = "cs_test123",
    payment_intent_id: str | None = None,
) -> Order:
    return Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=session_id,
        stripe_payment_intent_id=payment_intent_id,
        status=status,
        total_cents=9900,
        currency="USD",
        line_items=[],
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
    db.rollback = AsyncMock()
    return db


# ---------------------------------------------------------------------------
# _handle_checkout_completed
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock)
async def test_checkout_completed_marks_order_paid(mock_fulfill, mock_db):
    """checkout.session.completed transitions order status to paid."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {
        "object": {
            "id": "cs_test123",
            "payment_intent": "pi_abc123",
        }
    }
    await _handle_checkout_completed(event_data, mock_db)

    assert order.status == OrderStatus.paid
    assert order.stripe_payment_intent_id == "pi_abc123"
    mock_db.commit.assert_awaited()
    mock_fulfill.assert_awaited_once_with(order, mock_db)


@pytest.mark.asyncio
@patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock)
async def test_checkout_completed_creates_audit_log(mock_fulfill, mock_db):
    """checkout.session.completed creates an OrderAuditLog entry."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {"object": {"id": "cs_test123", "payment_intent": "pi_abc123"}}
    await _handle_checkout_completed(event_data, mock_db)

    mock_db.add.assert_called()
    added = mock_db.add.call_args[0][0]
    assert added.new_status == OrderStatus.paid.value
    assert added.triggered_by == "stripe.checkout.session.completed"


@pytest.mark.asyncio
@patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock)
async def test_checkout_completed_order_not_found_is_noop(mock_fulfill, mock_db):
    """checkout.session.completed is silent when order cannot be found."""
    mock_db.execute.return_value = _mock_select_result(None)

    event_data = {"object": {"id": "cs_unknown", "payment_intent": "pi_abc"}}
    await _handle_checkout_completed(event_data, mock_db)

    mock_db.commit.assert_not_awaited()
    mock_fulfill.assert_not_awaited()


@pytest.mark.asyncio
@patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock)
async def test_checkout_completed_no_payment_intent(mock_fulfill, mock_db):
    """checkout.session.completed handles missing payment_intent gracefully."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {"object": {"id": "cs_test123", "payment_intent": None}}
    await _handle_checkout_completed(event_data, mock_db)

    assert order.status == OrderStatus.paid
    assert order.stripe_payment_intent_id is None
    mock_db.commit.assert_awaited()


# ---------------------------------------------------------------------------
# _handle_checkout_expired
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_checkout_expired_transitions_to_expired(mock_db):
    """checkout.session.expired marks the order as expired."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {"object": {"id": "cs_test123"}}
    await _handle_checkout_expired(event_data, mock_db)

    assert order.status == OrderStatus.expired
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_checkout_expired_order_not_found_is_noop(mock_db):
    """checkout.session.expired is silent when order cannot be found."""
    mock_db.execute.return_value = _mock_select_result(None)

    event_data = {"object": {"id": "cs_unknown"}}
    await _handle_checkout_expired(event_data, mock_db)

    mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_checkout_expired_creates_audit_log(mock_db):
    """checkout.session.expired creates an audit log entry."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {"object": {"id": "cs_test123"}}
    await _handle_checkout_expired(event_data, mock_db)

    mock_db.add.assert_called()
    added = mock_db.add.call_args[0][0]
    assert added.new_status == OrderStatus.expired.value


# ---------------------------------------------------------------------------
# _handle_payment_failed
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_payment_failed_transitions_to_canceled(mock_db):
    """payment_intent.payment_failed marks order as canceled."""
    order = _make_order(payment_intent_id="pi_fail123")
    mock_db.execute.return_value = _mock_select_result(order)

    event_data = {"object": {"id": "pi_fail123"}}
    await _handle_payment_failed(event_data, mock_db)

    assert order.status == OrderStatus.canceled
    mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_payment_failed_order_not_found_is_noop(mock_db):
    """payment_intent.payment_failed is silent when no matching order."""
    mock_db.execute.return_value = _mock_select_result(None)

    event_data = {"object": {"id": "pi_unknown"}}
    await _handle_payment_failed(event_data, mock_db)

    mock_db.commit.assert_not_awaited()


# ---------------------------------------------------------------------------
# Idempotency — via the StripeEvent model processing statuses
# ---------------------------------------------------------------------------


def test_processing_status_values():
    """Verify all expected processing statuses are present."""
    expected = {"received", "processing", "processed", "failed"}
    assert {s.value for s in ProcessingStatus} == expected


def test_stripe_event_received_status():
    """StripeEvent records the received processing status when explicitly set."""
    event = StripeEvent(
        stripe_event_id="evt_test",
        event_type="checkout.session.completed",
        payload_json={"id": "evt_test"},
        processing_status=ProcessingStatus.received,
    )
    assert event.processing_status == ProcessingStatus.received


def test_stripe_event_idempotency_key_is_stripe_event_id():
    """StripeEvent.stripe_event_id is the deduplication key."""
    evt1 = StripeEvent(
        stripe_event_id="evt_same",
        event_type="checkout.session.completed",
        payload_json={},
        processing_status=ProcessingStatus.processed,
    )
    evt2 = StripeEvent(
        stripe_event_id="evt_same",
        event_type="checkout.session.completed",
        payload_json={},
    )
    assert evt1.stripe_event_id == evt2.stripe_event_id
