"""Admin endpoints for offering inspection."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.offering import Offering, OfferingType

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])


class OfferingSummaryResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    offering_type: str
    title: str
    description: str | None
    price_cents: int
    currency: str
    stripe_price_id: str
    lms_resource_id: str
    active: bool
    metadata_json: dict | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


@router.get("/admin/offerings/", response_model=list[OfferingSummaryResponse])
async def list_offerings(
    request: Request,
    db: AsyncSession = Depends(get_db),
    tenant_id: uuid.UUID | None = Query(default=None),
    offering_type: OfferingType | None = Query(default=None),
    active: bool | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    """List offerings with optional tenant/type/active filters."""
    query = select(Offering)

    mw_tenant_id = getattr(request.state, "tenant_id", None)
    if mw_tenant_id:
        query = query.where(Offering.tenant_id == mw_tenant_id)
    elif tenant_id:
        query = query.where(Offering.tenant_id == tenant_id)

    if offering_type:
        query = query.where(Offering.offering_type == offering_type)
    if active is not None:
        query = query.where(Offering.active == active)

    query = query.order_by(Offering.created_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
