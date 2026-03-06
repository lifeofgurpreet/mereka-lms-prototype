"""Integration tests for admin offerings listing endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.offering import Offering, OfferingType

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}
TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
OTHER_TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000009")


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_offering(**overrides) -> Offering:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": TENANT_ID,
        "offering_type": OfferingType.course_seat,
        "title": "Test Course",
        "description": "A test offering",
        "price_cents": 9900,
        "currency": "USD",
        "stripe_price_id": f"price_{uuid.uuid4().hex[:12]}",
        "lms_resource_id": "course-v1:Test+101+2024",
        "active": True,
        "metadata_json": None,
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Offering(**defaults)


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_offerings_without_auth_returns_401(mock_settings, client):
    """GET /admin/offerings/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get("/api/v1/admin/offerings/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_offerings_with_auth_returns_200(mock_settings, client):
    """GET /admin/offerings/ returns offerings with filters applied."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    offering = _make_offering(offering_type=OfferingType.seat_pack, active=True)
    mock_db = AsyncMock()
    mock_db.execute.return_value = _mock_scalars_result([offering])

    _override_db(mock_db)
    try:
        resp = await client.get(
            "/api/v1/admin/offerings/?offering_type=seat_pack&active=true",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert len(payload) == 1
    assert payload[0]["offering_type"] == "seat_pack"
    assert payload[0]["active"] is True


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_offerings_tenant_scope_mismatch_returns_403(mock_settings, client):
    """GET /admin/offerings/ rejects conflicting tenant_id query and header scope."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    mock_db = AsyncMock()
    _override_db(mock_db)
    try:
        resp = await client.get(
            "/api/v1/admin/offerings/",
            headers={
                "X-API-Key": VALID_API_KEY,
                "X-Tenant-ID": str(TENANT_ID),
            },
            params={"tenant_id": str(OTHER_TENANT_ID)},
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 403
    assert "Tenant scope mismatch" in resp.json()["detail"]
    mock_db.execute.assert_not_awaited()
