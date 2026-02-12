"""Subscription management API endpoints."""
# @covers AC-022, AC-023
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime

import stripe as stripe_lib
import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.subscription import Subscription, SubscriptionStatus
from app.services.subscription import create_subscription

router = APIRouter(tags=["subscriptions"])
logger = structlog.get_logger()


# --- Request / Response schemas ---


class CreateSubscriptionRequest(BaseModel):
    tenant_id: uuid.UUID
    offering_id: uuid.UUID
    stripe_customer_id: str
    seat_count: int = 1
    enterprise_customer_uuid: uuid.UUID | None = None


class UpdateSubscriptionRequest(BaseModel):
    cancel: bool | None = None
    seat_count: int | None = None


class SubscriptionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    enterprise_customer_uuid: uuid.UUID | None
    offering_id: uuid.UUID
    stripe_subscription_id: str
    stripe_customer_id: str
    status: str
    current_period_start: datetime
    current_period_end: datetime
    grace_period_end: datetime | None
    canceled_at: datetime | None
    seat_count: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Endpoints ---


@router.post("/subscriptions/", response_model=SubscriptionResponse, status_code=201)
async def create_subscription_endpoint(
    request_body: CreateSubscriptionRequest,
    db: AsyncSession = Depends(get_db),
):
    """Create an enterprise subscription via Stripe."""
    if not settings.ENABLE_ENTERPRISE_SUBSCRIPTIONS:
        raise HTTPException(status_code=403, detail="Enterprise subscriptions are disabled")

    try:
        subscription = await create_subscription(
            db,
            tenant_id=request_body.tenant_id,
            offering_id=request_body.offering_id,
            stripe_customer_id=request_body.stripe_customer_id,
            seat_count=request_body.seat_count,
            enterprise_customer_uuid=request_body.enterprise_customer_uuid,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    return subscription


@router.get("/subscriptions/{subscription_id}", response_model=SubscriptionResponse)
async def get_subscription(
    subscription_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Get subscription details."""
    result = await db.execute(select(Subscription).where(Subscription.id == subscription_id))
    subscription = result.scalar_one_or_none()
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")

    # Tenant isolation: verify tenant_id matches request context
    tenant_id = getattr(request.state, "tenant_id", None)
    if tenant_id and subscription.tenant_id != tenant_id:
        raise HTTPException(status_code=404, detail="Subscription not found")

    return subscription


@router.patch("/subscriptions/{subscription_id}", response_model=SubscriptionResponse)
async def update_subscription(
    subscription_id: uuid.UUID,
    request_body: UpdateSubscriptionRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Update subscription — cancel or change seat count."""
    result = await db.execute(select(Subscription).where(Subscription.id == subscription_id))
    subscription = result.scalar_one_or_none()
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")

    tenant_id = getattr(request.state, "tenant_id", None)
    if tenant_id and subscription.tenant_id != tenant_id:
        raise HTTPException(status_code=404, detail="Subscription not found")

    stripe_lib.api_key = settings.STRIPE_SECRET_KEY

    if request_body.cancel:
        stripe_lib.Subscription.modify(
            subscription.stripe_subscription_id,
            cancel_at_period_end=True,
        )
        subscription.status = SubscriptionStatus.canceled
        subscription.canceled_at = datetime.now(tz=UTC)
        logger.info(
            "subscription.cancel_requested",
            subscription_uuid=str(subscription.id),
        )

    if request_body.seat_count is not None and request_body.seat_count != subscription.seat_count:
        stripe_sub = stripe_lib.Subscription.retrieve(subscription.stripe_subscription_id)
        stripe_lib.Subscription.modify(
            subscription.stripe_subscription_id,
            items=[{
                "id": stripe_sub["items"]["data"][0]["id"],
                "quantity": request_body.seat_count,
            }],
        )
        subscription.seat_count = request_body.seat_count
        logger.info(
            "subscription.seats_updated",
            subscription_uuid=str(subscription.id),
            seat_count=request_body.seat_count,
        )

    await db.commit()
    await db.refresh(subscription)
    return subscription


@router.get("/subscriptions/", response_model=list[SubscriptionResponse])
async def list_subscriptions(
    request: Request,
    db: AsyncSession = Depends(get_db),
    tenant_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    """List subscriptions, optionally filtered by tenant_id and status."""
    query = select(Subscription)

    # Apply tenant isolation from middleware
    mw_tenant_id = getattr(request.state, "tenant_id", None)
    if mw_tenant_id:
        query = query.where(Subscription.tenant_id == mw_tenant_id)
    elif tenant_id:
        query = query.where(Subscription.tenant_id == tenant_id)

    if status:
        query = query.where(Subscription.status == status)

    query = query.order_by(Subscription.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()
