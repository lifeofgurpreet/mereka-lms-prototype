"""Durable fulfillment outbox with retry and reconciliation."""

import asyncio
from datetime import UTC, datetime, timedelta

import structlog
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.database import async_session
from app.models.fulfillment_job import FulfillmentJob, FulfillmentJobStatus
from app.models.order import Order, OrderAuditLog, OrderStatus
from app.services.fulfillment import fulfill_order

logger = structlog.get_logger()

RECONCILEABLE_ORDER_STATUSES = (
    OrderStatus.paid,
    OrderStatus.fulfilling,
    OrderStatus.partially_fulfilled,
    OrderStatus.fulfillment_failed,
)


async def enqueue_fulfillment_job(
    db: AsyncSession,
    *,
    order: Order,
    triggered_by: str,
    force: bool = False,
) -> FulfillmentJob:
    """Create or requeue a fulfillment job for an order (idempotent)."""
    result = await db.execute(
        select(FulfillmentJob).where(FulfillmentJob.order_id == order.id)
    )
    job = result.scalar_one_or_none()
    now = datetime.now(UTC)

    if job is None:
        job = FulfillmentJob(
            order_id=order.id,
            tenant_id=order.tenant_id,
            status=FulfillmentJobStatus.pending,
            attempts=0,
            max_attempts=settings.FULFILLMENT_MAX_RETRIES,
            next_attempt_at=now,
            triggered_by=triggered_by,
        )
        db.add(job)
        return job

    if job.status == FulfillmentJobStatus.succeeded and not force:
        return job

    job.status = FulfillmentJobStatus.pending
    job.next_attempt_at = now
    job.completed_at = None
    job.last_error = None
    job.triggered_by = triggered_by
    if force:
        job.attempts = 0
    return job


def _next_retry_delay(attempts: int) -> int:
    base = max(1, settings.FULFILLMENT_BASE_DELAY_SECONDS)
    # Cap backoff at 1 hour to prevent unbounded delay growth.
    return min(3600, base * (2 ** max(0, attempts - 1)))


async def _mark_dead_letter(db: AsyncSession, job: FulfillmentJob, reason: str) -> None:
    now = datetime.now(UTC)
    job.status = FulfillmentJobStatus.dead_letter
    job.completed_at = now
    job.last_error = reason[:2048]
    if job.order:
        db.add(
            OrderAuditLog(
                order_id=job.order.id,
                old_status=job.order.status.value,
                new_status=job.order.status.value,
                triggered_by="fulfillment.outbox.dead_letter",
                details={
                    "job_id": str(job.id),
                    "attempts": job.attempts,
                    "max_attempts": job.max_attempts,
                    "reason": reason[:512],
                },
            )
        )
    await db.commit()


async def _mark_retry(
    db: AsyncSession,
    job: FulfillmentJob,
    reason: str,
) -> None:
    delay_seconds = _next_retry_delay(job.attempts)
    job.status = FulfillmentJobStatus.failed
    job.next_attempt_at = datetime.now(UTC) + timedelta(seconds=delay_seconds)
    job.last_error = reason[:2048]
    await db.commit()


async def claim_next_fulfillment_job(db: AsyncSession) -> FulfillmentJob | None:
    """Claim the next runnable fulfillment job with row locking."""
    now = datetime.now(UTC)
    stmt: Select[tuple[FulfillmentJob]] = (
        select(FulfillmentJob)
        .where(
            FulfillmentJob.status.in_(
                [FulfillmentJobStatus.pending, FulfillmentJobStatus.failed]
            ),
            FulfillmentJob.next_attempt_at <= now,
            FulfillmentJob.attempts < FulfillmentJob.max_attempts,
        )
        .order_by(FulfillmentJob.next_attempt_at.asc(), FulfillmentJob.created_at.asc())
        .with_for_update(skip_locked=True)
        .limit(1)
    )
    result = await db.execute(stmt)
    job = result.scalar_one_or_none()
    if job is None:
        return None

    job.status = FulfillmentJobStatus.processing
    job.last_attempt_at = now
    job.attempts += 1
    await db.commit()
    await db.refresh(job)
    return job


async def process_fulfillment_job(job_id) -> None:
    """Process one claimed fulfillment job and persist final state."""
    async with async_session() as db:
        result = await db.execute(
            select(FulfillmentJob)
            .where(FulfillmentJob.id == job_id)
            .options(selectinload(FulfillmentJob.order).selectinload(Order.line_items))
        )
        job = result.scalar_one_or_none()
        if not job:
            logger.warning("fulfillment.job_missing", job_id=str(job_id))
            return

        if job.status != FulfillmentJobStatus.processing:
            logger.info(
                "fulfillment.job_not_processing",
                job_id=str(job.id),
                status=job.status.value,
            )
            return

        if not job.order:
            await _mark_dead_letter(db, job, "Associated order was not found")
            return

        try:
            await fulfill_order(job.order, db)
            await db.refresh(job.order)
        except Exception as exc:  # pragma: no cover - defensive path
            logger.error(
                "fulfillment.job_execution_error",
                job_id=str(job.id),
                order_id=str(job.order_id),
                error=str(exc),
            )
            if job.attempts >= job.max_attempts:
                await _mark_dead_letter(db, job, f"Unhandled error: {exc}")
            else:
                await _mark_retry(db, job, f"Unhandled error: {exc}")
            return

        if job.order.status == OrderStatus.fulfilled:
            job.status = FulfillmentJobStatus.succeeded
            job.completed_at = datetime.now(UTC)
            job.last_error = None
            await db.commit()
            logger.info(
                "fulfillment.job_succeeded",
                job_id=str(job.id),
                order_id=str(job.order_id),
            )
            return

        reason = f"Order status after fulfillment is {job.order.status.value}"
        if job.attempts >= job.max_attempts:
            await _mark_dead_letter(db, job, reason)
        else:
            await _mark_retry(db, job, reason)


async def reconcile_paid_orders(db: AsyncSession, *, limit: int) -> int:
    """Ensure every paid/unfulfilled order has a pending fulfillment job."""
    result = await db.execute(
        select(Order)
        .where(Order.status.in_(RECONCILEABLE_ORDER_STATUSES))
        .order_by(Order.created_at.asc())
        .limit(limit)
    )
    orders = result.scalars().all()

    reconciled = 0
    for order in orders:
        job = await enqueue_fulfillment_job(
            db,
            order=order,
            triggered_by="fulfillment.reconciliation",
            force=False,
        )
        if job.status in {FulfillmentJobStatus.pending, FulfillmentJobStatus.failed}:
            reconciled += 1

    if reconciled:
        await db.commit()
        logger.info(
            "fulfillment.reconcile_queued",
            reconciled=reconciled,
            scanned=len(orders),
        )
    return reconciled


async def run_fulfillment_worker(stop_event: asyncio.Event) -> None:
    """Run fulfillment worker loop until shutdown."""
    logger.info("fulfillment.worker_started")
    next_reconcile_at = datetime.now(UTC)

    while not stop_event.is_set():
        try:
            if settings.ENABLE_RECONCILIATION_JOB and datetime.now(UTC) >= next_reconcile_at:
                async with async_session() as db:
                    await reconcile_paid_orders(
                        db,
                        limit=settings.FULFILLMENT_RECONCILE_BATCH_SIZE,
                    )
                next_reconcile_at = datetime.now(UTC) + timedelta(
                    seconds=settings.FULFILLMENT_RECONCILE_INTERVAL_SECONDS
                )

            async with async_session() as db:
                job = await claim_next_fulfillment_job(db)

            if job:
                await process_fulfillment_job(job.id)
                continue

            try:
                await asyncio.wait_for(
                    stop_event.wait(),
                    timeout=max(1, settings.FULFILLMENT_WORKER_POLL_SECONDS),
                )
            except TimeoutError:
                continue
        except Exception as exc:  # pragma: no cover - defensive guard
            logger.error("fulfillment.worker_loop_error", error=str(exc))
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=1)
            except TimeoutError:
                pass

    logger.info("fulfillment.worker_stopped")
