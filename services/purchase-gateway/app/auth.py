"""API key authentication for admin endpoints."""
# @covers AC-019, AC-020
# @spec: ecommerce-purchase-gateway_spec.md

import hmac

import structlog
from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

from app.config import settings

logger = structlog.get_logger()

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_admin_api_key(
    api_key: str | None = Security(api_key_header),
) -> str:
    """Validate the admin API key from X-API-Key header."""
    if not settings.ADMIN_API_KEY:
        logger.error("admin.api_key_not_configured")
        raise HTTPException(status_code=503, detail="Admin API key not configured")
    if not api_key:
        raise HTTPException(status_code=401, detail="Missing API key")
    if not hmac.compare_digest(api_key, settings.ADMIN_API_KEY):
        logger.warning("admin.invalid_api_key")
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key
