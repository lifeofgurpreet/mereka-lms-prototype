"""Unit tests for admin Stripe event endpoints."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stripe_event import ProcessingStatus, StripeEvent
from app.routers.admin_events import list_stripe_events


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_event(**overrides) -> StripeEvent:
    defaults = {
        "id": uuid.uuid4(),
        "stripe_event_id": "evt_test_1",
        "event_type": "checkout.session.completed",
        "payload_json": {"id": "evt_test_1", "object": "event"},
        "processing_status": ProcessingStatus.processed,
        "received_at": datetime(2024, 1, 1, tzinfo=UTC),
        "processed_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return StripeEvent(**defaults)


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    return db


@pytest.mark.asyncio
async def test_list_stripe_events_omits_payload_by_default(mock_db):
    """payload_json is omitted unless include_payload=true."""
    event = _make_event(payload_json={"secret": "hidden"})
    mock_db.execute.return_value = _mock_scalars_result([event])

    result = await list_stripe_events(
        db=mock_db,
        include_payload=False,
        event_type=None,
        processing_status=None,
        stripe_event_id=None,
        limit=50,
        offset=0,
    )

    assert len(result) == 1
    assert result[0].stripe_event_id == "evt_test_1"
    assert result[0].processing_status == "processed"
    assert result[0].payload_json is None


@pytest.mark.asyncio
async def test_list_stripe_events_includes_payload_when_requested(mock_db):
    """payload_json is returned when include_payload=true."""
    payload = {"id": "evt_test_2", "object": "event", "type": "payment_intent.succeeded"}
    event = _make_event(
        stripe_event_id="evt_test_2",
        event_type="payment_intent.succeeded",
        payload_json=payload,
        processing_status=ProcessingStatus.failed,
    )
    mock_db.execute.return_value = _mock_scalars_result([event])

    result = await list_stripe_events(
        db=mock_db,
        include_payload=True,
        event_type=None,
        processing_status=None,
        stripe_event_id=None,
        limit=50,
        offset=0,
    )

    assert len(result) == 1
    assert result[0].stripe_event_id == "evt_test_2"
    assert result[0].processing_status == "failed"
    assert result[0].payload_json == payload
