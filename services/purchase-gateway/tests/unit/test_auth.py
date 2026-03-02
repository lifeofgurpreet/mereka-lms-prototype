"""Unit tests for require_admin_api_key dependency."""
# @covers AC-019, AC-020
# @spec: ecommerce-purchase-gateway_spec.md

from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.auth import require_admin_api_key

# ---------------------------------------------------------------------------
# Missing API key → 401
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_missing_api_key_returns_401(mock_settings):
    """No X-API-Key header → 401 Missing API key."""
    mock_settings.ADMIN_API_KEY = "some-configured-key"

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key=None)

    assert exc_info.value.status_code == 401
    assert "Missing" in exc_info.value.detail


# ---------------------------------------------------------------------------
# Wrong API key → 403
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_wrong_api_key_returns_403(mock_settings):
    """Wrong X-API-Key header value → 403 Invalid API key."""
    mock_settings.ADMIN_API_KEY = "correct-key-abc"

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key="wrong-key-xyz")

    assert exc_info.value.status_code == 403
    assert "Invalid" in exc_info.value.detail


# ---------------------------------------------------------------------------
# Correct API key → passes through, returns the key
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_correct_api_key_passes_through(mock_settings):
    """Correct X-API-Key header passes auth and returns the key value."""
    mock_settings.ADMIN_API_KEY = "valid-key-12345"

    result = await require_admin_api_key(api_key="valid-key-12345")

    assert result == "valid-key-12345"


# ---------------------------------------------------------------------------
# Unconfigured ADMIN_API_KEY → 503
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_unconfigured_api_key_returns_503(mock_settings):
    """Empty ADMIN_API_KEY in settings → 503 service unavailable."""
    mock_settings.ADMIN_API_KEY = ""

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key="any-key")

    assert exc_info.value.status_code == 503
    assert "not configured" in exc_info.value.detail


# ---------------------------------------------------------------------------
# Timing-safe comparison — correct key always succeeds
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_timing_safe_comparison_accepts_correct_key(mock_settings):
    """hmac.compare_digest is used; correct key is always accepted regardless of length."""
    key = "a" * 64
    mock_settings.ADMIN_API_KEY = key

    result = await require_admin_api_key(api_key=key)

    assert result == key


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_timing_safe_comparison_rejects_prefix(mock_settings):
    """A key that is a prefix of the correct key is rejected."""
    mock_settings.ADMIN_API_KEY = "full-secret-key"

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key="full-secret")

    assert exc_info.value.status_code == 403
