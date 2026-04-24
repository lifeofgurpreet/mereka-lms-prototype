"""Unit tests for admin refund endpoint."""
# @covers AC-015, AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order, OrderStatus
from app.routers.admin_refunds import CreateRefundRequest, create_order_refund

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


def _make_order(**overrides) -> Order:
    defaults = {
        "id": ORDER_ID,
        "tenant_id": TENANT_ID,
        "buyer_email": "buyer@example.com",
        "buyer_user_id": 42,
        "stripe_checkout_session_id": "cs_test_manual_refund",
        "stripe_payment_intent_id": "pi_manual_refund",
        "status": OrderStatus.fulfilled,
        "total_cents": 9900,
        "currency": "USD",
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Order(**defaults)


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


@pytest.mark.asyncio
@patch("app.routers.admin_refunds.stripe.Refund.create")
async def test_create_order_refund_success(mock_refund_create, mock_db):
    """Manual refund calls Stripe and returns normalized response payload."""
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(order)
    mock_refund_create.return_value = {
        "id": "re_test_123",
        "status": "succeeded",
        "amount": 3000,
        "currency": "usd",
    }

    response = await create_order_refund(
        order_id=order.id,
        request_body=CreateRefundRequest(
            amount_cents=3000,
            reason="requested_by_customer",
        ),
        request=_request_no_tenant(),
        db=mock_db,
    )

    mock_refund_create.assert_called_once()
    kwargs = mock_refund_create.call_args.kwargs
    assert kwargs["payment_intent"] == "pi_manual_refund"
    assert kwargs["amount"] == 3000
    assert kwargs["reason"] == "requested_by_customer"
    assert response.order_id == order.id
    assert response.stripe_refund_id == "re_test_123"
    assert response.stripe_refund_status == "succeeded"
    assert response.amount_cents == 3000
    assert response.currency == "USD"


@pytest.mark.asyncio
async def test_create_order_refund_not_found_returns_404(mock_db):
    """Missing order returns HTTP 404."""
    mock_db.execute.return_value = _mock_select_result(None)

    with pytest.raises(HTTPException) as exc_info:
        await create_order_refund(
            order_id=uuid.uuid4(),
            request_body=CreateRefundRequest(),
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_create_order_refund_missing_payment_intent_returns_409(mock_db):
    """Orders without Stripe payment intent cannot be refunded."""
    order = _make_order(stripe_payment_intent_id=None)
    mock_db.execute.return_value = _mock_select_result(order)

    with pytest.raises(HTTPException) as exc_info:
        await create_order_refund(
            order_id=order.id,
            request_body=CreateRefundRequest(),
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 409
    assert "cannot be refunded" in exc_info.value.detail


@pytest.mark.asyncio
async def test_create_order_refund_rejects_amount_above_total(mock_db):
    """Requested refund amount cannot exceed order total."""
    order = _make_order(total_cents=5000)
    mock_db.execute.return_value = _mock_select_result(order)

    with pytest.raises(HTTPException) as exc_info:
        await create_order_refund(
            order_id=order.id,
            request_body=CreateRefundRequest(amount_cents=6000),
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 400
    assert "exceeds order total" in exc_info.value.detail
