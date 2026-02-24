# @covers AC-004, AC-006, AC-007, AC-008, AC-015, AC-016, AC-017, AC-018
# @spec: ecommerce-purchase-gateway_spec.md

from datetime import datetime, timezone

import stripe
import structlog
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.order import Order, OrderAuditLog, OrderStatus
from app.models.stripe_event import ProcessingStatus, StripeEvent
from app.services.dispute import handle_dispute_closed, handle_dispute_created
from app.services.fulfillment import fulfill_order
from app.services.refund import process_refund
from app.services.subscription import (
    handle_invoice_paid,
    handle_invoice_payment_failed,
    handle_subscription_created,
    handle_subscription_deleted,
    handle_subscription_updated,
)

router = APIRouter()
logger = structlog.get_logger()


async def _log_audit(
    db: AsyncSession,
    order: Order,
    old_status: OrderStatus,
    new_status: OrderStatus,
    triggered_by: str,
    details: dict | None = None,
):
    """Create an audit log entry for order state transition."""
    audit_entry = OrderAuditLog(
        order_id=order.id,
        old_status=old_status.value,
        new_status=new_status.value,
        triggered_by=triggered_by,
        details=details,
    )
    db.add(audit_entry)
    logger.info(
        "order.status_changed",
        order_uuid=str(order.id),
        old_status=old_status.value,
        new_status=new_status.value,
        triggered_by=triggered_by,
    )


async def _handle_checkout_completed(
    event_data: dict,
    db: AsyncSession,
):
    """Handle checkout.session.completed event."""
    session = event_data["object"]
    session_id = session["id"]
    payment_intent_id = session.get("payment_intent")

    result = await db.execute(
        select(Order).where(Order.stripe_checkout_session_id == session_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        logger.warning("webhook.order_not_found", session_id=session_id)
        return

    old_status = order.status
    order.status = OrderStatus.paid
    order.stripe_payment_intent_id = payment_intent_id

    await _log_audit(
        db, order, old_status, OrderStatus.paid, "stripe.checkout.session.completed"
    )
    await db.commit()

    # Dispatch fulfillment
    await fulfill_order(order, db)


async def _handle_checkout_expired(
    event_data: dict,
    db: AsyncSession,
):
    """Handle checkout.session.expired event."""
    session = event_data["object"]
    session_id = session["id"]

    result = await db.execute(
        select(Order).where(Order.stripe_checkout_session_id == session_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        return

    old_status = order.status
    order.status = OrderStatus.expired

    await _log_audit(
        db, order, old_status, OrderStatus.expired, "stripe.checkout.session.expired"
    )
    await db.commit()


async def _handle_payment_failed(
    event_data: dict,
    db: AsyncSession,
):
    """Handle payment_intent.payment_failed event."""
    payment_intent = event_data["object"]
    payment_intent_id = payment_intent["id"]

    result = await db.execute(
        select(Order).where(Order.stripe_payment_intent_id == payment_intent_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        return

    old_status = order.status
    # Add payment_failed to OrderStatus if missing (scaffold doesn't have it)
    # For now, use "canceled" as closest match
    order.status = OrderStatus.canceled

    await _log_audit(
        db,
        order,
        old_status,
        OrderStatus.canceled,
        "stripe.payment_intent.payment_failed",
        details={"payment_intent_id": payment_intent_id},
    )
    await db.commit()


async def _handle_refund(event_data: dict, db: AsyncSession):
    """Handle charge.refunded — delegates to refund service."""
    await process_refund(event_data, db)


async def _handle_dispute_created(event_data: dict, db: AsyncSession):
    """Handle charge.dispute.created — delegates to dispute service."""
    await handle_dispute_created(event_data, db)


async def _handle_dispute_closed(event_data: dict, db: AsyncSession):
    """Handle charge.dispute.closed — delegates to dispute service."""
    await handle_dispute_closed(event_data, db)


@router.post("/webhooks/stripe/")
async def stripe_webhook(
    request: Request,
    stripe_signature: str = Header(alias="Stripe-Signature"),
    db: AsyncSession = Depends(get_db),
):
    """Handle incoming Stripe webhook events with idempotent processing."""
    payload = await request.body()
    try:
        event = stripe.Webhook.construct_event(
            payload, stripe_signature, settings.STRIPE_WEBHOOK_SECRET
        )
    except stripe.SignatureVerificationError:
        logger.warning("webhook.signature_invalid")
        raise HTTPException(status_code=400, detail="Invalid signature")
    except ValueError:
        logger.warning("webhook.invalid_payload")
        raise HTTPException(status_code=400, detail="Invalid payload")

    event_id = event["id"]
    event_type = event["type"]

    logger.info(
        "webhook.received",
        stripe_event_id=event_id,
        event_type=event_type,
    )

    # Check idempotency: already processed this event?
    result = await db.execute(
        select(StripeEvent).where(StripeEvent.stripe_event_id == event_id)
    )
    existing_event = result.scalar_one_or_none()
    if existing_event:
        # Allow retry of failed events; skip already-processed ones
        if existing_event.processing_status == ProcessingStatus.processed:
            logger.info("webhook.duplicate", stripe_event_id=event_id)
            return {"status": "duplicate"}
        if existing_event.processing_status == ProcessingStatus.failed:
            logger.info("webhook.retrying_failed", stripe_event_id=event_id)
            stripe_event_record = existing_event
        else:
            logger.info("webhook.already_processing", stripe_event_id=event_id)
            return {"status": "duplicate"}
    else:
        # Log event in stripe_events table (handle race with IntegrityError)
        stripe_event_record = StripeEvent(
            stripe_event_id=event_id,
            event_type=event_type,
            payload_json=event,
            processing_status=ProcessingStatus.received,
        )
        db.add(stripe_event_record)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            logger.info("webhook.duplicate_race", stripe_event_id=event_id)
            return {"status": "duplicate"}

    # Process event
    try:
        stripe_event_record.processing_status = ProcessingStatus.processing
        await db.commit()

        event_data = event["data"]
        if event_type == "checkout.session.completed":
            await _handle_checkout_completed(event_data, db)
        elif event_type == "checkout.session.expired":
            await _handle_checkout_expired(event_data, db)
        elif event_type == "payment_intent.payment_failed":
            await _handle_payment_failed(event_data, db)
        elif event_type == "charge.refunded":
            await _handle_refund(event_data, db)
        elif event_type == "charge.dispute.created":
            await _handle_dispute_created(event_data, db)
        elif event_type == "charge.dispute.closed":
            await _handle_dispute_closed(event_data, db)
        elif event_type == "customer.subscription.created":
            await handle_subscription_created(event_data, db)
        elif event_type == "customer.subscription.updated":
            await handle_subscription_updated(event_data, db)
        elif event_type == "customer.subscription.deleted":
            await handle_subscription_deleted(event_data, db)
        elif event_type == "invoice.paid":
            await handle_invoice_paid(event_data, db)
        elif event_type == "invoice.payment_failed":
            await handle_invoice_payment_failed(event_data, db)
        else:
            logger.info("webhook.unhandled_event_type", event_type=event_type)

        stripe_event_record.processing_status = ProcessingStatus.processed
        stripe_event_record.processed_at = datetime.now(timezone.utc)
        await db.commit()

    except Exception as e:
        logger.error(
            "webhook.processing_failed",
            stripe_event_id=event_id,
            error=str(e),
        )
        await db.rollback()
        stripe_event_record.processing_status = ProcessingStatus.failed
        try:
            await db.commit()
        except Exception:
            logger.error("webhook.failed_status_update_error", stripe_event_id=event_id)
        return JSONResponse(
            status_code=500,
            content={"status": "error", "detail": "Webhook processing failed"},
        )

    return {"status": "received"}
