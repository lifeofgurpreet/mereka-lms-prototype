# @covers AC-004, AC-006, AC-007, AC-008, AC-015, AC-016, AC-017, AC-018
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime, timedelta
from time import monotonic

import stripe
import structlog
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.metrics import observe_webhook_processing
from app.models.order import Order, OrderAuditLog, OrderStatus
from app.models.stripe_event import ProcessingStatus, StripeEvent
from app.services.dispute import handle_dispute_closed, handle_dispute_created
from app.services.fulfillment_outbox import enqueue_fulfillment_job
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


async def _persist_failed_event_status(db: AsyncSession, *, event_id: str) -> None:
    """Persist failed webhook event status in a fresh transaction after rollback."""
    try:
        result = await db.execute(
            update(StripeEvent)
            .where(StripeEvent.stripe_event_id == event_id)
            .values(processing_status=ProcessingStatus.failed)
        )
        await db.commit()
        if not getattr(result, "rowcount", 0):
            logger.warning("webhook.failed_event_not_found", stripe_event_id=event_id)
    except Exception:
        await db.rollback()
        logger.error("webhook.failed_status_update_error", stripe_event_id=event_id)


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
    session_metadata = session.get("metadata") or {}
    order_uuid_raw = session_metadata.get("order_uuid")

    result = await db.execute(
        select(Order).where(Order.stripe_checkout_session_id == session_id)
    )
    order = result.scalar_one_or_none()
    if not order and order_uuid_raw:
        try:
            order_uuid = uuid.UUID(order_uuid_raw)
        except (TypeError, ValueError):
            order_uuid = None
            logger.warning(
                "webhook.order_uuid_invalid",
                session_id=session_id,
                order_uuid=order_uuid_raw,
            )
        if order_uuid:
            by_uuid_result = await db.execute(select(Order).where(Order.id == order_uuid))
            order = by_uuid_result.scalar_one_or_none()
            if order:
                if order.stripe_checkout_session_id != session_id:
                    order.stripe_checkout_session_id = session_id
                logger.warning(
                    "webhook.order_recovered_by_metadata",
                    session_id=session_id,
                    order_uuid=str(order.id),
                )
    if not order:
        if order_uuid_raw:
            logger.error(
                "webhook.order_not_found_with_metadata",
                session_id=session_id,
                order_uuid=order_uuid_raw,
            )
            raise LookupError(
                f"checkout.session.completed could not resolve order_uuid={order_uuid_raw}"
            )

        logger.warning(
            "webhook.order_not_found",
            session_id=session_id,
            order_uuid=order_uuid_raw,
        )
        return

    old_status = order.status
    if old_status in {OrderStatus.pending, OrderStatus.expired, OrderStatus.canceled}:
        order.status = OrderStatus.paid
    order.stripe_payment_intent_id = payment_intent_id

    if old_status != order.status:
        await _log_audit(
            db, order, old_status, OrderStatus.paid, "stripe.checkout.session.completed"
        )

    await enqueue_fulfillment_job(
        db,
        order=order,
        triggered_by="stripe.checkout.session.completed",
        force=False,
    )
    await db.commit()


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
    started_at = monotonic()
    payload = await request.body()
    try:
        event = stripe.Webhook.construct_event(
            payload, stripe_signature, settings.STRIPE_WEBHOOK_SECRET
        )
    except stripe.SignatureVerificationError as exc:
        observe_webhook_processing(
            event_type="unknown",
            status="invalid_signature",
            duration_seconds=monotonic() - started_at,
        )
        logger.warning("webhook.signature_invalid")
        raise HTTPException(status_code=400, detail="Invalid signature") from exc
    except ValueError as exc:
        observe_webhook_processing(
            event_type="unknown",
            status="invalid_payload",
            duration_seconds=monotonic() - started_at,
        )
        logger.warning("webhook.invalid_payload")
        raise HTTPException(status_code=400, detail="Invalid payload") from exc

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
            observe_webhook_processing(
                event_type=event_type,
                status="duplicate",
                duration_seconds=monotonic() - started_at,
            )
            logger.info("webhook.duplicate", stripe_event_id=event_id)
            return {"status": "duplicate"}
        if existing_event.processing_status == ProcessingStatus.failed:
            logger.info("webhook.retrying_failed", stripe_event_id=event_id)
            stripe_event_record = existing_event
        else:
            stale_after_seconds = max(0, settings.STRIPE_EVENT_STALE_PROCESSING_SECONDS)
            stale_cutoff = datetime.now(UTC) - timedelta(seconds=stale_after_seconds)
            is_stale_processing = bool(
                stale_after_seconds
                and existing_event.received_at
                and existing_event.received_at <= stale_cutoff
            )
            if is_stale_processing:
                logger.warning(
                    "webhook.retrying_stale_processing",
                    stripe_event_id=event_id,
                    stale_after_seconds=stale_after_seconds,
                )
                stripe_event_record = existing_event
            else:
                observe_webhook_processing(
                    event_type=event_type,
                    status="duplicate",
                    duration_seconds=monotonic() - started_at,
                )
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
            observe_webhook_processing(
                event_type=event_type,
                status="duplicate",
                duration_seconds=monotonic() - started_at,
            )
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
        stripe_event_record.processed_at = datetime.now(UTC)
        await db.commit()

    except Exception as e:
        logger.error(
            "webhook.processing_failed",
            stripe_event_id=event_id,
            error=str(e),
        )
        await db.rollback()
        await _persist_failed_event_status(db, event_id=event_id)
        observe_webhook_processing(
            event_type=event_type,
            status="failed",
            duration_seconds=monotonic() - started_at,
        )
        return JSONResponse(
            status_code=500,
            content={"status": "error", "detail": "Webhook processing failed"},
        )

    observe_webhook_processing(
        event_type=event_type,
        status="processed",
        duration_seconds=monotonic() - started_at,
    )
    return {"status": "received"}
