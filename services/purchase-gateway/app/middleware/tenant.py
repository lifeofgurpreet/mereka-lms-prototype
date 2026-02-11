"""Tenant resolution middleware."""
# @covers AC-024, AC-025
# @spec: ecommerce-purchase-gateway_spec.md

import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

logger = structlog.get_logger()

# Default platform tenant (no multi-tenant header)
DEFAULT_TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000000")


class TenantMiddleware(BaseHTTPMiddleware):
    """Extract tenant_id from X-Tenant-ID header or default to platform tenant."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        tenant_header = request.headers.get("X-Tenant-ID")
        if tenant_header:
            try:
                request.state.tenant_id = uuid.UUID(tenant_header)
            except ValueError:
                request.state.tenant_id = DEFAULT_TENANT_ID
        else:
            request.state.tenant_id = DEFAULT_TENANT_ID

        return await call_next(request)
