"""Prometheus metrics for XQueue graders"""
import logging
from prometheus_client import Counter, Histogram, Gauge

logger = logging.getLogger(__name__)

# Grading metrics
xqueue_grading_total = Counter(
    'xqueue_grading_total',
    'Total number of code submissions graded',
    ['status']  # status: success, failure, timeout, sandbox_error
)

xqueue_grading_duration_seconds = Histogram(
    'xqueue_grading_duration_seconds',
    'Time taken to grade code submission',
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0)
)

xqueue_code_execution_time_ms = Histogram(
    'xqueue_code_execution_time_ms',
    'Student code execution time in milliseconds',
    buckets=(10, 50, 100, 250, 500, 1000, 2500, 5000)
)

# Queue metrics
xqueue_queue_depth = Gauge(
    'xqueue_queue_depth',
    'Number of submissions waiting to be graded',
    ['status']  # status: pending, processing
)

xqueue_active_workers = Gauge(
    'xqueue_active_workers',
    'Number of active grader workers'
)

# Sandbox metrics
xqueue_sandbox_violations_total = Counter(
    'xqueue_sandbox_violations_total',
    'Total number of sandbox violations',
    ['violation_type']  # violation_type: network_access, filesystem_write, cpu_limit, memory_limit
)

# Performance metrics
xqueue_grading_score_distribution = Histogram(
    'xqueue_grading_score_distribution',
    'Distribution of grading scores',
    buckets=(0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
)

# Idempotency metrics
xqueue_cached_results_total = Counter(
    'xqueue_cached_results_total',
    'Total number of cached/duplicate submissions'
)


def update_queue_metrics():
    """Update queue depth metrics from database"""
    try:
        from .models import GraderSubmission

        pending_count = GraderSubmission.objects.filter(status='pending').count()
        processing_count = GraderSubmission.objects.filter(status='processing').count()

        xqueue_queue_depth.labels(status='pending').set(pending_count)
        xqueue_queue_depth.labels(status='processing').set(processing_count)

        logger.debug(f'Queue metrics updated: pending={pending_count}, processing={processing_count}')

    except Exception as e:
        logger.error(f'Failed to update queue metrics: {e}', exc_info=True)


def update_worker_count():
    """Update active worker count from database"""
    try:
        from .models import GraderSubmission
        from django.utils import timezone
        from datetime import timedelta

        # Count workers that processed submissions in last 5 minutes
        five_minutes_ago = timezone.now() - timedelta(minutes=5)
        active_workers = GraderSubmission.objects.filter(
            started_processing_at__gte=five_minutes_ago
        ).values('worker_hostname').distinct().count()

        xqueue_active_workers.set(active_workers)

        logger.debug(f'Active workers: {active_workers}')

    except Exception as e:
        logger.error(f'Failed to update worker count: {e}', exc_info=True)
