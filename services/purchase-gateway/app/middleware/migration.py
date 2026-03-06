"""Migration routing helpers for phased Oscar -> Purchase Gateway cutover."""
# @covers AC-027
# @spec: ecommerce-purchase-gateway_spec.md

from __future__ import annotations

from dataclasses import dataclass

import structlog
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import settings

logger = structlog.get_logger()

# Legacy references indicate in-flight Oscar sessions/orders that should stay
# on the legacy handling path until migration is complete.
LEGACY_REFERENCE_PREFIXES = (
    "oscar_",
    "oscar-",
    "ecom_",
    "ecom-",
    "legacy_",
)


def is_legacy_checkout_reference(reference: str | None) -> bool:
    """Return True when a checkout reference indicates legacy Oscar routing."""
    if not reference:
        return False
    normalized = reference.strip().lower()
    return any(normalized.startswith(prefix) for prefix in LEGACY_REFERENCE_PREFIXES)


@dataclass(frozen=True)
class MigrationRouteDecision:
    """Routing decision for a purchase request during migration."""

    route: str
    reason: str


def decide_checkout_route(
    *,
    gateway_fulfillment_enabled: bool,
    checkout_reference: str | None,
) -> MigrationRouteDecision:
    """Choose gateway vs legacy checkout path during phased migration."""
    if is_legacy_checkout_reference(checkout_reference):
        return MigrationRouteDecision(route="legacy", reason="legacy_reference")

    if gateway_fulfillment_enabled:
        return MigrationRouteDecision(route="gateway", reason="gateway_fulfillment_enabled")

    return MigrationRouteDecision(route="legacy", reason="gateway_fulfillment_disabled")


class MigrationRoutingMiddleware(BaseHTTPMiddleware):
    """Annotate requests with migration routing decision metadata."""

    async def dispatch(self, request: Request, call_next):
        checkout_reference = request.headers.get("X-Mereka-Checkout-Reference")
        if not checkout_reference:
            checkout_reference = request.query_params.get("checkout_reference")

        decision = decide_checkout_route(
            gateway_fulfillment_enabled=settings.ENABLE_GATEWAY_FULFILLMENT,
            checkout_reference=checkout_reference,
        )

        request.state.checkout_route = decision.route
        request.state.checkout_route_reason = decision.reason

        if decision.route == "legacy":
            logger.info(
                "checkout.route_legacy",
                reason=decision.reason,
                checkout_reference=checkout_reference,
            )

        response = await call_next(request)
        response.headers["X-Mereka-Checkout-Route"] = decision.route
        return response


__all__ = [
    "MigrationRouteDecision",
    "MigrationRoutingMiddleware",
    "decide_checkout_route",
    "is_legacy_checkout_reference",
]
