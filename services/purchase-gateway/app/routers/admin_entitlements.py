"""Admin endpoints for entitlement inspection."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.entitlement import Entitlement, EntitlementStatus
from app.tenancy import request_tenant_scope

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])


class EntitlementSummaryResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    order_id: uuid.UUID
    line_item_id: uuid.UUID
    recipient_email: str
    lms_resource_id: str
    offering_type: str
    status: str
    claimed_by_user_id: int | None
    expires_at: datetime
    claimed_at: datetime | None
    invitation_sent_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


@router.get(
    "/admin/entitlements/",
    response_model=list[EntitlementSummaryResponse],
)
async def list_entitlements(
    request: Request,
    db: AsyncSession = Depends(get_db),
    tenant_id: uuid.UUID | None = Query(default=None),
    status: EntitlementStatus | None = Query(default=None),
    recipient_email: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    """List entitlements with optional tenant/status/email filters."""
    query = select(Entitlement)

    mw_tenant_id = request_tenant_scope(request)
    if mw_tenant_id:
        if tenant_id and tenant_id != mw_tenant_id:
            raise HTTPException(status_code=403, detail="Tenant scope mismatch")
        query = query.where(Entitlement.tenant_id == mw_tenant_id)
    elif tenant_id:
        query = query.where(Entitlement.tenant_id == tenant_id)

    if status:
        query = query.where(Entitlement.status == status)
    if recipient_email:
        query = query.where(Entitlement.recipient_email == recipient_email)

    query = query.order_by(Entitlement.created_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
