"""Tenant scope helpers for request-level isolation."""

import uuid

from starlette.requests import Request

from app.middleware.tenant import DEFAULT_TENANT_ID


def request_tenant_scope(request: Request) -> uuid.UUID | None:
    """Return explicit tenant scope from middleware, ignoring platform-default sentinel."""
    tenant_id = getattr(request.state, "tenant_id", None)
    if not isinstance(tenant_id, uuid.UUID):
        return None
    if tenant_id == DEFAULT_TENANT_ID:
        return None
    return tenant_id
