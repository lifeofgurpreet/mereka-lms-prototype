"""Django models for XQueue Graders"""
from django.db import models
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator
import hashlib
import json
import logging

logger = logging.getLogger(__name__)


class GraderSubmission(models.Model):
    """Track code submissions sent to grader workers"""

    # XQueue submission details
    xqueue_header = models.JSONField(help_text="XQueue header (queue_name, submission_id, etc.)")
    xqueue_body = models.JSONField(help_text="XQueue body (student_response, grader_payload, etc.)")

    # Submission identification
    submission_id = models.CharField(max_length=255, unique=True, db_index=True)
    submission_hash = models.CharField(
        max_length=64,
        db_index=True,
        help_text="SHA-256 hash of submission for idempotency check"
    )

    # Student code
    student_response = models.TextField(help_text="Student's code submission")
    grader_payload = models.TextField(blank=True, help_text="Grader configuration/test cases")

    # Grading status
    status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('processing', 'Processing'),
            ('success', 'Success'),
            ('failure', 'Failure'),
            ('timeout', 'Timeout'),
            ('sandbox_error', 'Sandbox Error'),
        ],
        default='pending',
        db_index=True
    )

    # Grading results
    correct = models.BooleanField(null=True, blank=True)
    score = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0.0), MaxValueValidator(100.0)],
        help_text="Score percentage (0.00 to 100.00)"
    )
    feedback = models.TextField(blank=True, help_text="Feedback to student")

    # Execution details
    stdout = models.TextField(blank=True, help_text="Standard output from code execution")
    stderr = models.TextField(blank=True, help_text="Standard error from code execution")
    execution_time_ms = models.IntegerField(null=True, blank=True, help_text="Execution time in milliseconds")
    exit_code = models.IntegerField(null=True, blank=True)

    # Sandbox security
    sandbox_violations = models.JSONField(
        default=list,
        help_text="List of sandbox violations (network access, file writes, etc.)"
    )

    # Timing
    submitted_at = models.DateTimeField(auto_now_add=True, db_index=True)
    started_processing_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    # Worker info
    worker_hostname = models.CharField(max_length=255, blank=True)
    worker_version = models.CharField(max_length=50, blank=True)

    class Meta:
        db_table = 'xqueue_grader_submission'
        verbose_name = 'Grader Submission'
        verbose_name_plural = 'Grader Submissions'
        indexes = [
            models.Index(fields=['submission_hash', 'status']),
            models.Index(fields=['submitted_at', 'status']),
            models.Index(fields=['status', 'submitted_at']),
        ]

    def __str__(self):
        return f"{self.submission_id} - {self.status}"

    @property
    def processing_time_ms(self):
        """Calculate total processing time in milliseconds"""
        if self.completed_at and self.started_processing_at:
            delta = self.completed_at - self.started_processing_at
            return int(delta.total_seconds() * 1000)
        return None

    @staticmethod
    def calculate_hash(student_response, grader_payload=''):
        """Calculate SHA-256 hash of submission for idempotency"""
        content = f"{student_response}|{grader_payload}"
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    @classmethod
    def find_duplicate(cls, submission_hash):
        """Find existing submission with same hash (for idempotency)"""
        return cls.objects.filter(
            submission_hash=submission_hash,
            status='success'
        ).order_by('-completed_at').first()

    def mark_processing(self, worker_hostname):
        """Mark submission as being processed"""
        self.status = 'processing'
        self.started_processing_at = timezone.now()
        self.worker_hostname = worker_hostname
        self.save(update_fields=['status', 'started_processing_at', 'worker_hostname'])
        logger.info(f'Grader submission processing started: {self.submission_id} on {worker_hostname}')

    def mark_success(self, result):
        """Mark submission as successfully graded"""
        self.status = 'success'
        self.correct = result.get('correct', False)
        self.score = result.get('score', 0.0)
        self.feedback = result.get('feedback', '')
        self.stdout = result.get('stdout', '')
        self.stderr = result.get('stderr', '')
        self.execution_time_ms = result.get('execution_time_ms', 0)
        self.exit_code = result.get('exit_code', 0)
        self.completed_at = timezone.now()
        self.save(update_fields=[
            'status', 'correct', 'score', 'feedback', 'stdout', 'stderr',
            'execution_time_ms', 'exit_code', 'completed_at'
        ])
        logger.info(f'Grader submission completed: {self.submission_id} - Score: {self.score}')

    def mark_failure(self, error_message):
        """Mark submission as failed"""
        self.status = 'failure'
        self.feedback = error_message
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'feedback', 'completed_at'])
        logger.error(f'Grader submission failed: {self.submission_id} - {error_message}')

    def mark_timeout(self):
        """Mark submission as timed out"""
        self.status = 'timeout'
        self.feedback = 'Code execution timed out. Please optimize your solution.'
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'feedback', 'completed_at'])
        logger.warning(f'Grader submission timed out: {self.submission_id}')

    def mark_sandbox_error(self, violations):
        """Mark submission with sandbox violations"""
        self.status = 'sandbox_error'
        self.sandbox_violations = violations
        self.feedback = 'Sandbox violation detected: ' + ', '.join(violations)
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'sandbox_violations', 'feedback', 'completed_at'])
        logger.warning(f'Sandbox violation: {self.submission_id} - {violations}')


class GraderQueueMetrics(models.Model):
    """Periodic snapshots of grader queue metrics"""

    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    # Queue depth
    pending_count = models.IntegerField(default=0)
    processing_count = models.IntegerField(default=0)

    # Success/failure rates
    success_count_1h = models.IntegerField(default=0, help_text="Successful gradings in last hour")
    failure_count_1h = models.IntegerField(default=0, help_text="Failed gradings in last hour")
    timeout_count_1h = models.IntegerField(default=0, help_text="Timeouts in last hour")
    sandbox_error_count_1h = models.IntegerField(default=0, help_text="Sandbox errors in last hour")

    # Performance
    avg_processing_time_ms = models.IntegerField(null=True, blank=True)
    p95_processing_time_ms = models.IntegerField(null=True, blank=True)
    p99_processing_time_ms = models.IntegerField(null=True, blank=True)

    # Worker info
    active_workers = models.IntegerField(default=0)

    class Meta:
        db_table = 'xqueue_grader_queue_metrics'
        verbose_name = 'Grader Queue Metrics'
        verbose_name_plural = 'Grader Queue Metrics'
        indexes = [
            models.Index(fields=['-timestamp']),
        ]

    def __str__(self):
        return f"Queue metrics at {self.timestamp} - Pending: {self.pending_count}"

    @classmethod
    def capture_snapshot(cls):
        """Capture current queue metrics snapshot"""
        from django.db.models import Avg, Count, Q
        from datetime import timedelta
        import numpy as np

        now = timezone.now()
        one_hour_ago = now - timedelta(hours=1)

        # Count submissions by status
        pending_count = GraderSubmission.objects.filter(status='pending').count()
        processing_count = GraderSubmission.objects.filter(status='processing').count()

        # Count outcomes in last hour
        recent_submissions = GraderSubmission.objects.filter(completed_at__gte=one_hour_ago)
        success_count = recent_submissions.filter(status='success').count()
        failure_count = recent_submissions.filter(status='failure').count()
        timeout_count = recent_submissions.filter(status='timeout').count()
        sandbox_error_count = recent_submissions.filter(status='sandbox_error').count()

        # Calculate processing time percentiles
        successful_submissions = recent_submissions.filter(status='success', execution_time_ms__isnull=False)
        processing_times = list(successful_submissions.values_list('execution_time_ms', flat=True))

        avg_processing_time = None
        p95_processing_time = None
        p99_processing_time = None

        if processing_times:
            avg_processing_time = int(np.mean(processing_times))
            p95_processing_time = int(np.percentile(processing_times, 95))
            p99_processing_time = int(np.percentile(processing_times, 99))

        # Count active workers (workers that processed submissions in last 5 minutes)
        five_minutes_ago = now - timedelta(minutes=5)
        active_workers = GraderSubmission.objects.filter(
            started_processing_at__gte=five_minutes_ago
        ).values('worker_hostname').distinct().count()

        # Create snapshot
        snapshot = cls.objects.create(
            pending_count=pending_count,
            processing_count=processing_count,
            success_count_1h=success_count,
            failure_count_1h=failure_count,
            timeout_count_1h=timeout_count,
            sandbox_error_count_1h=sandbox_error_count,
            avg_processing_time_ms=avg_processing_time,
            p95_processing_time_ms=p95_processing_time,
            p99_processing_time_ms=p99_processing_time,
            active_workers=active_workers,
        )

        logger.info(
            f'Queue metrics snapshot: Pending={pending_count}, '
            f'Processing={processing_count}, Active workers={active_workers}'
        )

        return snapshot
