"""Unit tests for admin order-detail endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.fulfillment_job import FulfillmentJob, FulfillmentJobStatus
from app.models.order import (
    FulfillmentStatus,
    LineItem,
    Order,
    OrderAuditLog,
    OrderStatus,
)
from app.routers.admin_orders import get_order_detail

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")


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


def _make_order(**overrides) -> Order:
    defaults = {
        "id": ORDER_ID,
        "tenant_id": TENANT_ID,
        "buyer_email": "buyer@example.com",
        "stripe_checkout_session_id": "cs_test_order_detail",
        "stripe_payment_intent_id": "pi_test_order_detail",
        "status": OrderStatus.fulfillment_failed,
        "total_cents": 9900,
        "currency": "USD",
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 2, tzinfo=UTC),
        "fulfilled_at": None,
        "refunded_at": None,
    }
    defaults.update(overrides)
    return Order(**defaults)


def _make_line_item(**overrides) -> LineItem:
    defaults = {
        "id": uuid.uuid4(),
        "order_id": ORDER_ID,
        "offering_uuid": uuid.uuid4(),
        "offering_type": "course_seat",
        "lms_resource_id": "course-v1:Test+101+2024",
        "quantity": 1,
        "unit_price_cents": 9900,
        "total_price_cents": 9900,
        "fulfillment_status": FulfillmentStatus.failed,
    }
    defaults.update(overrides)
    return LineItem(**defaults)


def _make_audit_log(**overrides) -> OrderAuditLog:
    defaults = {
        "id": uuid.uuid4(),
        "order_id": ORDER_ID,
        "old_status": "paid",
        "new_status": "fulfillment_failed",
        "triggered_by": "fulfillment.outbox.dead_letter",
        "timestamp": datetime(2024, 1, 2, tzinfo=UTC),
        "details": {"reason": "lms timeout"},
    }
    defaults.update(overrides)
    return OrderAuditLog(**defaults)


def _make_fulfillment_job(**overrides) -> FulfillmentJob:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": TENANT_ID,
        "order_id": ORDER_ID,
        "status": FulfillmentJobStatus.failed,
        "attempts": 10,
        "max_attempts": 10,
        "next_attempt_at": datetime(2024, 1, 2, tzinfo=UTC),
        "last_attempt_at": datetime(2024, 1, 2, tzinfo=UTC),
        "completed_at": datetime(2024, 1, 2, tzinfo=UTC),
        "last_error": "network timeout",
        "triggered_by": "fulfillment.reconciliation",
    }
    defaults.update(overrides)
    return FulfillmentJob(**defaults)


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


@pytest.mark.asyncio
async def test_get_order_detail_returns_order_line_items_audit_and_job(mock_db):
    """Order detail returns nested line items, audit timeline, and job metadata."""
    order = _make_order()
    line_item = _make_line_item()
    audit_entry = _make_audit_log()
    job = _make_fulfillment_job()

    mock_db.execute.side_effect = [
        _mock_select_result(order),
        _mock_scalars_result([line_item]),
        _mock_scalars_result([audit_entry]),
        _mock_select_result(job),
    ]

    request = MagicMock()
    request.state = MagicMock(spec=[])

    result = await get_order_detail(order.id, request, mock_db)

    assert result.id == order.id
    assert result.status == "fulfillment_failed"
    assert len(result.line_items) == 1
    assert result.line_items[0].fulfillment_status == "failed"
    assert len(result.audit_log) == 1
    assert result.audit_log[0].new_status == "fulfillment_failed"
    assert result.fulfillment_job is not None
    assert result.fulfillment_job.status == "failed"


@pytest.mark.asyncio
async def test_get_order_detail_returns_404_when_order_not_found(mock_db):
    """Missing order returns HTTP 404."""
    mock_db.execute.return_value = _mock_select_result(None)

    request = MagicMock()
    request.state = MagicMock(spec=[])

    with pytest.raises(HTTPException) as exc_info:
        await get_order_detail(uuid.uuid4(), request, mock_db)

    assert exc_info.value.status_code == 404
    assert "Order not found" in exc_info.value.detail
