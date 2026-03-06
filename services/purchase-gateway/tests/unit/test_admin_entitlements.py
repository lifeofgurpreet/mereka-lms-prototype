"""Unit tests for admin entitlement listing endpoint."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.entitlement import Entitlement, EntitlementStatus
from app.routers.admin_entitlements import list_entitlements

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
LINE_ITEM_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")


def _mock_scalars_result(objects):
    scalars = MagicMock()
    scalars.all.return_value = objects
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_entitlement(**overrides) -> Entitlement:
    defaults = {
        "id": uuid.uuid4(),
        "tenant_id": TENANT_ID,
        "order_id": ORDER_ID,
        "line_item_id": LINE_ITEM_ID,
        "recipient_email": "learner@example.com",
        "lms_resource_id": "course-v1:Test+101+2024",
        "offering_type": "course_seat",
        "status": EntitlementStatus.pending,
        "claim_token": "claim-token-123",
        "claimed_by_user_id": None,
        "expires_at": datetime(2024, 2, 1, tzinfo=UTC),
        "claimed_at": None,
        "invitation_sent_at": datetime(2024, 1, 1, tzinfo=UTC),
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Entitlement(**defaults)


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


def _request_with_tenant(tenant_id: uuid.UUID):
    request = MagicMock()
    request.state = MagicMock()
    request.state.tenant_id = tenant_id
    return request


@pytest.mark.asyncio
async def test_list_entitlements_returns_filtered_rows(mock_db):
    """Endpoint returns entitlement list and serializes enum to string."""
    ent = _make_entitlement(status=EntitlementStatus.claimed)
    mock_db.execute.return_value = _mock_scalars_result([ent])

    result = await list_entitlements(
        request=_request_no_tenant(),
        db=mock_db,
        tenant_id=TENANT_ID,
        status=EntitlementStatus.claimed,
        recipient_email="learner@example.com",
        limit=50,
        offset=0,
    )

    assert len(result) == 1
    assert result[0].recipient_email == "learner@example.com"
    assert result[0].status == EntitlementStatus.claimed


@pytest.mark.asyncio
async def test_list_entitlements_returns_empty_list(mock_db):
    """Endpoint returns empty list when no entitlements match."""
    mock_db.execute.return_value = _mock_scalars_result([])

    result = await list_entitlements(
        request=_request_no_tenant(),
        db=mock_db,
        tenant_id=None,
        status=None,
        recipient_email=None,
        limit=50,
        offset=0,
    )

    assert result == []


@pytest.mark.asyncio
async def test_list_entitlements_tenant_scope_mismatch_returns_403(mock_db):
    """Reject query tenant_id that does not match middleware tenant scope."""
    with pytest.raises(HTTPException) as exc_info:
        await list_entitlements(
            request=_request_with_tenant(TENANT_ID),
            db=mock_db,
            tenant_id=uuid.UUID("00000000-0000-0000-0000-000000000009"),
            status=None,
            recipient_email=None,
            limit=50,
            offset=0,
        )

    assert exc_info.value.status_code == 403
    assert "Tenant scope mismatch" in exc_info.value.detail
    mock_db.execute.assert_not_awaited()
