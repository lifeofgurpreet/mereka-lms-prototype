"""Integration tests for admin tenant reports endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from collections import namedtuple
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}
TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000000")

AggRow = namedtuple(
    "AggRow",
    [
        "order_count",
        "gross_revenue_cents",
        "refunded",
        "partially_refunded",
        "fulfillment_failed",
        "pending",
    ],
)


def _mock_agg_result(row):
    result = MagicMock()
    result.one.return_value = row
    return result


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
    mock_settings.ADMIN_JWT_SECRET = ""
    mock_settings.ADMIN_JWT_ALGORITHMS = ["HS256"]
    mock_settings.ADMIN_JWT_ISSUER = None
    mock_settings.ADMIN_JWT_AUDIENCE = None
    mock_settings.ADMIN_ALLOWED_ROLES = ["payments_admin"]
    mock_settings.ADMIN_REQUIRE_JWT = False

    resp = await client.get(f"/api/v1/admin/tenants/{TENANT_ID}/reports/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_tenant_reports_with_auth_returns_200(mock_settings, client):
    """GET reports returns aggregated tenant metrics via SQL."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY
    mock_settings.ADMIN_JWT_SECRET = ""
    mock_settings.ADMIN_JWT_ALGORITHMS = ["HS256"]
    mock_settings.ADMIN_JWT_ISSUER = None
    mock_settings.ADMIN_JWT_AUDIENCE = None
    mock_settings.ADMIN_ALLOWED_ROLES = ["payments_admin"]
    mock_settings.ADMIN_REQUIRE_JWT = False

    row = AggRow(
        order_count=3,
        gross_revenue_cents=12000,
        refunded=1,
        partially_refunded=0,
        fulfillment_failed=0,
        pending=1,
    )
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_agg_result(row)

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
