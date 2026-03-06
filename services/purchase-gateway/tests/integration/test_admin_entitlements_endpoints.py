"""Integration tests for admin entitlements endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.entitlement import Entitlement, EntitlementStatus

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}
TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
LINE_ITEM_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_entitlement(**overrides) -> Entitlement:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": TENANT_ID,
        "order_id": ORDER_ID,
        "line_item_id": LINE_ITEM_ID,
        "recipient_email": "learner@example.com",
        "lms_resource_id": "course-v1:Test+101+2024",
        "offering_type": "course_seat",
        "status": EntitlementStatus.pending,
        "claim_token": "claim-token-http",
        "claimed_by_user_id": None,
        "expires_at": datetime(2024, 2, 1, tzinfo=UTC),
        "claimed_at": None,
        "invitation_sent_at": datetime(2024, 1, 1, tzinfo=UTC),
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Entitlement(**defaults)


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_entitlements_without_auth_returns_401(mock_settings, client):
    """GET /admin/entitlements/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get("/api/v1/admin/entitlements/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_entitlements_with_auth_returns_200(mock_settings, client):
    """GET /admin/entitlements/ returns entitlement records."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    ent = _make_entitlement(status=EntitlementStatus.claimed)
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_scalars_result([ent])

    _override_db(mock_db)
    try:
        resp = await client.get(
            "/api/v1/admin/entitlements/?status=claimed&recipient_email=learner@example.com",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert len(payload) == 1
    assert payload[0]["recipient_email"] == "learner@example.com"
    assert payload[0]["status"] == "claimed"
