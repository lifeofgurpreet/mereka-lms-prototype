import pytest
from unittest.mock import AsyncMock, patch


@pytest.mark.asyncio
async def test_checkout_requires_buyer_email(client):
    """Checkout must reject requests missing buyer_email."""
    resp = await client.post("/api/v1/checkout/", json={
        "offering_uuid": "00000000-0000-0000-0000-000000000001",
        "success_url": "https://example.com/success",
        "cancel_url": "https://example.com/cancel",
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_checkout_requires_offering_uuid(client):
    """Checkout must reject requests missing offering_uuid."""
    resp = await client.post("/api/v1/checkout/", json={
        "buyer_email": "buyer@example.com",
        "success_url": "https://example.com/success",
        "cancel_url": "https://example.com/cancel",
    })
    assert resp.status_code == 422
