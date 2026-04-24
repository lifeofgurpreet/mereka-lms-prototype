"""Integration tests for admin entitlement action endpoints."""
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


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
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
async def test_revoke_entitlement_without_auth_returns_401(mock_settings, client):
    """POST /admin/entitlements/{id}/revoke/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.post(f"/api/v1/admin/entitlements/{uuid.uuid4()}/revoke/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_revoke_entitlement_with_auth_returns_200(mock_settings, client):
    """POST /admin/entitlements/{id}/revoke/ revokes entitlement."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    entitlement = _make_entitlement()
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(entitlement)
    mock_db.commit = AsyncMock()

    async def _fake_refresh(obj):
        obj.updated_at = datetime(2024, 1, 2, tzinfo=UTC)

    mock_db.refresh.side_effect = _fake_refresh

    _override_db(mock_db)
    try:
        resp = await client.post(
            f"/api/v1/admin/entitlements/{entitlement.id}/revoke/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert payload["id"] == str(entitlement.id)
    assert payload["status"] == "revoked"


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_revoke_entitlement_not_found_returns_404(mock_settings, client):
    """POST /admin/entitlements/{id}/revoke/ returns 404 when missing."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_select_result(None)

    _override_db(mock_db)
    try:
        resp = await client.post(
            f"/api/v1/admin/entitlements/{uuid.uuid4()}/revoke/",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 404
