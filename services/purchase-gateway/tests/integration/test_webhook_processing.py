"""Integration tests for Stripe webhook processing — signature, idempotency, error handling."""
# @covers AC-004, AC-006, AC-007, AC-008, AC-015, AC-016, AC-017, AC-018
# @spec: ecommerce-purchase-gateway_spec.md

import hashlib
import hmac
import json
import time
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.database import get_db
from app.main import app
from app.models.order import Order, OrderStatus
from app.models.stripe_event import ProcessingStatus, StripeEvent

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _sign_payload(payload: bytes, secret: str) -> str:
    """Build a valid Stripe-Signature header for the given payload and secret."""
    timestamp = str(int(time.time()))
    signed = f"{timestamp}.{payload.decode()}"
    sig = hmac.new(secret.encode(), signed.encode(), hashlib.sha256).hexdigest()
    return f"t={timestamp},v1={sig}"


def _checkout_event(session_id: str | None = None) -> dict:
    session_id = session_id or f"cs_{uuid.uuid4().hex[:16]}"
    return {
        "id": f"evt_{uuid.uuid4().hex[:16]}",
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": session_id,
                "payment_intent": f"pi_{uuid.uuid4().hex[:16]}",
            }
        },
    }


def _override_db(mock_db):
    async def _get_db_override():
        yield mock_db

    app.dependency_overrides[get_db] = _get_db_override


def _clear_overrides():
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Signature validation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_valid_signature_is_accepted(mock_stripe, client):
    """Webhook with a valid Stripe signature returns 200."""
    import stripe as stripe_lib

    event = _checkout_event()
    payload = json.dumps(event).encode()

    mock_stripe.Webhook.construct_event.return_value = event
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    existing_result = MagicMock()
    existing_result.scalar_one_or_none.return_value = None

    mock_db = AsyncMock()
    mock_db.execute.return_value = existing_result
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.rollback = AsyncMock()

    _override_db(mock_db)
    try:
        with patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock):
            resp = await client.post(
                "/webhooks/stripe/",
                content=payload,
                headers={"Stripe-Signature": "t=123,v1=fakesig"},
            )
    finally:
        _clear_overrides()

    # construct_event was called and returned our event without raising
    assert resp.status_code == 200


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_invalid_signature_returns_400(mock_stripe, client):
    """Webhook with an invalid Stripe signature → 400."""
    import stripe as stripe_lib

    mock_stripe.Webhook.construct_event.side_effect = (
        stripe_lib.SignatureVerificationError("Bad sig", http_body="", sig_header="")
    )
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    resp = await client.post(
        "/webhooks/stripe/",
        content=b'{"id": "evt_bad"}',
        headers={"Stripe-Signature": "t=1,v1=invalidsignature"},
    )

    assert resp.status_code == 400
    assert "Invalid signature" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_missing_stripe_signature_header_returns_422(client):
    """Webhook without Stripe-Signature header → 422 (required header)."""
    resp = await client.post("/webhooks/stripe/", content=b'{"id": "evt_test"}')
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_duplicate_already_processed_event_returns_duplicate(mock_stripe, client):
    """Webhook returns {status: 'duplicate'} for an already-processed event."""
    import stripe as stripe_lib

    event = _checkout_event()
    payload = json.dumps(event).encode()

    mock_stripe.Webhook.construct_event.return_value = event
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    existing = StripeEvent(
        stripe_event_id=event["id"],
        event_type=event["type"],
        payload_json=event,
        processing_status=ProcessingStatus.processed,
    )
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = existing

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    _override_db(mock_db)
    try:
        resp = await client.post(
            "/webhooks/stripe/",
            content=payload,
            headers={"Stripe-Signature": "t=1,v1=sig"},
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json() == {"status": "duplicate"}


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_duplicate_in_processing_state_returns_duplicate(mock_stripe, client):
    """Webhook with an event currently being processed returns {status: 'duplicate'}."""
    import stripe as stripe_lib

    event = _checkout_event()
    payload = json.dumps(event).encode()

    mock_stripe.Webhook.construct_event.return_value = event
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    in_progress = StripeEvent(
        stripe_event_id=event["id"],
        event_type=event["type"],
        payload_json=event,
        processing_status=ProcessingStatus.processing,
    )
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = in_progress

    mock_db = AsyncMock()
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()

    _override_db(mock_db)
    try:
        resp = await client.post(
            "/webhooks/stripe/",
            content=payload,
            headers={"Stripe-Signature": "t=1,v1=sig"},
        )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json() == {"status": "duplicate"}


# ---------------------------------------------------------------------------
# Processing error → 500 (not a re-raise)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_processing_error_returns_500_not_500_exception(mock_stripe, client):
    """When event handler raises, webhook returns 500 JSONResponse (no unhandled exception)."""
    import stripe as stripe_lib

    event = _checkout_event()
    payload = json.dumps(event).encode()

    mock_stripe.Webhook.construct_event.return_value = event
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    # No existing event record
    first_result = MagicMock()
    first_result.scalar_one_or_none.return_value = None

    # Record to track status updates
    stripe_event_record = StripeEvent(
        stripe_event_id=event["id"],
        event_type=event["type"],
        payload_json=event,
        processing_status=ProcessingStatus.received,
    )

    call_count = 0

    async def _execute(stmt):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return first_result
        # Return the stripe_event_record for subsequent queries
        r = MagicMock()
        r.scalar_one_or_none.return_value = stripe_event_record
        return r

    def _capture_add(obj):
        nonlocal stripe_event_record
        if isinstance(obj, StripeEvent):
            stripe_event_record = obj

    mock_db = AsyncMock()
    mock_db.execute.side_effect = _execute
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock(side_effect=_capture_add)
    mock_db.rollback = AsyncMock()

    _override_db(mock_db)
    try:
        with patch(
            "app.routers.webhooks._handle_checkout_completed",
            new_callable=AsyncMock,
            side_effect=RuntimeError("Unexpected failure"),
        ):
            resp = await client.post(
                "/webhooks/stripe/",
                content=payload,
                headers={"Stripe-Signature": "t=1,v1=sig"},
            )
    finally:
        _clear_overrides()

    # 500 is returned as a JSONResponse, not raised as an exception
    assert resp.status_code == 500
    data = resp.json()
    assert data["status"] == "error"


# ---------------------------------------------------------------------------
# checkout.session.completed → order marked paid
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_checkout_completed_marks_order_paid(mock_stripe, client):
    """checkout.session.completed webhook marks the matching order as paid."""
    import stripe as stripe_lib

    session_id = "cs_test_paid_check"
    event = _checkout_event(session_id=session_id)
    payload = json.dumps(event).encode()

    mock_stripe.Webhook.construct_event.return_value = event
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=session_id,
        status=OrderStatus.pending,
        total_cents=9900,
        currency="USD",
        line_items=[],
    )

    call_count = 0

    async def _execute(stmt):
        nonlocal call_count
        call_count += 1
        r = MagicMock()
        if call_count == 1:
            # First call: idempotency check — no existing event
            r.scalar_one_or_none.return_value = None
        elif call_count == 2:
            # Second call: order lookup in _handle_checkout_completed
            r.scalar_one_or_none.return_value = order
        else:
            r.scalar_one_or_none.return_value = None
        return r

    added_records = []

    def _add(obj):
        added_records.append(obj)

    mock_db = AsyncMock()
    mock_db.execute.side_effect = _execute
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()
    mock_db.add = MagicMock(side_effect=_add)

    _override_db(mock_db)
    try:
        with patch("app.routers.webhooks.fulfill_order", new_callable=AsyncMock):
            resp = await client.post(
                "/webhooks/stripe/",
                content=payload,
                headers={"Stripe-Signature": "t=1,v1=sig"},
            )
    finally:
        _clear_overrides()

    assert resp.status_code == 200
    assert resp.json() == {"status": "received"}
    assert order.status == OrderStatus.paid
