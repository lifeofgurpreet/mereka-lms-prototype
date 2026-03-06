"""Integration tests for admin tenant reports endpoint."""
# @covers AC-019, AC-022
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
TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000000")


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_order(*, status: OrderStatus, total_cents: int) -> Order:
    return Order(
        id=uuid.uuid4(),
        tenant_id=TENANT_ID,
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=f"cs_{uuid.uuid4().hex[:12]}",
        stripe_payment_intent_id=f"pi_{uuid.uuid4().hex[:12]}",
        status=status,
        total_cents=total_cents,
        currency="USD",
        created_at=datetime(2024, 1, 1, tzinfo=UTC),
        updated_at=datetime(2024, 1, 1, tzinfo=UTC),
    )


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_tenant_reports_without_auth_returns_401(mock_settings, client):
    """GET /admin/tenants/{tenant}/reports/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get(f"/api/v1/admin/tenants/{TENANT_ID}/reports/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_tenant_reports_with_auth_returns_200(mock_settings, client):
    """GET reports returns aggregated tenant metrics."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    orders = [
        _make_order(status=OrderStatus.fulfilled, total_cents=10000),
        _make_order(status=OrderStatus.refunded, total_cents=2000),
        _make_order(status=OrderStatus.pending, total_cents=1500),
    ]
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_scalars_result(orders)

    _override_db(mock_db)
    try:
        resp = await client.get(
            f"/api/v1/admin/tenants/{TENANT_ID}/reports/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert payload["tenant_id"] == str(TENANT_ID)
    assert payload["order_count"] == 3
    assert payload["gross_revenue_cents"] == 12000
    assert payload["refunded_order_count"] == 1
    assert payload["refund_rate_percent"] == 33.33
