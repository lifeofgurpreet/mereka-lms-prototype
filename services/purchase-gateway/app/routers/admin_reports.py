"""Admin endpoints for tenant-level purchase reporting."""
# @covers AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.order import Order, OrderStatus
from app.tenancy import request_tenant_scope

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


def _count_where(column, value):
    """SQL conditional count: SUM(1) where column == value."""
    return func.coalesce(func.sum(case((column == value, 1), else_=0)), 0)


@router.get("/admin/tenants/{tenant_id}/reports/", response_model=TenantReportResponse)
async def get_tenant_report(
    tenant_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Return aggregate order metrics for a tenant."""
    mw_tenant_id = request_tenant_scope(request)
    if mw_tenant_id and str(mw_tenant_id) != str(tenant_id):
        raise HTTPException(status_code=403, detail="Forbidden for requested tenant")

    revenue_status_values = [s.value for s in REVENUE_STATUSES]

    stmt = select(
        func.count().label("order_count"),
        func.coalesce(
            func.sum(
                case((Order.status.in_(revenue_status_values), Order.total_cents), else_=0)
            ),
            0,
        ).label("gross_revenue_cents"),
        _count_where(Order.status, OrderStatus.refunded.value).label("refunded"),
        _count_where(Order.status, OrderStatus.partially_refunded.value).label(
            "partially_refunded"
        ),
        _count_where(Order.status, OrderStatus.fulfillment_failed.value).label(
            "fulfillment_failed"
        ),
        _count_where(Order.status, OrderStatus.pending.value).label("pending"),
    ).where(Order.tenant_id == tenant_id)

    row = (await db.execute(stmt)).one()

    refund_events = row.refunded + row.partially_refunded
    refund_rate = round((refund_events / row.order_count) * 100, 2) if row.order_count else 0.0

    return TenantReportResponse(
        tenant_id=tenant_id,
        order_count=row.order_count,
        gross_revenue_cents=row.gross_revenue_cents,
        refunded_order_count=row.refunded,
        partially_refunded_order_count=row.partially_refunded,
        fulfillment_failed_order_count=row.fulfillment_failed,
        pending_order_count=row.pending,
        refund_rate_percent=refund_rate,
        generated_at=datetime.now(UTC),
    )
