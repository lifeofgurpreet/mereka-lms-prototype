"""Admin endpoints for order detail inspection."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.fulfillment_job import FulfillmentJob
from app.models.order import LineItem, Order, OrderAuditLog

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])


class LineItemResponse(BaseModel):
    id: uuid.UUID
    offering_uuid: uuid.UUID
    offering_type: str
    lms_resource_id: str
    quantity: int
    unit_price_cents: int
    total_price_cents: int
    fulfillment_status: str


class OrderAuditLogResponse(BaseModel):
    id: uuid.UUID
    old_status: str
    new_status: str
    triggered_by: str
    timestamp: datetime
    details: dict | None


class FulfillmentJobResponse(BaseModel):
    id: uuid.UUID
    status: str
    attempts: int
    max_attempts: int
    next_attempt_at: datetime
    last_attempt_at: datetime | None
    completed_at: datetime | None
    last_error: str | None
    triggered_by: str


class OrderDetailResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    buyer_email: str
    buyer_user_id: int | None
    stripe_checkout_session_id: str
    stripe_payment_intent_id: str | None
    status: str
    total_cents: int
    currency: str
    created_at: datetime
    updated_at: datetime
    fulfilled_at: datetime | None
    refunded_at: datetime | None
    line_items: list[LineItemResponse]
    audit_log: list[OrderAuditLogResponse]
    fulfillment_job: FulfillmentJobResponse | None


@router.get("/admin/orders/{order_id}/", response_model=OrderDetailResponse)
async def get_order_detail(
    order_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Return order detail with line-items, fulfillment-job, and audit timeline."""
    query = select(Order).where(Order.id == order_id)
    mw_tenant_id = getattr(request.state, "tenant_id", None)
    if mw_tenant_id:
        query = query.where(Order.tenant_id == mw_tenant_id)

    result = await db.execute(query)
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    line_items_result = await db.execute(
        select(LineItem).where(LineItem.order_id == order.id).order_by(LineItem.created_at.asc())
    )
    line_items = line_items_result.scalars().all()

    audit_result = await db.execute(
        select(OrderAuditLog)
        .where(OrderAuditLog.order_id == order.id)
        .order_by(OrderAuditLog.timestamp.desc())
    )
    audit_logs = audit_result.scalars().all()

    job_result = await db.execute(
        select(FulfillmentJob).where(FulfillmentJob.order_id == order.id)
    )
    job = job_result.scalar_one_or_none()

    return OrderDetailResponse(
        id=order.id,
        tenant_id=order.tenant_id,
        buyer_email=order.buyer_email,
        buyer_user_id=order.buyer_user_id,
        stripe_checkout_session_id=order.stripe_checkout_session_id,
        stripe_payment_intent_id=order.stripe_payment_intent_id,
        status=order.status.value,
        total_cents=order.total_cents,
        currency=order.currency,
        created_at=order.created_at,
        updated_at=order.updated_at,
        fulfilled_at=order.fulfilled_at,
        refunded_at=order.refunded_at,
        line_items=[
            LineItemResponse(
                id=item.id,
                offering_uuid=item.offering_uuid,
                offering_type=item.offering_type,
                lms_resource_id=item.lms_resource_id,
                quantity=item.quantity,
                unit_price_cents=item.unit_price_cents,
                total_price_cents=item.total_price_cents,
                fulfillment_status=item.fulfillment_status.value,
            )
            for item in line_items
        ],
        audit_log=[
            OrderAuditLogResponse(
                id=entry.id,
                old_status=entry.old_status,
                new_status=entry.new_status,
                triggered_by=entry.triggered_by,
                timestamp=entry.timestamp,
                details=entry.details,
            )
            for entry in audit_logs
        ],
        fulfillment_job=(
            FulfillmentJobResponse(
                id=job.id,
                status=job.status.value,
                attempts=job.attempts,
                max_attempts=job.max_attempts,
                next_attempt_at=job.next_attempt_at,
                last_attempt_at=job.last_attempt_at,
                completed_at=job.completed_at,
                last_error=job.last_error,
                triggered_by=job.triggered_by,
            )
            if job
            else None
        ),
    )
