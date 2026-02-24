"""Dispute handling — processes charge.dispute.created and charge.dispute.closed events."""
# @covers AC-017, AC-018
# @spec: ecommerce-purchase-gateway_spec.md

import asyncio
from datetime import UTC, datetime

import stripe
import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
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


async def _find_order_by_dispute(dispute: dict, db: AsyncSession) -> Order | None:
    """Resolve a dispute to its associated order via charge → payment_intent."""
    charge_id = dispute.get("charge")
    if not charge_id:
        return None

    stripe.api_key = settings.STRIPE_SECRET_KEY
    charge = await asyncio.to_thread(stripe.Charge.retrieve, charge_id)
    payment_intent_id = charge.payment_intent

    result = await db.execute(
        select(Order).where(Order.stripe_payment_intent_id == payment_intent_id)
    )
    return result.scalar_one_or_none()


async def _revoke_order_enrollments(order: Order) -> None:
    """Revoke all enrollments for an order (used on dispute auto-revoke)."""
    if not order.buyer_user_id:
        return

    lms = LMSClient()
    user = await lms.get_user_by_email(order.buyer_email)
    if not user:
        return

    for item in order.line_items:
        success = await lms.deactivate_enrollment(user["username"], item.lms_resource_id)
        if success:
            logger.info(
                "dispute.enrollment_revoked",
                order_uuid=str(order.id),
                course_id=item.lms_resource_id,
            )


async def _restore_order_enrollments(order: Order) -> None:
    """Re-activate enrollments after winning a dispute."""
    if not order.buyer_user_id:
        return

    lms = LMSClient()
    user = await lms.get_user_by_email(order.buyer_email)
    if not user:
        return

    for item in order.line_items:
        await lms.enroll_user(user["username"], item.lms_resource_id)
        logger.info(
            "dispute.enrollment_restored",
            order_uuid=str(order.id),
            course_id=item.lms_resource_id,
        )


async def handle_dispute_created(event_data: dict, db: AsyncSession) -> None:
    """Handle charge.dispute.created — flag order, optionally auto-revoke enrollments."""
    dispute = event_data["object"]

    order = await _find_order_by_dispute(dispute, db)
    if not order:
        logger.warning("dispute.order_not_found", dispute_id=dispute["id"])
        return

    # Idempotency: skip if already disputed
    if order.status == OrderStatus.disputed:
        logger.info("dispute.already_flagged", order_uuid=str(order.id))
        return

    old_status = order.status
    order.status = OrderStatus.disputed

    await _log_audit(
        db,
        order,
        old_status,
        OrderStatus.disputed,
        "stripe.charge.dispute.created",
        details={"dispute_id": dispute["id"], "reason": dispute.get("reason")},
    )

    # Optional auto-revoke based on feature flag
    if settings.ENABLE_AUTO_REVOKE_ON_DISPUTE:
        await _revoke_order_enrollments(order)
        logger.info("dispute.auto_revoked", order_uuid=str(order.id))

    await db.commit()

    logger.info(
        "dispute.created",
        order_uuid=str(order.id),
        dispute_id=dispute["id"],
        reason=dispute.get("reason"),
    )


async def handle_dispute_closed(event_data: dict, db: AsyncSession) -> None:
    """Handle charge.dispute.closed — restore if won, revoke if lost."""
    dispute = event_data["object"]
    outcome = dispute["status"]

    order = await _find_order_by_dispute(dispute, db)
    if not order:
        logger.warning("dispute.order_not_found", dispute_id=dispute["id"])
        return

    old_status = order.status

    if outcome == "won":
        # Merchant won — restore order and re-activate enrollments
        order.status = OrderStatus.paid
        await _restore_order_enrollments(order)
        action = "dispute_won_restored"
    else:
        # Lost or closed without winning — treat as refunded
        order.status = OrderStatus.refunded
        order.refunded_at = datetime.now(UTC)
        await _revoke_order_enrollments(order)
        action = "dispute_lost_refunded"

    await _log_audit(
        db,
        order,
        old_status,
        order.status,
        "stripe.charge.dispute.closed",
        details={"dispute_id": dispute["id"], "outcome": outcome, "action": action},
    )
    await db.commit()

    logger.info(
        "dispute.closed",
        order_uuid=str(order.id),
        dispute_id=dispute["id"],
        outcome=outcome,
        action=action,
    )
