"""Unit tests for admin entitlement action endpoints."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.entitlement import Entitlement, EntitlementStatus
from app.routers.admin_entitlement_actions import revoke_entitlement

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
        "invitation_sent_at": datetime(2024, 1, 1, tzinfo=UTC),
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
async def test_revoke_entitlement_updates_status_and_commits(mock_db):
    """Pending entitlement transitions to revoked and persists."""
    ent = _make_entitlement(status=EntitlementStatus.pending)
    mock_db.execute.return_value = _mock_select_result(ent)

    response = await revoke_entitlement(
        entitlement_id=ent.id,
        request=_request_no_tenant(),
        db=mock_db,
    )

    assert ent.status == EntitlementStatus.revoked
    mock_db.commit.assert_awaited_once()
    mock_db.refresh.assert_awaited_once_with(ent)
    assert response.status == "revoked"


@pytest.mark.asyncio
async def test_revoke_entitlement_is_idempotent_when_already_revoked(mock_db):
    """Already-revoked entitlement returns success without another commit."""
    ent = _make_entitlement(status=EntitlementStatus.revoked)
    mock_db.execute.return_value = _mock_select_result(ent)

    response = await revoke_entitlement(
        entitlement_id=ent.id,
        request=_request_no_tenant(),
        db=mock_db,
    )

    mock_db.commit.assert_not_awaited()
    mock_db.refresh.assert_not_awaited()
    assert response.status == "revoked"


@pytest.mark.asyncio
async def test_revoke_entitlement_not_found_returns_404(mock_db):
    """Unknown entitlement id returns 404."""
    mock_db.execute.return_value = _mock_select_result(None)

    with pytest.raises(HTTPException) as exc_info:
        await revoke_entitlement(
            entitlement_id=uuid.uuid4(),
            request=_request_no_tenant(),
            db=mock_db,
        )

    assert exc_info.value.status_code == 404
