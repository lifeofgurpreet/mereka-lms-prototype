"""Integration tests for CORS policy."""

import uuid

import pytest


@pytest.mark.asyncio
async def test_cors_preflight_allows_delete_method(client):
    """CORS preflight for admin delete endpoint includes DELETE in allowed methods."""
    resp = await client.options(
        f"/api/v1/admin/offerings/{uuid.uuid4()}",
        headers={
            "Origin": "https://apps.academyv2.mereka.io",
            "Access-Control-Request-Method": "DELETE",
            "Access-Control-Request-Headers": "content-type,x-api-key",
        },
    )

    assert resp.status_code == 200
    allow_methods = resp.headers.get("access-control-allow-methods", "")
    assert "DELETE" in allow_methods
