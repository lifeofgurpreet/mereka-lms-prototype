"""Django models for ORA2 operations tracking"""
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from opaque_keys.edx.django.models import CourseKeyField
import logging

User = get_user_model()
logger = logging.getLogger(__name__)


class ORA2FallbackTracking(models.Model):
    """Track peer-to-staff grading fallbacks"""

    submission_uuid = models.CharField(max_length=128, unique=True, db_index=True)
    course_id = CourseKeyField(max_length=255, db_index=True)
    student_id = models.CharField(max_length=255, db_index=True)
    item_id = models.CharField(max_length=255)

    # Fallback details
    fallback_reason = models.CharField(
        max_length=50,
        choices=[
            ('timeout', 'Peer Grading Timeout'),
            ('insufficient_peers', 'Insufficient Peer Graders'),
            ('manual', 'Manual Override'),
        ],
        default='timeout'
    )
    fallback_triggered_at = models.DateTimeField(auto_now_add=True)
    staff_assigned_at = models.DateTimeField(null=True, blank=True)
    staff_graded_at = models.DateTimeField(null=True, blank=True)

    # Peer assessment tracking
    peer_grading_started_at = models.DateTimeField()
    peer_grading_deadline = models.DateTimeField()
    peers_required = models.IntegerField(default=3)
    peers_completed = models.IntegerField(default=0)

    # Status
    status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending Staff Review'),
            ('assigned', 'Assigned to Staff'),
            ('completed', 'Staff Grading Completed'),
            ('cancelled', 'Cancelled'),
        ],
        default='pending',
        db_index=True
    )

    class Meta:
        db_table = 'ora2_fallback_tracking'
        verbose_name = 'ORA2 Fallback Tracking'
        verbose_name_plural = 'ORA2 Fallback Trackings'
        indexes = [
            models.Index(fields=['course_id', 'status']),
            models.Index(fields=['fallback_triggered_at']),
        ]

    def __str__(self):
        return f'Fallback: {self.submission_uuid} ({self.fallback_reason})'

    def mark_staff_assigned(self):
        """Mark fallback submission as assigned to staff"""
        self.staff_assigned_at = timezone.now()
        self.status = 'assigned'
        self.save(update_fields=['staff_assigned_at', 'status'])
        logger.info(f'ORA2 fallback assigned to staff: {self.submission_uuid}')

    def mark_staff_completed(self):
        """Mark staff grading as completed"""
        self.staff_graded_at = timezone.now()
        self.status = 'completed'
        self.save(update_fields=['staff_graded_at', 'status'])
        logger.info(f'ORA2 fallback completed: {self.submission_uuid}')

    @classmethod
    def trigger_fallback(cls, submission_uuid, course_id, student_id, item_id, reason='timeout', **kwargs):
        """Create a fallback tracking record"""
        fallback, created = cls.objects.get_or_create(
            submission_uuid=submission_uuid,
            defaults={
                'course_id': course_id,
                'student_id': student_id,
                'item_id': item_id,
                'fallback_reason': reason,
                'peer_grading_started_at': kwargs.get('peer_grading_started_at', timezone.now()),
                'peer_grading_deadline': kwargs.get('peer_grading_deadline', timezone.now()),
                'peers_required': kwargs.get('peers_required', 3),
                'peers_completed': kwargs.get('peers_completed', 0),
            }
        )

        if created:
            logger.info(f'ORA2 fallback triggered: {submission_uuid}, reason={reason}')

        return fallback


class ORA2OperationalMetrics(models.Model):
    """Aggregate operational metrics for ORA2 (daily snapshots)"""

    course_id = CourseKeyField(max_length=255, db_index=True)
    date = models.DateField(db_index=True)

    # Submission metrics
    total_submissions = models.IntegerField(default=0)
    submissions_with_files = models.IntegerField(default=0)
    total_file_uploads = models.IntegerField(default=0)
    total_file_size_bytes = models.BigIntegerField(default=0)

    # Peer assessment metrics
    total_peer_assessments = models.IntegerField(default=0)
    avg_peer_assessment_time_seconds = models.FloatField(null=True, blank=True)

    # Staff grading metrics
    total_staff_assessments = models.IntegerField(default=0)
    avg_staff_assessment_time_seconds = models.FloatField(null=True, blank=True)
    staff_grading_queue_size = models.IntegerField(default=0)

    # Grade propagation
    total_grades_propagated = models.IntegerField(default=0)
    failed_grade_propagations = models.IntegerField(default=0)

    # Fallback metrics
    total_fallbacks = models.IntegerField(default=0)
    fallback_due_to_timeout = models.IntegerField(default=0)
    fallback_due_to_insufficient_peers = models.IntegerField(default=0)

    # Storage metrics (snapshot)
    storage_used_bytes = models.BigIntegerField(default=0)
    storage_total_bytes = models.BigIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ora2_operational_metrics'
        verbose_name = 'ORA2 Operational Metrics'
        verbose_name_plural = 'ORA2 Operational Metrics'
        unique_together = [['course_id', 'date']]
        indexes = [
            models.Index(fields=['date', 'course_id']),
        ]

    def __str__(self):
        return f'ORA2 Metrics: {self.course_id} ({self.date})'

    @property
    def storage_usage_percent(self):
        """Calculate storage usage percentage"""
        if self.storage_total_bytes > 0:
            return (self.storage_used_bytes / self.storage_total_bytes) * 100
        return 0.0


class ORA2FileUpload(models.Model):
    """Track individual file uploads for audit and cleanup"""

    submission_uuid = models.CharField(max_length=128, db_index=True)
    course_id = CourseKeyField(max_length=255, db_index=True)
    student_id = models.CharField(max_length=255)

    file_key = models.CharField(max_length=512, unique=True)
    file_name = models.CharField(max_length=255)
    file_type = models.CharField(max_length=50)
    file_size_bytes = models.BigIntegerField()

    uploaded_at = models.DateTimeField(auto_now_add=True)
    file_path = models.CharField(max_length=1024, blank=True)

    # Status for cleanup
    status = models.CharField(
        max_length=20,
        choices=[
            ('active', 'Active'),
            ('archived', 'Archived'),
            ('deleted', 'Deleted'),
        ],
        default='active',
        db_index=True
    )

    class Meta:
        db_table = 'ora2_file_uploads'
        verbose_name = 'ORA2 File Upload'
        verbose_name_plural = 'ORA2 File Uploads'
        indexes = [
            models.Index(fields=['course_id', 'uploaded_at']),
            models.Index(fields=['status', 'uploaded_at']),
        ]

    def __str__(self):
        return f'{self.file_name} ({self.file_type}, {self.file_size_bytes} bytes)'

    @classmethod
    def track_upload(cls, submission_uuid, course_id, student_id, file_key, file_name, file_size, file_path=''):
        """Track a file upload"""
        file_type = file_name.split('.')[-1].lower() if '.' in file_name else 'unknown'

        upload, created = cls.objects.get_or_create(
            file_key=file_key,
            defaults={
                'submission_uuid': submission_uuid,
                'course_id': course_id,
                'student_id': student_id,
                'file_name': file_name,
                'file_type': file_type,
                'file_size_bytes': file_size,
                'file_path': file_path,
            }
        )

        if created:
            logger.info(f'ORA2 file upload tracked: {file_name} ({file_size} bytes)')

        return upload
