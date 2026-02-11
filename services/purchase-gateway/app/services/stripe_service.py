"""Stripe API interaction layer."""

import stripe
import structlog

from app.config import settings

logger = structlog.get_logger()


async def create_checkout_session(
    *,
    price_id: str,
    customer_email: str,
    order_uuid: str,
    success_url: str,
    cancel_url: str,
    stripe_account: str | None = None,
) -> stripe.checkout.Session:
    """Create a Stripe Checkout Session.

    Args:
        price_id: Stripe Price object ID.
        customer_email: Buyer's email address.
        order_uuid: Internal order UUID for correlation.
        success_url: URL to redirect to after successful payment.
        cancel_url: URL to redirect to after cancellation.
        stripe_account: Stripe Connect account ID for multi-tenant.
    """
    stripe.api_key = settings.STRIPE_SECRET_KEY

    kwargs: dict = {
        "customer_email": customer_email,
        "mode": "payment",
        "line_items": [{"price": price_id, "quantity": 1}],
        "success_url": f"{success_url}?session_id={{CHECKOUT_SESSION_ID}}",
        "cancel_url": cancel_url,
        "metadata": {"order_uuid": order_uuid},
        "payment_intent_data": {"capture_method": "automatic"},
    }

    if stripe_account:
        kwargs["stripe_account"] = stripe_account

    return stripe.checkout.Session.create(**kwargs)


async def verify_webhook_signature(payload: bytes, signature: str) -> dict:
    """Verify a Stripe webhook signature and return the parsed event."""
    return stripe.Webhook.construct_event(
        payload, signature, settings.STRIPE_WEBHOOK_SECRET
    )
