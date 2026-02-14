"""
Per-tenant rate limiter using token bucket algorithm.

@spec: email-notifications-pipeline_spec.md
@covers: AC-030

Rate limit: 50 emails/sec per tenant to prevent abuse and
ensure fair resource allocation across organizations.
"""

import logging
import threading
import time

logger = logging.getLogger(__name__)

# Default rate: 50 emails/sec per tenant
DEFAULT_RATE = 50
DEFAULT_CAPACITY = 50

# Thread-safe storage for per-tenant buckets
_tenant_buckets = {}
_lock = threading.Lock()


class TokenBucket:
    """
    Token bucket rate limiter.

    Allows bursts up to `capacity` tokens, refills at `rate` tokens/sec.
    """

    def __init__(self, rate=DEFAULT_RATE, capacity=DEFAULT_CAPACITY):
        self.rate = rate
        self.capacity = capacity
        self.tokens = float(capacity)
        self.last_refill = time.monotonic()
        self._lock = threading.Lock()

    def _refill(self):
        """Refill tokens based on elapsed time."""
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
        self.last_refill = now

    def consume(self, count=1):
        """
        Try to consume `count` tokens.

        Returns True if tokens were available, False if rate limited.
        """
        with self._lock:
            self._refill()
            if self.tokens >= count:
                self.tokens -= count
                return True
            return False

    def wait_and_consume(self, count=1, max_wait=5.0):
        """
        Wait for tokens to become available, then consume.

        Returns True if consumed within max_wait, False if timed out.
        """
        deadline = time.monotonic() + max_wait
        while time.monotonic() < deadline:
            if self.consume(count):
                return True
            # Sleep for estimated refill time
            wait = min(count / self.rate, deadline - time.monotonic())
            if wait > 0:
                time.sleep(wait)
        return False


def get_tenant_bucket(org_slug):
    """
    Get or create a token bucket for a tenant.

    Thread-safe: uses a global lock for bucket creation.
    """
    with _lock:
        if org_slug not in _tenant_buckets:
            _tenant_buckets[org_slug] = TokenBucket(
                rate=DEFAULT_RATE,
                capacity=DEFAULT_CAPACITY,
            )
            logger.debug("Created rate limiter for tenant %s", org_slug)
        return _tenant_buckets[org_slug]


def check_rate_limit(org_slug, count=1):
    """
    Check if sending `count` emails for a tenant is within rate limits.

    Returns True if allowed, False if rate limited.
    """
    bucket = get_tenant_bucket(org_slug)
    return bucket.consume(count)


def wait_for_rate_limit(org_slug, count=1, max_wait=5.0):
    """
    Wait until rate limit allows sending, then consume tokens.

    Returns True if allowed within max_wait, False if timed out.
    """
    bucket = get_tenant_bucket(org_slug)
    return bucket.wait_and_consume(count, max_wait)
