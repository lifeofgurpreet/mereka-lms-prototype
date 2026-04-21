"""HTTP-request counting middleware.

Emits `http_requests_total{method, handler, status_code}` and
`http_request_duration_seconds` on every non-/metrics request. Consumed by
the PurchaseGatewayHighErrorRate alert in
deploy/k8s/base/monitoring/prometheusrule-services.yaml.

Bead: mereka-lms-zuv1 (see audit mereka-lms-33d8 for origin).
"""

from __future__ import annotations

import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.metrics import HTTP_REQUEST_DURATION_SECONDS, HTTP_REQUESTS_TOTAL


class PrometheusHTTPMetricsMiddleware(BaseHTTPMiddleware):
    """Count + time every HTTP request that reaches the FastAPI router.

    `handler` is the route template (e.g. `/api/v1/checkout/{id}`) when
    available, or the raw path when the request did not match a route (404s).
    This keeps cardinality bounded even under scanner traffic.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next) -> Response:
        # Skip self-metric requests to avoid feedback loops in the counter.
        if request.url.path == "/metrics":
            return await call_next(request)

        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        except Exception:
            # Re-raise after recording — the FastAPI exception handler still runs.
            raise
        finally:
            handler = _resolve_handler(request)
            method = request.method
            labels = (method, handler, str(status_code))
            HTTP_REQUESTS_TOTAL.labels(*labels).inc()
            HTTP_REQUEST_DURATION_SECONDS.labels(*labels).observe(
                max(0.0, time.perf_counter() - started)
            )


def _resolve_handler(request: Request) -> str:
    """Return route template if matched, else raw path (trimmed for safety)."""
    route = request.scope.get("route")
    if route is not None:
        path_template = getattr(route, "path", None)
        if path_template:
            return path_template
    # Fallback: raw path, truncated to protect against high-cardinality labels
    # from malformed URLs or directory-scanner probes.
    raw = request.url.path or "/"
    return raw[:120]
