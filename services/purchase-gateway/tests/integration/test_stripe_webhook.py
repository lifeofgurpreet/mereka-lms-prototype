import hashlib
import hmac
import json
import time
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Signature verification
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_webhook_rejects_missing_signature(client):
    """Webhook must reject requests without Stripe-Signature header."""
    resp = await client.post("/webhooks/stripe/", content=b'{}')
    assert resp.status_code == 422  # Missing required header


@pytest.mark.asyncio
async def test_webhook_rejects_invalid_signature(client):
    """Webhook must reject requests with an invalid signature."""
    resp = await client.post(
        "/webhooks/stripe/",
        content=b'{"id": "evt_test"}',
        headers={"Stripe-Signature": "t=123,v1=bad"},
    )
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# Helpers for building signed webhook requests
# ---------------------------------------------------------------------------


def _sign_payload(payload: bytes, secret: str) -> str:
    """Compute a valid Stripe-Signature header for the given payload and secret."""
    timestamp = str(int(time.time()))
    signed_payload = f"{timestamp}.{payload.decode()}"
    signature = hmac.new(
        secret.encode(), signed_payload.encode(), hashlib.sha256
    ).hexdigest()
    return f"t={timestamp},v1={signature}"


def _checkout_completed_event(session_id: str = "cs_test_integ") -> dict:
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


# ---------------------------------------------------------------------------
# Duplicate event idempotency — verified via the DB layer
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.routers.webhooks.stripe")
async def test_webhook_duplicate_already_processed_returns_duplicate(mock_stripe, client):
    """Webhook returns {status: duplicate} when event was already processed."""
    import stripe as stripe_lib
    from app.database import get_db
    from app.main import app
    from app.models.stripe_event import ProcessingStatus, StripeEvent

    event_payload = _checkout_completed_event()
    payload_bytes = json.dumps(event_payload).encode()
    secret = "whsec_test"

    # Stripe verification passes (bypasses real signature check)
    mock_stripe.Webhook.construct_event.return_value = event_payload
    mock_stripe.SignatureVerificationError = stripe_lib.SignatureVerificationError

    # DB returns an already-processed event record
    existing_event = StripeEvent(
        stripe_event_id=event_payload["id"],
        event_type=event_payload["type"],
        payload_json=event_payload,
        processing_status=ProcessingStatus.processed,
    )
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = existing_event

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=mock_result)
    mock_db.commit = AsyncMock()

    async def _override_get_db():
        yield mock_db

    app.dependency_overrides[get_db] = _override_get_db
    try:
        resp = await client.post(
            "/webhooks/stripe/",
            content=payload_bytes,
            headers={"Stripe-Signature": _sign_payload(payload_bytes, secret)},
        )
    finally:
        app.dependency_overrides.pop(get_db, None)

    assert resp.status_code == 200
    assert resp.json() == {"status": "duplicate"}


# ---------------------------------------------------------------------------
# Health check — sanity test against the full app
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_readiness_probe(client):
    """GET /ready/ returns 200 with status ready — no DB/Redis required."""
    resp = await client.get("/ready/")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ready"
