"""Admin endpoints for entitlement state actions."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import datetime

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


class EntitlementActionResponse(BaseModel):
    id: uuid.UUID
    status: str
    claimed_by_user_id: int | None
    claimed_at: datetime | None
    invitation_sent_at: datetime | None
    updated_at: datetime


@router.post(
    "/admin/entitlements/{entitlement_id}/revoke/",
    response_model=EntitlementActionResponse,
)
async def revoke_entitlement(
    entitlement_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Revoke an entitlement (idempotent)."""
    query = select(Entitlement).where(Entitlement.id == entitlement_id)
    mw_tenant_id = request_tenant_scope(request)
    if mw_tenant_id:
        query = query.where(Entitlement.tenant_id == mw_tenant_id)

    result = await db.execute(query)
    entitlement = result.scalar_one_or_none()
    if not entitlement:
        raise HTTPException(status_code=404, detail="Entitlement not found")

    if entitlement.status != EntitlementStatus.revoked:
        entitlement.status = EntitlementStatus.revoked
        await db.commit()
        await db.refresh(entitlement)

    logger.info(
        "entitlement.revoked",
        entitlement_uuid=str(entitlement.id),
        tenant_id=str(entitlement.tenant_id),
    )
    return EntitlementActionResponse(
        id=entitlement.id,
        status=entitlement.status.value,
        claimed_by_user_id=entitlement.claimed_by_user_id,
        claimed_at=entitlement.claimed_at,
        invitation_sent_at=entitlement.invitation_sent_at,
        updated_at=entitlement.updated_at,
    )
