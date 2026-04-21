"""Tests for PrometheusHTTPMetricsMiddleware.

Bead: mereka-lms-zuv1 — verifies that http_requests_total + duration metrics
are emitted with the label names the PurchaseGatewayHighErrorRate alert reads.
"""

import pytest
from prometheus_client import REGISTRY, generate_latest

from app.main import app  # noqa: F401 — ensures middleware is registered
from app.metrics import HTTP_REQUEST_DURATION_SECONDS, HTTP_REQUESTS_TOTAL


def _sample_total(counter, **labels):
    """Return the current value of a Counter for given labels (0 if absent)."""
    return counter.labels(**labels)._value.get()  # prometheus_client internal; fine in tests


def test_metric_names_match_alert_contract():
    """Alert PurchaseGatewayHighErrorRate filters on status_code=~'5..' and
    job='purchase-gateway-metrics'. The metric must:
      - be named http_requests_total (prometheus_client strips the _total suffix internally)
      - carry a status_code label (not status)
    """
    # _name is the Counter's stem (prometheus_client appends _total automatically).
    assert HTTP_REQUESTS_TOTAL._name == "http_requests"
    assert HTTP_REQUESTS_TOTAL._labelnames == ("method", "handler", "status_code")
    assert HTTP_REQUEST_DURATION_SECONDS._labelnames == ("method", "handler", "status_code")


@pytest.mark.asyncio
async def test_request_increments_counter(client):
    """A GET /health/ hits the middleware and increments http_requests_total.

    The test does not assert a specific status code because the health check
    may return 503 when the DB is unreachable in the test environment — what
    matters is that the middleware recorded the request under whatever status
    code it actually returned.
    """
    response = await client.get("/health/")
    status_code = str(response.status_code)

    sample = _sample_total(
        HTTP_REQUESTS_TOTAL, method="GET", handler="/health/", status_code=status_code
    )
    assert sample >= 1, f"Counter for status={status_code} should have at least one sample"


@pytest.mark.asyncio
async def test_metrics_endpoint_not_self_counted(client):
    """GET /metrics itself must not appear as a sample — would cause feedback.
    Any status code the router returns is acceptable (may 200 or 307 depending
    on how the ASGI mount resolves); what matters is the counter did NOT
    increment for handler='/metrics'.
    """
    before_values = {
        code: _sample_total(
            HTTP_REQUESTS_TOTAL, method="GET", handler="/metrics", status_code=code
        )
        for code in ("200", "307", "404")
    }
    await client.get("/metrics")
    after_values = {
        code: _sample_total(
            HTTP_REQUESTS_TOTAL, method="GET", handler="/metrics", status_code=code
        )
        for code in ("200", "307", "404")
    }
    assert before_values == after_values, (
        "Middleware must skip /metrics to avoid feedback "
        f"(before={before_values} after={after_values})"
    )


@pytest.mark.asyncio
async def test_exposition_contains_alert_readable_sample(client):
    """After one request, /metrics exposition contains http_requests_total."""
    await client.get("/health/")
    body = generate_latest(REGISTRY).decode("utf-8")
    assert "http_requests_total" in body
    # status_code label must appear (not just "status")
    assert 'status_code="200"' in body or "status_code=\"200\"" in body
