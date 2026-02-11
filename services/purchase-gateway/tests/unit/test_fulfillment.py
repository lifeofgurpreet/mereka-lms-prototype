import uuid
from datetime import datetime, timezone

import pytest

from app.models.order import FulfillmentStatus, OrderStatus


def test_order_status_values():
    """Verify all expected order statuses exist."""
    expected = {
        "pending", "paid", "fulfilling", "fulfilled",
        "partially_fulfilled", "fulfillment_failed",
        "refunded", "partially_refunded", "disputed",
        "expired", "canceled",
    }
    assert {s.value for s in OrderStatus} == expected


def test_fulfillment_status_values():
    """Verify all expected fulfillment statuses exist."""
    expected = {"pending", "fulfilled", "failed", "revoked"}
    assert {s.value for s in FulfillmentStatus} == expected
