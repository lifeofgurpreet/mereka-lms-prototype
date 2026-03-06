"""Admin endpoints for tenant-level purchase reporting."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.order import Order, OrderStatus

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])


REVENUE_STATUSES = {
    OrderStatus.paid,
    OrderStatus.fulfilling,
    OrderStatus.fulfilled,
    OrderStatus.partially_fulfilled,
    OrderStatus.fulfillment_failed,
    OrderStatus.partially_refunded,
    OrderStatus.refunded,
    OrderStatus.disputed,
}


class TenantReportResponse(BaseModel):
    tenant_id: uuid.UUID
    order_count: int
    gross_revenue_cents: int
    refunded_order_count: int
    partially_refunded_order_count: int
    fulfillment_failed_order_count: int
    pending_order_count: int
    refund_rate_percent: float
    generated_at: datetime


@router.get("/admin/tenants/{tenant_id}/reports/", response_model=TenantReportResponse)
async def get_tenant_report(
    tenant_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Return aggregate order metrics for a tenant."""
    mw_tenant_id = getattr(request.state, "tenant_id", None)
    if mw_tenant_id and str(mw_tenant_id) != str(tenant_id):
        raise HTTPException(status_code=403, detail="Forbidden for requested tenant")

    result = await db.execute(select(Order).where(Order.tenant_id == tenant_id))
    orders = result.scalars().all()

    order_count = len(orders)
    gross_revenue_cents = sum(
        order.total_cents for order in orders if order.status in REVENUE_STATUSES
    )
    refunded_order_count = sum(1 for order in orders if order.status == OrderStatus.refunded)
    partially_refunded_order_count = sum(
        1 for order in orders if order.status == OrderStatus.partially_refunded
    )
    fulfillment_failed_order_count = sum(
        1 for order in orders if order.status == OrderStatus.fulfillment_failed
    )
    pending_order_count = sum(1 for order in orders if order.status == OrderStatus.pending)
    refund_events = refunded_order_count + partially_refunded_order_count
    refund_rate_percent = round((refund_events / order_count) * 100, 2) if order_count else 0.0

    return TenantReportResponse(
        tenant_id=tenant_id,
        order_count=order_count,
        gross_revenue_cents=gross_revenue_cents,
        refunded_order_count=refunded_order_count,
        partially_refunded_order_count=partially_refunded_order_count,
        fulfillment_failed_order_count=fulfillment_failed_order_count,
        pending_order_count=pending_order_count,
        refund_rate_percent=refund_rate_percent,
        generated_at=datetime.now(UTC),
    )
