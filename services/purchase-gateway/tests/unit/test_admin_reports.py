"""Unit tests for admin tenant reports endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order, OrderStatus
from app.routers.admin_reports import get_tenant_report

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_order(
    *,
    status: OrderStatus,
    total_cents: int,
    tenant_id: uuid.UUID = TENANT_ID,
) -> Order:
    return Order(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=f"cs_{uuid.uuid4().hex[:12]}",
        stripe_payment_intent_id=f"pi_{uuid.uuid4().hex[:12]}",
        status=status,
        total_cents=total_cents,
        currency="USD",
        created_at=datetime(2024, 1, 1, tzinfo=UTC),
        updated_at=datetime(2024, 1, 1, tzinfo=UTC),
    )


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


@pytest.mark.asyncio
async def test_get_tenant_report_aggregates_metrics(mock_db):
    """Report aggregates counts, revenue, and refund rate from tenant orders."""
    orders = [
        _make_order(status=OrderStatus.fulfilled, total_cents=10000),
        _make_order(status=OrderStatus.refunded, total_cents=2000),
        _make_order(status=OrderStatus.partially_refunded, total_cents=5000),
        _make_order(status=OrderStatus.fulfillment_failed, total_cents=7000),
        _make_order(status=OrderStatus.pending, total_cents=3000),
    ]
    mock_db.execute.return_value = _mock_scalars_result(orders)

    report = await get_tenant_report(
        tenant_id=TENANT_ID,
        request=_request_no_tenant(),
        db=mock_db,
    )

    assert report.order_count == 5
    assert report.gross_revenue_cents == 24000
    assert report.refunded_order_count == 1
    assert report.partially_refunded_order_count == 1
    assert report.fulfillment_failed_order_count == 1
    assert report.pending_order_count == 1
    assert report.refund_rate_percent == 40.0


@pytest.mark.asyncio
async def test_get_tenant_report_forbidden_for_mismatched_tenant_scope(mock_db):
    """If middleware tenant scope mismatches path tenant, request is forbidden."""
    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = uuid.UUID("00000000-0000-0000-0000-000000000099")

    with pytest.raises(HTTPException) as exc_info:
        await get_tenant_report(
            tenant_id=TENANT_ID,
            request=request,
            db=mock_db,
        )

    assert exc_info.value.status_code == 403
