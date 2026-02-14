"""
Prometheus metrics for multi-tenant monitoring.

@spec: multi-tenancy-architecture_spec.md
@covers: tenant_request_total, tenant_cache_hit_ratio
"""

import logging

logger = logging.getLogger(__name__)

# Lazy-initialized Prometheus metrics
_tenant_request_counter = None
_tenant_cache_hit_counter = None
_tenant_cache_miss_counter = None
_tenant_request_duration = None


def _ensure_metrics():
    """Initialize Prometheus metrics (lazy, fail-safe)."""
    global _tenant_request_counter, _tenant_cache_hit_counter
    global _tenant_cache_miss_counter, _tenant_request_duration

    if _tenant_request_counter is not None:
        return True

    try:
        from prometheus_client import Counter, Histogram

        _tenant_request_counter = Counter(
            'tenant_request_total',
            'Total requests per tenant',
            ['tenant_uuid'],
        )

        _tenant_cache_hit_counter = Counter(
            'tenant_cache_hits_total',
            'Cache hits per tenant',
            ['tenant_uuid'],
        )

        _tenant_cache_miss_counter = Counter(
            'tenant_cache_misses_total',
            'Cache misses per tenant',
            ['tenant_uuid'],
        )

        _tenant_request_duration = Histogram(
            'tenant_request_duration_seconds',
            'Request duration per tenant',
            ['tenant_uuid'],
            buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
        )

        return True
    except ImportError:
        logger.debug("prometheus_client not available; tenant metrics disabled")
        return False


def record_tenant_request(tenant_uuid, duration_seconds=None):
    """Record a request for a tenant."""
    if not _ensure_metrics():
        return
    _tenant_request_counter.labels(tenant_uuid=tenant_uuid).inc()
    if duration_seconds is not None and _tenant_request_duration:
        _tenant_request_duration.labels(tenant_uuid=tenant_uuid).observe(duration_seconds)


def record_cache_hit(tenant_uuid):
    """Record a cache hit for a tenant."""
    if not _ensure_metrics():
        return
    _tenant_cache_hit_counter.labels(tenant_uuid=tenant_uuid).inc()


def record_cache_miss(tenant_uuid):
    """Record a cache miss for a tenant."""
    if not _ensure_metrics():
        return
    _tenant_cache_miss_counter.labels(tenant_uuid=tenant_uuid).inc()
