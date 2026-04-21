"""Purchase-gateway Prometheus metrics helpers."""

from prometheus_client import Counter, Histogram

# Generic HTTP request counter consumed by PurchaseGatewayHighErrorRate alert
# (deploy/k8s/base/monitoring/prometheusrule-services.yaml). Label names
# (method, handler, status_code) match the alert expr verbatim — see bead
# mereka-lms-zuv1 for context.
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Count of HTTP requests handled by the purchase-gateway app.",
    labelnames=("method", "handler", "status_code"),
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "Latency of HTTP requests handled by the purchase-gateway app.",
    labelnames=("method", "handler", "status_code"),
)

CHECKOUT_CREATED_TOTAL = Counter(
    "purchase_gateway_checkout_total",
    "Number of successful checkout sessions created.",
)

WEBHOOK_PROCESSING_SECONDS = Histogram(
    "purchase_gateway_webhook_processing_seconds",
    "Stripe webhook processing latency in seconds.",
    labelnames=("event_type", "status"),
)

FULFILLMENT_DURATION_SECONDS = Histogram(
    "purchase_gateway_fulfillment_duration_seconds",
    "Fulfillment outbox job processing duration in seconds.",
    labelnames=("status",),
)

FULFILLMENT_DEAD_LETTER_TOTAL = Counter(
    "purchase_gateway_dead_letter_total",
    "Number of fulfillment jobs moved to dead letter status.",
)

RECONCILIATION_QUEUED_TOTAL = Counter(
    "purchase_gateway_reconciliation_queued_total",
    "Number of orders queued by reconciliation sweeps.",
)


def record_checkout_created() -> None:
    CHECKOUT_CREATED_TOTAL.inc()


def observe_webhook_processing(
    *,
    event_type: str,
    status: str,
    duration_seconds: float,
) -> None:
    WEBHOOK_PROCESSING_SECONDS.labels(event_type=event_type, status=status).observe(
        max(0.0, duration_seconds)
    )


def observe_fulfillment_duration(*, status: str, duration_seconds: float) -> None:
    FULFILLMENT_DURATION_SECONDS.labels(status=status).observe(max(0.0, duration_seconds))


def record_dead_letter() -> None:
    FULFILLMENT_DEAD_LETTER_TOTAL.inc()


def record_reconciliation_queued(count: int) -> None:
    if count > 0:
        RECONCILIATION_QUEUED_TOTAL.inc(count)
