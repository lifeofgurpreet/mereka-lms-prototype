import stripe
import structlog
from fastapi import APIRouter, Header, HTTPException, Request

from app.config import settings

router = APIRouter()
logger = structlog.get_logger()


@router.post("/webhooks/stripe/")
async def stripe_webhook(
    request: Request,
    stripe_signature: str = Header(alias="Stripe-Signature"),
):
    """Receive and verify Stripe webhook events.

    Returns 200 immediately. Actual processing is dispatched asynchronously.
    """
    payload = await request.body()
    stripe.api_key = settings.STRIPE_SECRET_KEY

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

    # TODO: Check stripe_events table for idempotency (duplicate event_id)
    # TODO: Log event in stripe_events table
    # TODO: Dispatch to fulfillment worker via Redis queue

    return {"status": "received"}
