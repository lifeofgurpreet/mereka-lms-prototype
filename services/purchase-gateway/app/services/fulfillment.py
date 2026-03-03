"""Fulfillment engine — enrolls users or creates entitlements after payment."""
# @covers AC-002, AC-003, AC-019, AC-020, AC-021
# @spec: ecommerce-purchase-gateway_spec.md

import secrets
import uuid
from datetime import UTC, datetime, timedelta

import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.entitlement import Entitlement, EntitlementStatus
from app.models.order import FulfillmentStatus, Order, OrderStatus
from app.services.lms_client import LMSClient

logger = structlog.get_logger()


async def fulfill_order(order: Order, db: AsyncSession) -> None:
    """Process fulfillment for a paid order.

    Resolves the buyer's LMS account. If the user exists, enrolls them directly.
    If no user exists, creates an entitlement and triggers invitation.
    """
    if not settings.ENABLE_GATEWAY_FULFILLMENT:
        logger.info("fulfillment.disabled", order_uuid=str(order.id))
        return

    lms = LMSClient()
    user = await lms.get_user_by_email(order.buyer_email)

    for item in order.line_items:
        if item.fulfillment_status == FulfillmentStatus.fulfilled:
            continue  # Idempotent — already done

        if user:
            order.buyer_user_id = user["id"]
            success = await lms.enroll_user(
                username=user["username"],
                course_id=item.lms_resource_id,
            )
            item.fulfillment_status = (
                FulfillmentStatus.fulfilled if success else FulfillmentStatus.failed
            )
        else:
            # No LMS account — create entitlement
            claim_token = secrets.token_urlsafe(32)
            entitlement = Entitlement(
                id=uuid.uuid4(),
                order_id=order.id,
                line_item_id=item.id,
                tenant_id=order.tenant_id,
                recipient_email=order.buyer_email,
                lms_resource_id=item.lms_resource_id,
                offering_type=item.offering_type,
                status=EntitlementStatus.pending,
                claim_token=claim_token,
                expires_at=datetime.now(UTC)
                + timedelta(days=settings.ENTITLEMENT_CLAIM_EXPIRY_DAYS),
            )
            db.add(entitlement)
            item.fulfillment_status = FulfillmentStatus.fulfilled

            logger.info(
                "entitlement.created",
                entitlement_uuid=str(entitlement.id),
                order_uuid=str(order.id),
                tenant_id=str(order.tenant_id),
            )

    # Determine final order status
    statuses = {li.fulfillment_status for li in order.line_items}
    if statuses == {FulfillmentStatus.fulfilled}:
        order.status = OrderStatus.fulfilled
        order.fulfilled_at = datetime.now(UTC)
    elif FulfillmentStatus.failed in statuses and FulfillmentStatus.fulfilled in statuses:
        order.status = OrderStatus.partially_fulfilled
    elif statuses == {FulfillmentStatus.failed}:
        order.status = OrderStatus.fulfillment_failed
    else:
        order.status = OrderStatus.fulfilling

    await db.commit()
