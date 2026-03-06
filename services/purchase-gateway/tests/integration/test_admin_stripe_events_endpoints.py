"""Integration tests for admin Stripe event endpoints."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.database import get_db
from app.main import app
from app.models.stripe_event import ProcessingStatus, StripeEvent

VALID_API_KEY = "test-admin-key-for-integration"
HEADERS = {"X-API-Key": VALID_API_KEY}


def _make_event(**overrides) -> StripeEvent:
    defaults = {
        "id": uuid.uuid4(),
        "stripe_event_id": "evt_test_int_1",
        "event_type": "checkout.session.completed",
        "payload_json": {"id": "evt_test_int_1", "object": "event"},
        "processing_status": ProcessingStatus.processed,
        "received_at": datetime(2024, 1, 1, tzinfo=UTC),
        "processed_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return StripeEvent(**defaults)


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_stripe_events_without_auth_returns_401(mock_settings, client):
    """GET /admin/stripe-events/ without API key is rejected."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    resp = await client.get("/api/v1/admin/stripe-events/")

    assert resp.status_code == 401


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_stripe_events_with_valid_auth_returns_200(mock_settings, client):
    """GET /admin/stripe-events/ returns summaries and omits payload by default."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    event = _make_event(payload_json={"sensitive": "value"})
    scalars = MagicMock()
    scalars.all.return_value = [event]
    mock_result = MagicMock()
    mock_result.scalars.return_value = scalars

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result

    _override_db(mock_db)
    try:
        resp = await client.get("/api/v1/admin/stripe-events/", headers=HEADERS)
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    payload = resp.json()
    assert len(payload) == 1
    assert payload[0]["stripe_event_id"] == "evt_test_int_1"
    assert payload[0]["processing_status"] == "processed"
    assert payload[0]["payload_json"] is None


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_list_stripe_events_include_payload_true(mock_settings, client):
    """GET /admin/stripe-events/?include_payload=true includes raw payload_json."""
    mock_settings.ADMIN_API_KEY = VALID_API_KEY

    payload_json = {"id": "evt_payload", "type": "charge.refunded"}
    event = _make_event(
        stripe_event_id="evt_payload",
        event_type="charge.refunded",
        payload_json=payload_json,
        processing_status=ProcessingStatus.failed,
    )
    scalars = MagicMock()
    scalars.all.return_value = [event]
    mock_result = MagicMock()
    mock_result.scalars.return_value = scalars

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result

    _override_db(mock_db)
    try:
        resp = await client.get(
            "/api/v1/admin/stripe-events/?include_payload=true",
            headers=HEADERS,
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["stripe_event_id"] == "evt_payload"
    assert data[0]["processing_status"] == "failed"
    assert data[0]["payload_json"] == payload_json
