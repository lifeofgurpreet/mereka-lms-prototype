"""Unit tests for migration routing helpers."""
# @covers AC-027
# @spec: ecommerce-purchase-gateway_spec.md

from app.middleware.migration import (
    decide_checkout_route,
    is_legacy_checkout_reference,
)


def test_is_legacy_checkout_reference_detects_known_prefixes():
    assert is_legacy_checkout_reference("oscar_order_123")
    assert is_legacy_checkout_reference("ECOM-session-1")
    assert is_legacy_checkout_reference("legacy_checkout_42")


def test_is_legacy_checkout_reference_ignores_unknown_values():
    assert not is_legacy_checkout_reference(None)
    assert not is_legacy_checkout_reference("")
    assert not is_legacy_checkout_reference("gateway_checkout_123")


def test_decide_checkout_route_prefers_legacy_reference_when_gateway_enabled():
    decision = decide_checkout_route(
        gateway_fulfillment_enabled=True,
        checkout_reference="oscar_order_123",
    )
    assert decision.route == "legacy"
    assert decision.reason == "legacy_reference"


def test_decide_checkout_route_uses_gateway_when_enabled_without_legacy_reference():
    decision = decide_checkout_route(
        gateway_fulfillment_enabled=True,
        checkout_reference="gateway_checkout_123",
    )
    assert decision.route == "gateway"
    assert decision.reason == "gateway_fulfillment_enabled"


def test_decide_checkout_route_falls_back_to_legacy_when_gateway_disabled():
    decision = decide_checkout_route(
        gateway_fulfillment_enabled=False,
        checkout_reference="gateway_checkout_123",
    )
    assert decision.route == "legacy"
    assert decision.reason == "gateway_fulfillment_disabled"
