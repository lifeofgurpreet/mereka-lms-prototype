"""Refund processing — handles charge.refunded events and enrollment revocation."""
# @covers AC-015, AC-016
# @spec: ecommerce-purchase-gateway_spec.md

from datetime import UTC, datetime

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order, OrderAuditLog, OrderStatus
from app.services.lms_client import LMSClient

logger = structlog.get_logger()


async def _log_audit(
    db: AsyncSession,
    order: Order,
    old_status: OrderStatus,
    new_status: OrderStatus,
    triggered_by: str,
    details: dict | None = None,
) -> None:
    audit_entry = OrderAuditLog(
        order_id=order.id,
        old_status=old_status.value,
        new_status=new_status.value,
        triggered_by=triggered_by,
        details=details,
    )
    db.add(audit_entry)


async def revoke_enrollment(username: str, course_id: str) -> bool:
    """Revoke a single enrollment via the LMS enrollment API."""
    lms = LMSClient()
    success = await lms.deactivate_enrollment(username, course_id)
    if success:
        logger.info("enrollment.revoked", username=username, course_id=course_id)
    else:
        logger.error("enrollment.revoke_failed", username=username, course_id=course_id)
    return success


async def _revoke_order_enrollments(order: Order) -> None:
    """Revoke all enrollments associated with an order."""
    if not order.buyer_user_id:
        return

    lms = LMSClient()
    user = await lms.get_user_by_email(order.buyer_email)
    if not user:
        return

    for item in order.line_items:
        await revoke_enrollment(user["username"], item.lms_resource_id)


async def process_refund(event_data: dict, db: AsyncSession) -> None:
    """Handle charge.refunded event — idempotent, handles full and partial refunds."""
    charge = event_data["object"]
    payment_intent_id = charge.get("payment_intent")
    amount_refunded = charge["amount_refunded"]
    amount = charge["amount"]

    result = await db.execute(
        select(Order).where(Order.stripe_payment_intent_id == payment_intent_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        logger.warning("refund.order_not_found", payment_intent_id=payment_intent_id)
        return

    # Idempotency: skip if already fully refunded
    if order.status == OrderStatus.refunded:
        logger.info("refund.already_processed", order_uuid=str(order.id))
        return

    old_status = order.status
    is_full_refund = amount_refunded >= amount

    if is_full_refund:
        order.status = OrderStatus.refunded
        await _revoke_order_enrollments(order)
    else:
        order.status = OrderStatus.partially_refunded

    order.refunded_at = datetime.now(UTC)

    await _log_audit(
        db,
        order,
        old_status,
        order.status,
        "stripe.charge.refunded",
        details={
            "amount_refunded": amount_refunded,
            "total_amount": amount,
            "full_refund": is_full_refund,
        },
    )
    await db.commit()

    logger.info(
        "refund.processed",
        order_uuid=str(order.id),
        full_refund=is_full_refund,
        amount_refunded=amount_refunded,
    )


async def process_partial_refund(event_data: dict, db: AsyncSession) -> None:
    """Handle partial refund — updates status but does not revoke enrollments."""
    charge = event_data["object"]
    payment_intent_id = charge.get("payment_intent")
    amount_refunded = charge["amount_refunded"]
    amount = charge["amount"]

    result = await db.execute(
        select(Order).where(Order.stripe_payment_intent_id == payment_intent_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        return

    if order.status == OrderStatus.partially_refunded:
        return  # Idempotent

    old_status = order.status
    order.status = OrderStatus.partially_refunded
    order.refunded_at = datetime.now(UTC)

    await _log_audit(
        db,
        order,
        old_status,
        order.status,
        "stripe.charge.refunded",
        details={
            "amount_refunded": amount_refunded,
            "total_amount": amount,
            "full_refund": False,
        },
    )
    await db.commit()
