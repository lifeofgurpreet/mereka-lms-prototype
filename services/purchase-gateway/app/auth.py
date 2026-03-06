"""Admin authentication for admin endpoints (JWT-first with API-key fallback)."""
# @covers AC-019, AC-020
# @spec: ecommerce-purchase-gateway_spec.md

import hmac
from collections.abc import Mapping
from typing import Any

import jwt
import structlog
from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError

from app.config import settings

logger = structlog.get_logger()

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
bearer_header = HTTPBearer(auto_error=False)


def _extract_roles(payload: Mapping[str, Any]) -> set[str]:
    """Extract role-like claims from common JWT fields."""
    roles: set[str] = set()

    roles_claim = payload.get("roles")
    if isinstance(roles_claim, list):
        roles.update(str(role) for role in roles_claim if isinstance(role, str) and role)
    elif isinstance(roles_claim, str) and roles_claim:
        roles.add(roles_claim)

    role_claim = payload.get("role")
    if isinstance(role_claim, str) and role_claim:
        roles.add(role_claim)

    scope_claim = payload.get("scope")
    if isinstance(scope_claim, str) and scope_claim:
        roles.update(scope_claim.split())

    return roles


def _decode_admin_jwt(
    token: str,
    secret: str,
    algorithms: list[str],
    issuer: str | None,
    audience: str | None,
) -> Mapping[str, Any]:
    """Decode JWT token with configured issuer/audience constraints."""
    decode_kwargs: dict[str, Any] = {"algorithms": algorithms}
    if issuer:
        decode_kwargs["issuer"] = issuer
    if audience:
        decode_kwargs["audience"] = audience
    else:
        decode_kwargs["options"] = {"verify_aud": False}

    payload = jwt.decode(token, secret, **decode_kwargs)
    if not isinstance(payload, Mapping):
        raise InvalidTokenError("JWT payload must be an object")
    return payload


def _normalize_api_key(api_key: object) -> str | None:
    if isinstance(api_key, str) and api_key:
        return api_key
    return None


def _normalize_bearer_token(bearer: object) -> str | None:
    if isinstance(bearer, HTTPAuthorizationCredentials) and bearer.credentials:
        return bearer.credentials
    return None


async def require_admin_api_key(
    api_key: str | None = Security(api_key_header),
    bearer: HTTPAuthorizationCredentials | None = Security(bearer_header),
) -> str:
    """Validate admin access via JWT roles or API key fallback."""
    bearer_token = _normalize_bearer_token(bearer)
    api_key_value = _normalize_api_key(api_key)

    admin_api_key = settings.ADMIN_API_KEY if isinstance(settings.ADMIN_API_KEY, str) else ""
    jwt_secret = settings.ADMIN_JWT_SECRET if isinstance(settings.ADMIN_JWT_SECRET, str) else ""
    jwt_algorithms = (
        settings.ADMIN_JWT_ALGORITHMS
        if isinstance(settings.ADMIN_JWT_ALGORITHMS, list)
        and all(isinstance(item, str) for item in settings.ADMIN_JWT_ALGORITHMS)
        else ["HS256"]
    )
    jwt_issuer = settings.ADMIN_JWT_ISSUER if isinstance(settings.ADMIN_JWT_ISSUER, str) else None
    jwt_audience = (
        settings.ADMIN_JWT_AUDIENCE if isinstance(settings.ADMIN_JWT_AUDIENCE, str) else None
    )
    require_jwt = settings.ADMIN_REQUIRE_JWT if isinstance(settings.ADMIN_REQUIRE_JWT, bool) else False
    allowed_roles_raw = settings.ADMIN_ALLOWED_ROLES
    allowed_roles = (
        {role for role in allowed_roles_raw if isinstance(role, str) and role}
        if isinstance(allowed_roles_raw, list)
        else {"payments_admin", "enterprise_admin"}
    )

    if bearer_token:
        if not jwt_secret:
            logger.error("admin.jwt_secret_not_configured")
            raise HTTPException(status_code=503, detail="Admin JWT secret not configured")
        try:
            payload = _decode_admin_jwt(
                bearer_token,
                secret=jwt_secret,
                algorithms=jwt_algorithms,
                issuer=jwt_issuer,
                audience=jwt_audience,
            )
        except InvalidTokenError:
            logger.warning("admin.invalid_bearer_token")
            raise HTTPException(status_code=403, detail="Invalid bearer token") from None

        token_roles = _extract_roles(payload)
        if allowed_roles and token_roles.isdisjoint(allowed_roles):
            logger.warning("admin.jwt_insufficient_role", token_roles=sorted(token_roles))
            raise HTTPException(status_code=403, detail="Insufficient admin role")
        return str(payload.get("sub") or "jwt-admin")

    if require_jwt:
        raise HTTPException(status_code=401, detail="Missing bearer token")

    if not admin_api_key:
        if jwt_secret:
            raise HTTPException(status_code=401, detail="Missing bearer token")
        logger.error("admin.api_key_not_configured")
        raise HTTPException(status_code=503, detail="Admin API key not configured")

    if not api_key_value:
        raise HTTPException(status_code=401, detail="Missing API key")
    if not hmac.compare_digest(api_key_value, admin_api_key):
        logger.warning("admin.invalid_api_key")
        raise HTTPException(status_code=403, detail="Invalid API key")
    return "api-key-admin"
