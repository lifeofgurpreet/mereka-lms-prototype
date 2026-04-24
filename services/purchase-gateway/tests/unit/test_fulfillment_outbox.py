"""Unit tests for durable fulfillment outbox queue and reconciliation."""

import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.fulfillment_job import FulfillmentJob, FulfillmentJobStatus
from app.models.order import Order, OrderStatus
from app.services.fulfillment_outbox import (
    claim_next_fulfillment_job,
    enqueue_fulfillment_job,
    reconcile_paid_orders,
)


def _mock_select_result(obj):
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


def _mock_scalars_result(values):
    scalars = MagicMock()
    scalars.all.return_value = values
    result = MagicMock()
    result.scalars.return_value = scalars
    return result


def _make_order(status: OrderStatus = OrderStatus.paid) -> Order:
    return Order(
        id=uuid.uuid4(),
        tenant_id=uuid.UUID(int=1),
        buyer_email="buyer@example.com",
        stripe_checkout_session_id=f"cs_{uuid.uuid4().hex[:8]}",
        status=status,
        total_cents=5000,
        currency="USD",
        line_items=[],
    )


@pytest.fixture
def mock_db():
    db = AsyncMock(spec=AsyncSession)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = MagicMock()
    return db


@pytest.mark.asyncio
async def test_enqueue_fulfillment_job_creates_new_job(mock_db):
    order = _make_order()
    mock_db.execute.return_value = _mock_select_result(None)

    job = await enqueue_fulfillment_job(
        mock_db,
        order=order,
        triggered_by="stripe.checkout.session.completed",
    )

    assert job.order_id == order.id
    assert job.tenant_id == order.tenant_id
    assert job.status == FulfillmentJobStatus.pending
    assert job.triggered_by == "stripe.checkout.session.completed"
    mock_db.add.assert_called_once_with(job)


@pytest.mark.asyncio
async def test_enqueue_fulfillment_job_requeues_existing_job(mock_db):
    order = _make_order()
    existing = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=order.id,
        tenant_id=order.tenant_id,
        status=FulfillmentJobStatus.failed,
        attempts=3,
        max_attempts=10,
        next_attempt_at=datetime.now(UTC) + timedelta(minutes=5),
        triggered_by="old-trigger",
        last_error="old error",
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    job = await enqueue_fulfillment_job(
        mock_db,
        order=order,
        triggered_by="manual.requeue",
    )

    assert job.id == existing.id
    assert job.status == FulfillmentJobStatus.pending
    assert job.triggered_by == "manual.requeue"
    assert job.last_error is None
    mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_enqueue_fulfillment_job_keeps_active_processing_job(mock_db):
    order = _make_order()
    original_next_attempt = datetime.now(UTC) + timedelta(minutes=5)
    existing = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=order.id,
        tenant_id=order.tenant_id,
        status=FulfillmentJobStatus.processing,
        attempts=2,
        max_attempts=10,
        next_attempt_at=original_next_attempt,
        last_attempt_at=datetime.now(UTC) - timedelta(minutes=2),
        triggered_by="worker.loop",
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    job = await enqueue_fulfillment_job(
        mock_db,
        order=order,
        triggered_by="stripe.checkout.session.completed",
    )

    assert job.id == existing.id
    assert job.status == FulfillmentJobStatus.processing
    assert job.attempts == 2
    assert job.next_attempt_at == original_next_attempt
    assert job.triggered_by == "worker.loop"
    mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_enqueue_fulfillment_job_requeues_stale_processing_job(mock_db):
    order = _make_order()
    existing = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=order.id,
        tenant_id=order.tenant_id,
        status=FulfillmentJobStatus.processing,
        attempts=3,
        max_attempts=10,
        next_attempt_at=datetime.now(UTC) + timedelta(minutes=5),
        last_attempt_at=datetime.now(UTC) - timedelta(hours=2),
        triggered_by="worker.loop",
        last_error="old error",
    )
    mock_db.execute.return_value = _mock_select_result(existing)

    job = await enqueue_fulfillment_job(
        mock_db,
        order=order,
        triggered_by="manual.requeue",
    )

    assert job.id == existing.id
    assert job.status == FulfillmentJobStatus.pending
    assert job.attempts == 3
    assert job.triggered_by == "manual.requeue"
    assert job.last_error is None
    mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_claim_next_fulfillment_job_marks_processing(mock_db):
    order = _make_order()
    job = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=order.id,
        tenant_id=order.tenant_id,
        status=FulfillmentJobStatus.pending,
        attempts=0,
        max_attempts=10,
        next_attempt_at=datetime.now(UTC) - timedelta(seconds=1),
        triggered_by="reconcile",
    )
    mock_db.execute.return_value = _mock_select_result(job)

    claimed = await claim_next_fulfillment_job(mock_db)

    assert claimed is job
    assert job.status == FulfillmentJobStatus.processing
    assert job.attempts == 1
    mock_db.commit.assert_awaited_once()
    mock_db.refresh.assert_awaited_once_with(job)


@pytest.mark.asyncio
async def test_claim_next_fulfillment_job_reclaims_stale_processing_job(mock_db):
    order = _make_order()
    job = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=order.id,
        tenant_id=order.tenant_id,
        status=FulfillmentJobStatus.processing,
        attempts=1,
        max_attempts=10,
        next_attempt_at=datetime.now(UTC) + timedelta(hours=1),
        last_attempt_at=datetime.now(UTC) - timedelta(hours=1),
        triggered_by="worker.loop",
    )
    mock_db.execute.return_value = _mock_select_result(job)

    claimed = await claim_next_fulfillment_job(mock_db)

    assert claimed is job
    assert job.status == FulfillmentJobStatus.processing
    assert job.attempts == 2
    mock_db.commit.assert_awaited_once()
    mock_db.refresh.assert_awaited_once_with(job)


@pytest.mark.asyncio
async def test_claim_next_fulfillment_job_query_includes_stale_processing_clause(mock_db):
    mock_db.execute.return_value = _mock_select_result(None)

    claimed = await claim_next_fulfillment_job(mock_db)

    assert claimed is None
    stmt = mock_db.execute.call_args.args[0]
    sql = str(stmt)
    assert "fulfillment_jobs.status = " in sql
    assert "fulfillment_jobs.last_attempt_at <=" in sql
    assert "fulfillment_jobs.last_attempt_at IS NOT NULL" in sql
    mock_db.commit.assert_not_called()
    mock_db.refresh.assert_not_called()


@pytest.mark.asyncio
@patch("app.services.fulfillment_outbox.record_reconciliation_queued")
async def test_reconcile_paid_orders_enqueues_jobs_and_commits(
    mock_record_reconciliation_queued,
    mock_db,
):
    orders = [
        _make_order(OrderStatus.paid),
        _make_order(OrderStatus.fulfillment_failed),
    ]
    mock_db.execute.return_value = _mock_scalars_result(orders)

    pending_job = FulfillmentJob(
        id=uuid.uuid4(),
        order_id=orders[0].id,
        tenant_id=orders[0].tenant_id,
        status=FulfillmentJobStatus.pending,
        attempts=0,
        max_attempts=10,
        next_attempt_at=datetime.now(UTC),
        triggered_by="fulfillment.reconciliation",
    )

    with patch(
        "app.services.fulfillment_outbox.enqueue_fulfillment_job",
        new_callable=AsyncMock,
        side_effect=[pending_job, pending_job],
    ) as mock_enqueue:
        reconciled = await reconcile_paid_orders(mock_db, limit=100)

    assert reconciled == 2
    assert mock_enqueue.await_count == 2
    mock_db.commit.assert_awaited_once()
    mock_record_reconciliation_queued.assert_called_once_with(2)
