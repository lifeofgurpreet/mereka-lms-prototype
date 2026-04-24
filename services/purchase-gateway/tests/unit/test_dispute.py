"""Unit tests for dispute handlers in purchase-gateway."""
# @covers AC-017, AC-018
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order, OrderStatus
from app.services.dispute import handle_dispute_closed, handle_dispute_created


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.add = MagicMock()
    return db


def _make_order(*, status: OrderStatus = OrderStatus.paid) -> Order:
    return Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=f"cs_{uuid.uuid4().hex[:8]}",
        stripe_payment_intent_id=f"pi_{uuid.uuid4().hex[:8]}",
        status=status,
        total_cents=9900,
        currency="USD",
        line_items=[],
    )


@pytest.mark.asyncio
async def test_handle_dispute_created_no_order_is_noop(mock_db):
    event_data = {"object": {"id": "dp_123", "reason": "fraudulent", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=None),
    ):
        await handle_dispute_created(event_data, mock_db)

    mock_db.commit.assert_not_awaited()
    mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_handle_dispute_created_marks_disputed_and_logs_audit(mock_db):
    order = _make_order(status=OrderStatus.paid)
    event_data = {"object": {"id": "dp_123", "reason": "fraudulent", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=order),
    ), patch(
        "app.services.dispute._revoke_order_enrollments",
        new=AsyncMock(),
    ) as mock_revoke, patch(
        "app.services.dispute.settings.ENABLE_AUTO_REVOKE_ON_DISPUTE",
        False,
    ):
        await handle_dispute_created(event_data, mock_db)

    assert order.status == OrderStatus.disputed
    mock_db.commit.assert_awaited_once()
    mock_revoke.assert_not_awaited()
    mock_db.add.assert_called_once()
    audit = mock_db.add.call_args[0][0]
    assert audit.old_status == OrderStatus.paid.value
    assert audit.new_status == OrderStatus.disputed.value
    assert audit.triggered_by == "stripe.charge.dispute.created"
    assert audit.details == {"dispute_id": "dp_123", "reason": "fraudulent"}


@pytest.mark.asyncio
async def test_handle_dispute_created_is_idempotent_for_disputed_order(mock_db):
    order = _make_order(status=OrderStatus.disputed)
    event_data = {"object": {"id": "dp_123", "reason": "fraudulent", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=order),
    ):
        await handle_dispute_created(event_data, mock_db)

    mock_db.commit.assert_not_awaited()
    mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_handle_dispute_created_auto_revokes_when_flag_enabled(mock_db):
    order = _make_order(status=OrderStatus.paid)
    event_data = {"object": {"id": "dp_123", "reason": "fraudulent", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=order),
    ), patch(
        "app.services.dispute._revoke_order_enrollments",
        new=AsyncMock(),
    ) as mock_revoke, patch(
        "app.services.dispute.settings.ENABLE_AUTO_REVOKE_ON_DISPUTE",
        True,
    ):
        await handle_dispute_created(event_data, mock_db)

    assert order.status == OrderStatus.disputed
    mock_revoke.assert_awaited_once_with(order)
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_handle_dispute_closed_won_restores_order_and_enrollments(mock_db):
    order = _make_order(status=OrderStatus.disputed)
    event_data = {"object": {"id": "dp_123", "status": "won", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=order),
    ), patch(
        "app.services.dispute._restore_order_enrollments",
        new=AsyncMock(),
    ) as mock_restore, patch(
        "app.services.dispute._revoke_order_enrollments",
        new=AsyncMock(),
    ) as mock_revoke:
        await handle_dispute_closed(event_data, mock_db)

    assert order.status == OrderStatus.paid
    mock_restore.assert_awaited_once_with(order)
    mock_revoke.assert_not_awaited()
    mock_db.commit.assert_awaited_once()
    audit = mock_db.add.call_args[0][0]
    assert audit.details["action"] == "dispute_won_restored"
    assert audit.details["outcome"] == "won"


@pytest.mark.asyncio
async def test_handle_dispute_closed_lost_refunds_and_revokes(mock_db):
    order = _make_order(status=OrderStatus.disputed)
    event_data = {"object": {"id": "dp_123", "status": "lost", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=order),
    ), patch(
        "app.services.dispute._restore_order_enrollments",
        new=AsyncMock(),
    ) as mock_restore, patch(
        "app.services.dispute._revoke_order_enrollments",
        new=AsyncMock(),
    ) as mock_revoke:
        await handle_dispute_closed(event_data, mock_db)

    assert order.status == OrderStatus.refunded
    assert order.refunded_at is not None
    mock_revoke.assert_awaited_once_with(order)
    mock_restore.assert_not_awaited()
    mock_db.commit.assert_awaited_once()
    audit = mock_db.add.call_args[0][0]
    assert audit.details["action"] == "dispute_lost_refunded"
    assert audit.details["outcome"] == "lost"


@pytest.mark.asyncio
async def test_handle_dispute_closed_no_order_is_noop(mock_db):
    event_data = {"object": {"id": "dp_123", "status": "won", "charge": "ch_123"}}

    with patch(
        "app.services.dispute._find_order_by_dispute",
        new=AsyncMock(return_value=None),
    ):
        await handle_dispute_closed(event_data, mock_db)

    mock_db.commit.assert_not_awaited()
    mock_db.add.assert_not_called()
