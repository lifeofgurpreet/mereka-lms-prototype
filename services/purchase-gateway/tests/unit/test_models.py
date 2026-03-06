import uuid
from datetime import UTC, datetime

from app.models.fulfillment_job import FulfillmentJobStatus
from app.models.order import FulfillmentStatus, LineItem, Order, OrderAuditLog, OrderStatus


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


def test_fulfillment_job_status_values():
    """Verify outbox job status enum covers retry + terminal states."""
    expected = {"pending", "processing", "succeeded", "failed", "dead_letter"}
    assert {s.value for s in FulfillmentJobStatus} == expected


# ---------------------------------------------------------------------------
# Order model — field defaults and valid state transitions
# ---------------------------------------------------------------------------


def test_order_explicit_pending_status():
    """Order status can be set to pending at creation."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        total_cents=5000,
        currency="USD",
        status=OrderStatus.pending,
    )
    assert order.status == OrderStatus.pending


def test_order_explicit_currency():
    """Order currency field is stored as-set."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        total_cents=5000,
        currency="USD",
    )
    assert order.currency == "USD"


def test_order_status_transition_pending_to_paid():
    """Order can transition from pending to paid."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        total_cents=5000,
        status=OrderStatus.pending,
    )
    order.status = OrderStatus.paid
    assert order.status == OrderStatus.paid


def test_order_status_transition_paid_to_fulfilled():
    """Order can transition from paid to fulfilled."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        total_cents=5000,
        status=OrderStatus.paid,
    )
    order.status = OrderStatus.fulfilled
    order.fulfilled_at = datetime.now(UTC)
    assert order.status == OrderStatus.fulfilled
    assert order.fulfilled_at is not None


def test_order_status_transition_fulfilled_to_refunded():
    """Order can transition from fulfilled to refunded."""
    order = Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id="cs_test",
        total_cents=5000,
        status=OrderStatus.fulfilled,
    )
    order.status = OrderStatus.refunded
    order.refunded_at = datetime.now(UTC)
    assert order.status == OrderStatus.refunded
    assert order.refunded_at is not None


# ---------------------------------------------------------------------------
# LineItem model
# ---------------------------------------------------------------------------


def test_line_item_explicit_pending_fulfillment_status():
    """LineItem.fulfillment_status can be set to pending."""
    item = LineItem(
        id=uuid.uuid4(),
        order_id=uuid.uuid4(),
        offering_uuid=uuid.UUID(int=10),
        offering_type="course_seat",
        lms_resource_id="course-v1:Test+101+2024",
        quantity=1,
        unit_price_cents=5000,
        total_price_cents=5000,
        fulfillment_status=FulfillmentStatus.pending,
    )
    assert item.fulfillment_status == FulfillmentStatus.pending


def test_line_item_total_price_is_quantity_times_unit_price():
    """LineItem total_price_cents should equal quantity * unit_price_cents."""
    item = LineItem(
        id=uuid.uuid4(),
        order_id=uuid.uuid4(),
        offering_uuid=uuid.UUID(int=10),
        offering_type="course_seat",
        lms_resource_id="course-v1:Test+101+2024",
        quantity=3,
        unit_price_cents=5000,
        total_price_cents=15000,
    )
    assert item.total_price_cents == item.quantity * item.unit_price_cents


# ---------------------------------------------------------------------------
# OrderAuditLog model
# ---------------------------------------------------------------------------


def test_order_audit_log_captures_status_transition():
    """OrderAuditLog records old/new status and trigger source."""
    audit = OrderAuditLog(
        id=uuid.uuid4(),
        order_id=uuid.uuid4(),
        old_status=OrderStatus.pending.value,
        new_status=OrderStatus.paid.value,
        triggered_by="stripe.checkout.session.completed",
    )
    assert audit.old_status == "pending"
    assert audit.new_status == "paid"
    assert audit.triggered_by == "stripe.checkout.session.completed"
