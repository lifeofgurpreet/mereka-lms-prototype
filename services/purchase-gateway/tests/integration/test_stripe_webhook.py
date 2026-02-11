import pytest


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
