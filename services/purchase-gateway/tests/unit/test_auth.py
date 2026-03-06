"""Unit tests for require_admin_api_key dependency."""
# @covers AC-019, AC-020
# @spec: ecommerce-purchase-gateway_spec.md

from unittest.mock import patch

import jwt
import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.auth import require_admin_api_key


def _set_auth_defaults(mock_settings):
    mock_settings.ADMIN_API_KEY = ""
    mock_settings.ADMIN_JWT_SECRET = ""
    mock_settings.ADMIN_JWT_ALGORITHMS = ["HS256"]
    mock_settings.ADMIN_JWT_ISSUER = None
    mock_settings.ADMIN_JWT_AUDIENCE = None
    mock_settings.ADMIN_ALLOWED_ROLES = ["payments_admin", "enterprise_admin"]
    mock_settings.ADMIN_REQUIRE_JWT = False


# ---------------------------------------------------------------------------
# Missing API key → 401
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_missing_api_key_returns_401(mock_settings):
    """No X-API-Key header → 401 Missing API key."""
    _set_auth_defaults(mock_settings)
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
    _set_auth_defaults(mock_settings)
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
    """Correct X-API-Key header passes auth and returns opaque identifier."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_API_KEY = "valid-key-12345"

    result = await require_admin_api_key(api_key="valid-key-12345")

    assert result == "api-key-admin"


# ---------------------------------------------------------------------------
# Unconfigured ADMIN_API_KEY → 503
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_unconfigured_api_key_returns_503(mock_settings):
    """Empty ADMIN_API_KEY in settings → 503 service unavailable."""
    _set_auth_defaults(mock_settings)
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
    _set_auth_defaults(mock_settings)
    key = "a" * 64
    mock_settings.ADMIN_API_KEY = key

    result = await require_admin_api_key(api_key=key)

    assert result == "api-key-admin"


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_timing_safe_comparison_rejects_prefix(mock_settings):
    """A key that is a prefix of the correct key is rejected."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_API_KEY = "full-secret-key"

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key="full-secret")

    assert exc_info.value.status_code == 403


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_valid_jwt_with_allowed_role_passes(mock_settings):
    """Valid admin JWT with an allowed role is accepted."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_JWT_SECRET = "jwt-secret"
    token = jwt.encode(
        {"sub": "admin-user-1", "roles": ["payments_admin"]},
        mock_settings.ADMIN_JWT_SECRET,
        algorithm="HS256",
    )

    result = await require_admin_api_key(
        api_key=None,
        bearer=HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
    )

    assert result == "admin-user-1"


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_jwt_with_disallowed_role_returns_403(mock_settings):
    """JWT without intersection with ADMIN_ALLOWED_ROLES is rejected."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_JWT_SECRET = "jwt-secret"
    mock_settings.ADMIN_ALLOWED_ROLES = ["payments_admin"]
    token = jwt.encode(
        {"sub": "admin-user-2", "roles": ["read_only"]},
        mock_settings.ADMIN_JWT_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(
            api_key=None,
            bearer=HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
        )

    assert exc_info.value.status_code == 403
    assert "Insufficient" in exc_info.value.detail


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_invalid_jwt_returns_403(mock_settings):
    """Malformed JWT is rejected with 403."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_JWT_SECRET = "jwt-secret"

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(
            api_key=None,
            bearer=HTTPAuthorizationCredentials(scheme="Bearer", credentials="bad-token"),
        )

    assert exc_info.value.status_code == 403
    assert "Invalid bearer token" in exc_info.value.detail


@pytest.mark.asyncio
@patch("app.auth.settings")
async def test_require_jwt_enforces_bearer_token(mock_settings):
    """ADMIN_REQUIRE_JWT=true rejects API-key-only requests."""
    _set_auth_defaults(mock_settings)
    mock_settings.ADMIN_API_KEY = "legacy-key"
    mock_settings.ADMIN_REQUIRE_JWT = True

    with pytest.raises(HTTPException) as exc_info:
        await require_admin_api_key(api_key="legacy-key", bearer=None)

    assert exc_info.value.status_code == 401
    assert "Missing bearer token" in exc_info.value.detail
