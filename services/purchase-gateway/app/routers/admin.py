"""Admin endpoints — offering management, entitlement assignment, order listing."""
# @covers AC-019, AC-020, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.entitlement import Entitlement, EntitlementStatus
from app.models.offering import Offering, OfferingType
from app.models.order import Order

router = APIRouter(tags=["admin"])
logger = structlog.get_logger()

MAX_BULK_ASSIGN = 500


# --- Request / Response schemas ---


class CreateOfferingRequest(BaseModel):
    offering_type: OfferingType
    title: str
    description: str | None = None
    price_cents: int
    currency: str = "USD"
    stripe_price_id: str
    lms_resource_id: str
    tenant_id: uuid.UUID
    active: bool = True
    metadata: dict | None = None


class UpdateOfferingRequest(BaseModel):
    title: str | None = None
    description: str | None = None
    price_cents: int | None = None
    active: bool | None = None
    metadata: dict | None = None


class OfferingResponse(BaseModel):
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


class BulkAssignRequest(BaseModel):
    order_id: uuid.UUID
    line_item_id: uuid.UUID
    lms_resource_id: str
    offering_type: str
    tenant_id: uuid.UUID
    emails: list[EmailStr]


class BulkAssignResponse(BaseModel):
    created: int
    skipped: int
    entitlement_ids: list[uuid.UUID]


class OrderSummaryResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    buyer_email: str
    status: str
    total_cents: int
    currency: str
    created_at: datetime
    fulfilled_at: datetime | None
    refunded_at: datetime | None

    model_config = {"from_attributes": True}


# --- Offerings ---


@router.post("/admin/offerings/", response_model=OfferingResponse, status_code=201)
async def create_offering(
    request_body: CreateOfferingRequest,
    db: AsyncSession = Depends(get_db),
):
    """Create a new offering (course seat, program, or seat pack)."""
    offering = Offering(
        id=uuid.uuid4(),
        tenant_id=request_body.tenant_id,
        offering_type=request_body.offering_type,
        title=request_body.title,
        description=request_body.description,
        price_cents=request_body.price_cents,
        currency=request_body.currency,
        stripe_price_id=request_body.stripe_price_id,
        lms_resource_id=request_body.lms_resource_id,
        active=request_body.active,
        metadata_json=request_body.metadata,
    )
    db.add(offering)
    await db.commit()
    await db.refresh(offering)

    logger.info(
        "offering.created",
        offering_uuid=str(offering.id),
        title=offering.title,
        tenant_id=str(offering.tenant_id),
    )
    return offering


@router.patch("/admin/offerings/{offering_id}", response_model=OfferingResponse)
async def update_offering(
    offering_id: uuid.UUID,
    request_body: UpdateOfferingRequest,
    db: AsyncSession = Depends(get_db),
):
    """Update an existing offering."""
    result = await db.execute(select(Offering).where(Offering.id == offering_id))
    offering = result.scalar_one_or_none()
    if not offering:
        raise HTTPException(status_code=404, detail="Offering not found")

    if request_body.title is not None:
        offering.title = request_body.title
    if request_body.description is not None:
        offering.description = request_body.description
    if request_body.price_cents is not None:
        offering.price_cents = request_body.price_cents
    if request_body.active is not None:
        offering.active = request_body.active
    if request_body.metadata is not None:
        offering.metadata_json = request_body.metadata

    await db.commit()
    await db.refresh(offering)

    logger.info("offering.updated", offering_uuid=str(offering.id))
    return offering


# --- Entitlements ---


@router.post("/admin/entitlements/assign", response_model=BulkAssignResponse)
async def bulk_assign_entitlements(
    request_body: BulkAssignRequest,
    db: AsyncSession = Depends(get_db),
):
    """Bulk assign entitlements to a list of emails (up to 500)."""
    if len(request_body.emails) > MAX_BULK_ASSIGN:
        raise HTTPException(
            status_code=400,
            detail=f"Maximum {MAX_BULK_ASSIGN} emails per request",
        )

    # Verify order exists
    result = await db.execute(select(Order).where(Order.id == request_body.order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Check for existing entitlements to avoid duplicates
    existing_result = await db.execute(
        select(Entitlement.recipient_email).where(
            Entitlement.order_id == request_body.order_id,
            Entitlement.line_item_id == request_body.line_item_id,
            Entitlement.recipient_email.in_([str(e) for e in request_body.emails]),
        )
    )
    existing_emails = {row[0] for row in existing_result.all()}

    created_ids: list[uuid.UUID] = []
    skipped = 0
    expires_at = datetime.now(UTC) + timedelta(
        days=settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS
    )

    for email in request_body.emails:
        email_str = str(email)
        if email_str in existing_emails:
            skipped += 1
            continue

        entitlement_id = uuid.uuid4()
        entitlement = Entitlement(
            id=entitlement_id,
            order_id=request_body.order_id,
            line_item_id=request_body.line_item_id,
            tenant_id=request_body.tenant_id,
            recipient_email=email_str,
            lms_resource_id=request_body.lms_resource_id,
            offering_type=request_body.offering_type,
            status=EntitlementStatus.pending,
            claim_token=secrets.token_urlsafe(32),
            expires_at=expires_at,
        )
        db.add(entitlement)
        created_ids.append(entitlement_id)

    await db.commit()

    logger.info(
        "entitlements.bulk_assigned",
        order_uuid=str(request_body.order_id),
        created=len(created_ids),
        skipped=skipped,
        tenant_id=str(request_body.tenant_id),
    )
    return BulkAssignResponse(
        created=len(created_ids),
        skipped=skipped,
        entitlement_ids=created_ids,
    )


# --- Orders ---


@router.get("/admin/orders/", response_model=list[OrderSummaryResponse])
async def list_orders(
    request: Request,
    db: AsyncSession = Depends(get_db),
    tenant_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    buyer_email: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    """List orders with optional filters."""
    query = select(Order)

    # Tenant isolation from middleware
    mw_tenant_id = getattr(request.state, "tenant_id", None)
    if mw_tenant_id:
        query = query.where(Order.tenant_id == mw_tenant_id)
    elif tenant_id:
        query = query.where(Order.tenant_id == tenant_id)

    if status:
        query = query.where(Order.status == status)

    if buyer_email:
        query = query.where(Order.buyer_email == buyer_email)

    query = query.order_by(Order.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()
