"""Unit tests for admin entitlement invitation endpoints."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.entitlement import Entitlement, EntitlementStatus
from app.routers.admin_entitlement_invitations import resend_entitlement_invitation

TENANT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
ORDER_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
LINE_ITEM_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
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
        "invitation_sent_at": None,
        "created_at": datetime(2024, 1, 1, tzinfo=UTC),
        "updated_at": datetime(2024, 1, 1, tzinfo=UTC),
    }
    defaults.update(overrides)
    return Entitlement(**defaults)


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


def _request_no_tenant():
    request = MagicMock()
    request.state = MagicMock(spec=[])
    return request


@pytest.mark.asyncio
async def test_resend_invitation_records_timestamp(mock_db):
    """Pending entitlement records a new invitation_sent_at timestamp."""
    ent = _make_entitlement(status=EntitlementStatus.pending)
    mock_db.execute.return_value = _mock_select_result(ent)

    async def _fake_refresh(obj):
        obj.updated_at = datetime(2024, 1, 2, tzinfo=UTC)

    mock_db.refresh.side_effect = _fake_refresh

    response = await resend_entitlement_invitation(
        entitlement_id=ent.id,
        request=_request_no_tenant(),
        db=mock_db,
    )

    mock_db.commit.assert_awaited_once()
    mock_db.refresh.assert_awaited_once_with(ent)
    assert ent.invitation_sent_at is not None
    assert response.status == "pending"
    assert response.delivery_status == "recorded"


@pytest.mark.asyncio
async def test_resend_invitation_rejects_non_pending_status(mock_db):
    """Only pending entitlements may be resent."""
    ent = _make_entitlement(status=EntitlementStatus.claimed)
    mock_db.execute.return_value = _mock_select_result(ent)

    with pytest.raises(HTTPException) as exc_info:
        await resend_entitlement_invitation(
            entitlement_id=ent.id,
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 409
    assert "only allowed for pending" in exc_info.value.detail


@pytest.mark.asyncio
async def test_resend_invitation_not_found_returns_404(mock_db):
    """Missing entitlement returns 404."""
    mock_db.execute.return_value = _mock_select_result(None)

    with pytest.raises(HTTPException) as exc_info:
        await resend_entitlement_invitation(
            entitlement_id=uuid.uuid4(),
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 404
