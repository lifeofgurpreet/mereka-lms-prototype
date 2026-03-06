"""Admin endpoints for entitlement invitation actions."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.entitlement import Entitlement, EntitlementStatus
from app.tenancy import request_tenant_scope

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])
logger = structlog.get_logger()


class ResendInvitationResponse(BaseModel):
    id: uuid.UUID
    status: str
    recipient_email: str
    invitation_sent_at: datetime
    delivery_status: str


@router.post(
    "/admin/entitlements/{entitlement_id}/resend-invitation/",
    response_model=ResendInvitationResponse,
)
async def resend_entitlement_invitation(
    entitlement_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Record a resend-invitation attempt for pending entitlements."""
    query = select(Entitlement).where(Entitlement.id == entitlement_id)
    mw_tenant_id = request_tenant_scope(request)
    if mw_tenant_id:
        query = query.where(Entitlement.tenant_id == mw_tenant_id)

    result = await db.execute(query)
    entitlement = result.scalar_one_or_none()
    if not entitlement:
        raise HTTPException(status_code=404, detail="Entitlement not found")

    if entitlement.status != EntitlementStatus.pending:
        raise HTTPException(
            status_code=409,
            detail=f"Invitation resend is only allowed for pending entitlements (status={entitlement.status.value})",
        )

    entitlement.invitation_sent_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(entitlement)

    logger.info(
        "entitlement.invitation_resent",
        entitlement_uuid=str(entitlement.id),
        tenant_id=str(entitlement.tenant_id),
    )

    return ResendInvitationResponse(
        id=entitlement.id,
        status=entitlement.status.value,
        recipient_email=entitlement.recipient_email,
        invitation_sent_at=entitlement.invitation_sent_at,
        delivery_status="recorded",
    )
