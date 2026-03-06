"""Unit tests for tenant scope helpers."""

import uuid
from unittest.mock import MagicMock

from app.middleware.tenant import DEFAULT_TENANT_ID
from app.tenancy import request_tenant_scope


def _request_with_tenant(value):
    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = value
    return request


def test_request_tenant_scope_returns_none_for_default_tenant():
    """Platform default tenant sentinel should not enforce request-scoped filtering."""
    assert request_tenant_scope(_request_with_tenant(DEFAULT_TENANT_ID)) is None


def test_request_tenant_scope_returns_explicit_tenant_id():
    """Explicit non-default tenant IDs should be enforced as request scope."""
    tenant_id = uuid.UUID("00000000-0000-0000-0000-000000000042")
    assert request_tenant_scope(_request_with_tenant(tenant_id)) == tenant_id


def test_request_tenant_scope_returns_none_for_non_uuid_value():
    """Missing or malformed tenant state should resolve to no explicit scope."""
    assert request_tenant_scope(_request_with_tenant("bad-tenant")) is None
