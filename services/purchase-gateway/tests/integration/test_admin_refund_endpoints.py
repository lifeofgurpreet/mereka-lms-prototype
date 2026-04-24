"""Integration tests for admin refund endpoint."""
# @covers AC-015, AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.order import Order, OrderStatus

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}
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
        "stripe_checkout_session_id": "cs_test_manual_refund_http",
        "stripe_payment_intent_id": "pi_manual_refund_http",
        "status": OrderStatus.fulfilled,
        "total_cents": 9900,
        "currency": "USD",
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Order(**defaults)


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_refund_without_auth_returns_401(mock_settings, client):
    """POST /admin/orders/{id}/refund/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.post(f"/api/v1/admin/orders/{ORDER_ID}/refund/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
@patch("app.routers.admin_refunds.stripe.Refund.create")
async def test_refund_with_auth_returns_200(mock_refund_create, mock_settings, client):
    """POST /admin/orders/{id}/refund/ creates Stripe refund request."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY
    mock_refund_create.return_value = {
        "id": "re_http_123",
        "status": "pending",
        "amount": 2500,
        "currency": "usd",
    }

    order = _make_order()
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(order)

    _override_db(mock_db)
    try:
        resp = await client.post(
            f"/api/v1/admin/orders/{ORDER_ID}/refund/",
            headers=HEADERS,
            json={"amount_cents": 2500, "reason": "requested_by_customer"},
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert payload["order_id"] == str(ORDER_ID)
    assert payload["stripe_refund_id"] == "re_http_123"
    assert payload["stripe_refund_status"] == "pending"
    assert payload["amount_cents"] == 2500
    assert payload["state_update_mode"] == "webhook_async"


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_refund_missing_payment_intent_returns_409(mock_settings, client):
    """Refund request for non-chargeable order is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    order = _make_order(stripe_payment_intent_id=None)
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(order)

    _override_db(mock_db)
    try:
        resp = await client.post(
            f"/api/v1/admin/orders/{ORDER_ID}/refund/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 409
    assert "cannot be refunded" in resp.json()["detail"]
