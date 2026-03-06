"""Integration tests for admin order-detail endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.fulfillment_job import FulfillmentJob, FulfillmentJobStatus
from app.models.order import (
    FulfillmentStatus,
    LineItem,
    Order,
    OrderAuditLog,
    OrderStatus,
)

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}
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
        "stripe_checkout_session_id": "cs_test_order_detail_http",
        "stripe_payment_intent_id": "pi_test_order_detail_http",
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


def _make_job(**overrides) -> FulfillmentJob:
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


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_order_detail_without_auth_returns_401(mock_settings, client):
    """GET /admin/orders/{id}/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get(f"/api/v1/admin/orders/{ORDER_ID}/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_order_detail_with_auth_returns_200(mock_settings, client):
    """GET /admin/orders/{id}/ returns order with nested line items and audit logs."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    order = _make_order()
    line_item = _make_line_item()
    audit_entry = _make_audit_log()
    job = _make_job()

    mock_db = AsyncMock()
    mock_db.execute.side_effect = [
        _mock_select_result(order),
        _mock_scalars_result([line_item]),
        _mock_scalars_result([audit_entry]),
        _mock_select_result(job),
    ]

    _override_db(mock_db)
    try:
        resp = await client.get(
            f"/api/v1/admin/orders/{ORDER_ID}/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert payload["id"] == str(ORDER_ID)
    assert payload["status"] == "fulfillment_failed"
    assert len(payload["line_items"]) == 1
    assert payload["line_items"][0]["fulfillment_status"] == "failed"
    assert len(payload["audit_log"]) == 1
    assert payload["audit_log"][0]["new_status"] == "fulfillment_failed"
    assert payload["fulfillment_job"] is not None
    assert payload["fulfillment_job"]["status"] == "failed"
