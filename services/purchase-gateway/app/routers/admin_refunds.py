"""Admin endpoints for manual refund initiation."""
# @covers AC-015, AC-019, AC-022
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from typing import Literal

import stripe
import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin_api_key
from app.database import get_db
from app.models.order import Order, OrderStatus
from app.tenancy import request_tenant_scope

router = APIRouter(tags=["admin"], dependencies=[Depends(require_admin_api_key)])
logger = structlog.get_logger()


class CreateRefundRequest(BaseModel):
    amount_cents: int | None = Field(default=None, gt=0)
    reason: Literal["duplicate", "fraudulent", "requested_by_customer"] | None = None


class RefundResponse(BaseModel):
    order_id: uuid.UUID
    stripe_refund_id: str
    stripe_refund_status: str
    amount_cents: int
    currency: str
    payment_intent_id: str
    state_update_mode: str


@router.post("/admin/orders/{order_id}/refund/", response_model=RefundResponse)
async def create_order_refund(
    order_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    request_body: CreateRefundRequest | None = None,
):
    """Initiate a Stripe refund for an order; local state updates via webhook."""
    body = request_body or CreateRefundRequest()
    query = select(Order).where(Order.id == order_id)
    mw_tenant_id = request_tenant_scope(request)
    if mw_tenant_id:
        query = query.where(Order.tenant_id == mw_tenant_id)

    result = await db.execute(query)
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.status == OrderStatus.refunded:
        raise HTTPException(status_code=409, detail="Order is already fully refunded")

    if not order.stripe_payment_intent_id:
        raise HTTPException(
            status_code=409,
            detail="Order has no Stripe payment intent and cannot be refunded",
        )

    if body.amount_cents is not None and body.amount_cents > order.total_cents:
        raise HTTPException(
            status_code=400,
            detail="Requested refund amount exceeds order total",
        )

    refund_args: dict = {
        "payment_intent": order.stripe_payment_intent_id,
        "metadata": {
            "order_id": str(order.id),
            "tenant_id": str(order.tenant_id),
            "triggered_by": "admin.refund",
        },
    }
    if body.amount_cents is not None:
        refund_args["amount"] = body.amount_cents
    if body.reason is not None:
        refund_args["reason"] = body.reason

    try:
        stripe_refund = stripe.Refund.create(**refund_args)
    except stripe.error.InvalidRequestError as exc:
        raise HTTPException(status_code=400, detail=f"Stripe refund rejected: {exc.user_message or 'unexpected error'}") from exc
    except stripe.error.StripeError as exc:  # pragma: no cover - defensive branch
        raise HTTPException(
            status_code=502,
            detail=f"Stripe refund creation failed: {exc.user_message or 'unexpected error'}",
        ) from exc

    refund_id = stripe_refund.get("id") or ""
    refund_status = stripe_refund.get("status") or "pending"
    refunded_amount = stripe_refund.get("amount")
    if not isinstance(refunded_amount, int):
        refunded_amount = body.amount_cents or order.total_cents
    currency = (stripe_refund.get("currency") or order.currency or "USD").upper()

    logger.info(
        "refund.manual_initiated",
        order_uuid=str(order.id),
        stripe_refund_id=refund_id,
        stripe_refund_status=refund_status,
        amount_cents=refunded_amount,
    )

    return RefundResponse(
        order_id=order.id,
        stripe_refund_id=refund_id,
        stripe_refund_status=refund_status,
        amount_cents=refunded_amount,
        currency=currency,
        payment_intent_id=order.stripe_payment_intent_id,
        state_update_mode="webhook_async",
    )
