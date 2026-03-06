"""Stripe API service layer — wraps stripe SDK calls for checkout and Connect routing."""
# @covers AC-009
# @spec: ecommerce-purchase-gateway_spec.md

import asyncio
import uuid

import stripe
import structlog

from app.config import settings

logger = structlog.get_logger()


class StripeService:
    """Thin wrapper around Stripe SDK for checkout session creation.

    Supports Stripe Connect multi-tenant routing via the ``stripe_account``
    parameter when a tenant has a connected Stripe account configured.
    """

    def __init__(self, stripe_account: str | None = None) -> None:
        """Initialise the service, optionally scoped to a connected account.

        Args:
            stripe_account: Stripe Connect account ID (e.g. ``acct_...``).
                When provided, all API calls are routed to that connected
                account rather than the platform account.
        """
        self.stripe_account = stripe_account

    def _request_options(self) -> dict:
        """Build per-request kwargs for Stripe Connect routing."""
        if self.stripe_account:
            return {"stripe_account": self.stripe_account}
        return {}

    async def create_checkout_session(
        self,
        *,
        customer_email: str,
        stripe_price_id: str,
        order_id: uuid.UUID,
        success_url: str,
        cancel_url: str,
    ) -> stripe.checkout.Session:
        """Create a Stripe Checkout Session.

        Embeds ``order_uuid`` in session metadata so the webhook handler can
        recover the order when the session ID is not yet stored locally.
        Sets ``capture_method: automatic`` on the payment intent.

        Args:
            customer_email: Buyer's email address.
            stripe_price_id: Stripe Price ID for the offering.
            order_id: Internal order UUID stored in session metadata as
                ``order_uuid``.
            success_url: Redirect URL on successful payment.
            cancel_url: Redirect URL when the buyer cancels.

        Returns:
            The created ``stripe.checkout.Session`` object.

        Raises:
            stripe.StripeError: On any Stripe API failure.
        """
        options = self._request_options()
        session = await asyncio.to_thread(
            stripe.checkout.Session.create,
            customer_email=customer_email,
            mode="payment",
            line_items=[
                {
                    "price": stripe_price_id,
                    "quantity": 1,
                }
            ],
            success_url=f"{success_url}?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=cancel_url,
            metadata={"order_uuid": str(order_id)},
            payment_intent_data={"capture_method": "automatic"},
            **options,
        )
        logger.info(
            "stripe.checkout_session_created",
            session_id=session.id,
            order_uuid=str(order_id),
            stripe_account=self.stripe_account,
        )
        return session

    @staticmethod
    def construct_webhook_event(
        payload: bytes,
        signature: str,
        webhook_secret: str | None = None,
    ) -> stripe.Event:
        """Verify and parse an incoming Stripe webhook payload.

        Args:
            payload: Raw request body bytes.
            signature: Value of the ``Stripe-Signature`` header.
            webhook_secret: HMAC secret for signature verification.
                Defaults to ``settings.STRIPE_WEBHOOK_SECRET``.

        Returns:
            Verified ``stripe.Event`` object.

        Raises:
            stripe.SignatureVerificationError: When the signature is invalid.
            ValueError: When the payload cannot be parsed.
        """
        secret = webhook_secret or settings.STRIPE_WEBHOOK_SECRET
        return stripe.Webhook.construct_event(payload, signature, secret)
