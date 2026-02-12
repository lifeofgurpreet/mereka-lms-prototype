"""Enterprise subscription management — Stripe Subscriptions lifecycle."""
# @covers AC-022, AC-023
# @spec: ecommerce-purchase-gateway_spec.md

import uuid
from datetime import UTC, datetime, timedelta

import stripe
import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.offering import Offering
from app.models.subscription import Subscription, SubscriptionStatus

logger = structlog.get_logger()

# Grace period after payment failure before revoking access
GRACE_PERIOD_DAYS = 7


async def create_subscription(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    offering_id: uuid.UUID,
    stripe_customer_id: str,
    seat_count: int = 1,
    enterprise_customer_uuid: uuid.UUID | None = None,
) -> Subscription:
    """Create a Stripe subscription and local record for an enterprise seat pack."""
    if not settings.ENABLE_ENTERPRISE_SUBSCRIPTIONS:
        raise ValueError("Enterprise subscriptions are disabled")

    # Look up offering to get the Stripe price ID
    result = await db.execute(select(Offering).where(Offering.id == offering_id))
    offering = result.scalar_one_or_none()
    if not offering:
        raise ValueError(f"Offering {offering_id} not found")

    stripe.api_key = settings.STRIPE_SECRET_KEY

    stripe_sub = stripe.Subscription.create(
        customer=stripe_customer_id,
        items=[{"price": offering.stripe_price_id, "quantity": seat_count}],
        metadata={
            "tenant_id": str(tenant_id),
            "offering_id": str(offering_id),
        },
    )

    subscription = Subscription(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        enterprise_customer_uuid=enterprise_customer_uuid,
        offering_id=offering_id,
        stripe_subscription_id=stripe_sub.id,
        stripe_customer_id=stripe_customer_id,
        status=SubscriptionStatus(stripe_sub.status),
        current_period_start=datetime.fromtimestamp(
            stripe_sub.current_period_start, tz=UTC
        ),
        current_period_end=datetime.fromtimestamp(
            stripe_sub.current_period_end, tz=UTC
        ),
        seat_count=seat_count,
    )
    db.add(subscription)
    await db.commit()
    await db.refresh(subscription)

    logger.info(
        "subscription.created",
        subscription_uuid=str(subscription.id),
        stripe_subscription_id=stripe_sub.id,
        tenant_id=str(tenant_id),
        seat_count=seat_count,
    )
    return subscription


async def handle_subscription_created(event_data: dict, db: AsyncSession) -> None:
    """Handle customer.subscription.created webhook event."""
    sub_obj = event_data["object"]
    stripe_sub_id = sub_obj["id"]

    # Idempotency: check if already recorded
    result = await db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub_id)
    )
    if result.scalar_one_or_none():
        logger.info("subscription.already_exists", stripe_subscription_id=stripe_sub_id)
        return

    metadata = sub_obj.get("metadata", {})
    tenant_id = uuid.UUID(metadata["tenant_id"]) if metadata.get("tenant_id") else uuid.UUID(int=0)
    offering_id_str = metadata.get("offering_id")

    subscription = Subscription(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        offering_id=uuid.UUID(offering_id_str) if offering_id_str else uuid.UUID(int=0),
        stripe_subscription_id=stripe_sub_id,
        stripe_customer_id=sub_obj["customer"],
        status=SubscriptionStatus(sub_obj["status"]),
        current_period_start=datetime.fromtimestamp(
            sub_obj["current_period_start"], tz=UTC
        ),
        current_period_end=datetime.fromtimestamp(
            sub_obj["current_period_end"], tz=UTC
        ),
        seat_count=sub_obj.get("quantity", 1),
    )
    db.add(subscription)
    await db.commit()

    logger.info(
        "subscription.webhook_created",
        stripe_subscription_id=stripe_sub_id,
        status=sub_obj["status"],
    )


async def handle_subscription_updated(event_data: dict, db: AsyncSession) -> None:
    """Handle customer.subscription.updated — sync status, period, and seat count."""
    sub_obj = event_data["object"]
    stripe_sub_id = sub_obj["id"]

    result = await db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub_id)
    )
    subscription = result.scalar_one_or_none()
    if not subscription:
        logger.warning("subscription.not_found", stripe_subscription_id=stripe_sub_id)
        return

    old_status = subscription.status
    subscription.status = SubscriptionStatus(sub_obj["status"])
    subscription.current_period_start = datetime.fromtimestamp(
        sub_obj["current_period_start"], tz=UTC
    )
    subscription.current_period_end = datetime.fromtimestamp(
        sub_obj["current_period_end"], tz=UTC
    )

    # Update seat count from first subscription item
    items = sub_obj.get("items", {}).get("data", [])
    if items:
        subscription.seat_count = items[0].get("quantity", subscription.seat_count)

    # Clear grace period if subscription is now active
    if subscription.status == SubscriptionStatus.active and subscription.grace_period_end:
        subscription.grace_period_end = None

    await db.commit()

    logger.info(
        "subscription.updated",
        stripe_subscription_id=stripe_sub_id,
        old_status=old_status.value,
        new_status=subscription.status.value,
        seat_count=subscription.seat_count,
    )


async def handle_subscription_deleted(event_data: dict, db: AsyncSession) -> None:
    """Handle customer.subscription.deleted — mark as canceled."""
    sub_obj = event_data["object"]
    stripe_sub_id = sub_obj["id"]

    result = await db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub_id)
    )
    subscription = result.scalar_one_or_none()
    if not subscription:
        logger.warning("subscription.not_found", stripe_subscription_id=stripe_sub_id)
        return

    subscription.status = SubscriptionStatus.canceled
    subscription.canceled_at = datetime.now(UTC)
    await db.commit()

    logger.info(
        "subscription.canceled",
        subscription_uuid=str(subscription.id),
        stripe_subscription_id=stripe_sub_id,
    )


async def handle_invoice_paid(event_data: dict, db: AsyncSession) -> None:
    """Handle invoice.paid — renew subscription period (seat renewal)."""
    invoice = event_data["object"]
    stripe_sub_id = invoice.get("subscription")
    if not stripe_sub_id:
        return  # Not a subscription invoice

    result = await db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub_id)
    )
    subscription = result.scalar_one_or_none()
    if not subscription:
        return

    # Update period from the invoice's period
    period = invoice.get("lines", {}).get("data", [{}])[0].get("period", {})
    if period.get("start"):
        subscription.current_period_start = datetime.fromtimestamp(
            period["start"], tz=UTC
        )
    if period.get("end"):
        subscription.current_period_end = datetime.fromtimestamp(
            period["end"], tz=UTC
        )

    # Ensure active status after successful payment
    if subscription.status == SubscriptionStatus.past_due:
        subscription.status = SubscriptionStatus.active
    subscription.grace_period_end = None

    await db.commit()

    logger.info(
        "subscription.invoice_paid",
        subscription_uuid=str(subscription.id),
        stripe_subscription_id=stripe_sub_id,
    )


async def handle_invoice_payment_failed(event_data: dict, db: AsyncSession) -> None:
    """Handle invoice.payment_failed — set grace period before access revocation."""
    invoice = event_data["object"]
    stripe_sub_id = invoice.get("subscription")
    if not stripe_sub_id:
        return

    result = await db.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub_id)
    )
    subscription = result.scalar_one_or_none()
    if not subscription:
        return

    subscription.status = SubscriptionStatus.past_due
    subscription.grace_period_end = datetime.now(UTC) + timedelta(days=GRACE_PERIOD_DAYS)
    await db.commit()

    logger.info(
        "subscription.payment_failed",
        subscription_uuid=str(subscription.id),
        stripe_subscription_id=stripe_sub_id,
        grace_period_end=subscription.grace_period_end.isoformat(),
    )
