# @covers AC-001, AC-005
# @spec: ecommerce-purchase-gateway_spec.md

import asyncio
import uuid
from urllib.parse import urlparse

import stripe
import structlog
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, HttpUrl, model_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.offering import Offering
from app.models.order import LineItem, Order, OrderStatus

router = APIRouter()
logger = structlog.get_logger()


def _is_allowed_origin(url: str) -> bool:
    """Check if a URL's origin is in the allowed list."""
    parsed = urlparse(url)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    return origin in settings.ALLOWED_ORIGINS


class CheckoutRequest(BaseModel):
    offering_uuid: uuid.UUID
    buyer_email: EmailStr
    tenant_id: uuid.UUID | None = None
    success_url: HttpUrl
    cancel_url: HttpUrl
    metadata: dict | None = None

    @model_validator(mode="after")
    def validate_redirect_urls(self):
        for field_name in ("success_url", "cancel_url"):
            url = str(getattr(self, field_name))
            if not _is_allowed_origin(url):
                raise ValueError(f"{field_name} origin not in ALLOWED_ORIGINS")
        return self


class CheckoutResponse(BaseModel):
    checkout_url: str
    order_id: uuid.UUID
    session_id: str


@router.post("/checkout/", response_model=CheckoutResponse)
async def create_checkout(
    request: CheckoutRequest,
    db: AsyncSession = Depends(get_db),
):
    """Create a Stripe Checkout Session for a given offering."""
    # Look up offering by UUID from DB to get stripe_price_id and details
    result = await db.execute(
        select(Offering).where(
            Offering.id == request.offering_uuid,
            Offering.active == True,  # noqa: E712
        )
    )
    offering = result.scalar_one_or_none()
    if not offering:
        raise HTTPException(status_code=404, detail="Offering not found or inactive")

    # Validate tenant isolation if enabled
    tenant_id = request.tenant_id or uuid.UUID("00000000-0000-0000-0000-000000000000")
    if settings.TENANT_ISOLATION_ENABLED and offering.tenant_id != tenant_id:
        raise HTTPException(status_code=403, detail="Offering not available for this tenant")

    order_id = uuid.uuid4()

    # Create pending order
    order = Order(
        id=order_id,
        tenant_id=tenant_id,
        buyer_email=request.buyer_email,
        stripe_checkout_session_id=f"pending-{order_id}",  # Unique placeholder until Stripe responds
        status=OrderStatus.pending,
        total_cents=offering.price_cents,
        currency=offering.currency,
        metadata_json=request.metadata,
    )

    try:
        session = await asyncio.to_thread(
            stripe.checkout.Session.create,
            customer_email=request.buyer_email,
            mode="payment",
            line_items=[
                {
                    "price": offering.stripe_price_id,
                    "quantity": 1,
                }
            ],
            success_url=f"{request.success_url}?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=str(request.cancel_url),
            metadata={"order_uuid": str(order_id)},
            payment_intent_data={"capture_method": "automatic"},
        )
    except stripe.StripeError as e:
        logger.error(
            "checkout.stripe_error",
            error=str(e),
            tenant_id=str(tenant_id),
        )
        raise HTTPException(status_code=503, detail="Payment service unavailable") from e

    order.stripe_checkout_session_id = session.id

    db.add(order)
    await db.commit()

    logger.info(
        "checkout.created",
        order_uuid=str(order_id),
        tenant_id=str(tenant_id),
        offering_uuid=str(request.offering_uuid),
    )

    return CheckoutResponse(
        checkout_url=session.url,
        order_id=order_id,
        session_id=session.id,
    )


@router.get("/checkout/{session_id}/status/")
async def checkout_status(session_id: str, db: AsyncSession = Depends(get_db)):
    """Check order status after checkout."""
    result = await db.execute(
        select(Order).where(Order.stripe_checkout_session_id == session_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return {
        "order_id": str(order.id),
        "status": order.status.value,
    }
