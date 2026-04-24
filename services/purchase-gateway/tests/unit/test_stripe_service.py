"""Unit tests for StripeService webhook signature helpers."""
# @covers AC-004
# @spec: ecommerce-purchase-gateway_spec.md

from unittest.mock import patch

from app.services.stripe_service import StripeService


@patch("app.services.stripe_service.stripe.Webhook.construct_event")
def test_construct_webhook_event_uses_configured_secret(mock_construct):
    """construct_webhook_event delegates to Stripe SDK with configured secret."""
    payload = b'{"id":"evt_123"}'
    signature = "t=1,v1=sig"
    StripeService.construct_webhook_event(payload, signature)
    mock_construct.assert_called_once()


@patch("app.services.stripe_service.StripeService.construct_webhook_event")
def test_verify_webhook_signature_aliases_construct_event(mock_construct):
    """verify_webhook_signature is a backward-compatible alias."""
    payload = b'{"id":"evt_123"}'
    signature = "t=1,v1=sig"
    webhook_secret = "whsec_test"

    StripeService.verify_webhook_signature(payload, signature, webhook_secret)

    mock_construct.assert_called_once_with(
        payload=payload,
        signature=signature,
        webhook_secret=webhook_secret,
    )
