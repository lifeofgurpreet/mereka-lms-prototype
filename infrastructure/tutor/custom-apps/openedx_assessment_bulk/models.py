"""
Models for Assessment Bulk Operations

Tracks bulk regrade jobs, grade overrides, exports/imports, IP logging, and audit trails.
"""
import hashlib
import json
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from opaque_keys.edx.django.models import UsageKeyField, CourseKeyField

User = get_user_model()


class BulkRegradeJob(models.Model):
    """
    Track bulk regrade jobs for scale (AC-ASS-029)

    Supports 5000+ students with progress tracking, checkpoint/resume on failure.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]

    job_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique job identifier (UUID)"
    )
    course_key = CourseKeyField(max_length=255, db_index=True)
    usage_key = UsageKeyField(
        max_length=255,
        null=True,
        blank=True,
        help_text="Specific problem to regrade (null = all problems in course)"
    )

    # Job execution
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_regrade_jobs'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        db_index=True
    )

    # Progress tracking (AC-ASS-029: progress updates)
    total_students = models.IntegerField(
        default=0,
        help_text="Total number of students to regrade"
    )
    processed_students = models.IntegerField(
        default=0,
        help_text="Number of students processed so far"
    )
    failed_students = models.IntegerField(
        default=0,
        help_text="Number of students that failed to regrade"
    )

    # Performance metrics (AC-ASS-029: must complete 5000 students in 5 minutes)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    duration_seconds = models.IntegerField(
        null=True,
        blank=True,
        help_text="Total job duration in seconds"
    )

    # Checkpoint/resume (AC-ASS-029: resume on failure)
    checkpoint_data = models.JSONField(
        default=dict,
        help_text="Checkpoint data for resuming failed jobs"
    )
    last_processed_user_id = models.IntegerField(
        null=True,
        blank=True,
        help_text="Last user ID processed (for resume)"
    )

    # Error tracking
    error_message = models.TextField(
        blank=True,
        help_text="Error message if job failed"
    )
    error_details = models.JSONField(
        default=dict,
        help_text="Detailed error information"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['course_key', 'status', '-created_at']),
            models.Index(fields=['status', 'created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"Regrade Job {self.job_id} ({self.status})"

    def calculate_progress_percentage(self):
        """Calculate progress percentage"""
        if self.total_students == 0:
            return 0.0
        return (self.processed_students / self.total_students) * 100

    def calculate_estimated_time_remaining(self):
        """Calculate estimated time remaining in seconds"""
        if not self.started_at or self.processed_students == 0:
            return None

        elapsed = (timezone.now() - self.started_at).total_seconds()
        rate = self.processed_students / elapsed  # students per second
        remaining_students = self.total_students - self.processed_students

        if rate > 0:
            return remaining_students / rate
        return None

    def create_checkpoint(self):
        """
        Create checkpoint for resume (AC-ASS-029)

        Stores current progress and state for resuming after failure.
        """
        self.checkpoint_data = {
            'processed_students': self.processed_students,
            'failed_students': self.failed_students,
            'last_processed_user_id': self.last_processed_user_id,
            'checkpoint_at': timezone.now().isoformat(),
        }
        self.save(update_fields=['checkpoint_data', 'updated_at'])

    def can_resume(self):
        """Check if job can be resumed"""
        return self.status == 'failed' and self.checkpoint_data.get('processed_students', 0) > 0


class GradeOverrideAudit(models.Model):
    """
    Audit trail for staff grade overrides (AC-ASS-030)

    Records: original grade, new grade, staff user, timestamp, reason.
    """
    usage_key = UsageKeyField(max_length=255, db_index=True)
    course_key = CourseKeyField(max_length=255, db_index=True)
    student = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='grade_overrides_received'
    )

    # Override details (AC-ASS-030: track original and new grade)
    original_score = models.FloatField(
        help_text="Original score before override"
    )
    new_score = models.FloatField(
        help_text="New score after override"
    )
    max_score = models.FloatField(
        help_text="Maximum possible score"
    )

    original_grade_percentage = models.FloatField(
        help_text="Original grade as percentage"
    )
    new_grade_percentage = models.FloatField(
        help_text="New grade as percentage"
    )

    # Staff who made the override (AC-ASS-030: staff user)
    overridden_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='grade_overrides_made'
    )

    # Audit details (AC-ASS-030: timestamp, reason)
    reason = models.TextField(
        help_text="Reason for grade override"
    )
    override_type = models.CharField(
        max_length=50,
        choices=[
            ('manual_adjustment', 'Manual Adjustment'),
            ('special_circumstance', 'Special Circumstance'),
            ('grading_error', 'Grading Error Correction'),
            ('resubmission_allowed', 'Resubmission Allowed'),
            ('accessibility_accommodation', 'Accessibility Accommodation'),
        ],
        default='manual_adjustment'
    )

    created_at = models.DateTimeField(auto_now_add=True)  # AC-ASS-030: timestamp

    class Meta:
        indexes = [
            models.Index(fields=['course_key', 'student', '-created_at']),
            models.Index(fields=['usage_key', 'student', '-created_at']),
            models.Index(fields=['overridden_by', '-created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"Override for {self.student.username} by {self.overridden_by.username if self.overridden_by else 'Unknown'}"

    def calculate_change(self):
        """Calculate grade change"""
        return self.new_score - self.original_score

    def calculate_change_percentage(self):
        """Calculate grade change as percentage"""
        return self.new_grade_percentage - self.original_grade_percentage


class ExamSubmissionIPLog(models.Model):
    """
    IP logging for exam submissions (AC-ASS-035)

    Captures student IP for every exam submission for compliance and security.
    """
    usage_key = UsageKeyField(max_length=255, db_index=True)
    course_key = CourseKeyField(max_length=255, db_index=True)
    student = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='exam_ip_logs'
    )

    # IP information (AC-ASS-035: capture IP)
    ip_address = models.GenericIPAddressField(
        help_text="Student's IP address"
    )
    ip_address_hash = models.CharField(
        max_length=64,
        db_index=True,
        help_text="SHA-256 hash of IP for privacy-preserving queries"
    )

    # Additional metadata
    user_agent = models.TextField(
        blank=True,
        help_text="Browser user agent string"
    )
    submission_type = models.CharField(
        max_length=50,
        choices=[
            ('exam_start', 'Exam Start'),
            ('exam_submit', 'Exam Submit'),
            ('question_submit', 'Question Submit'),
            ('proctoring_event', 'Proctoring Event'),
        ],
        default='exam_submit'
    )

    # Geolocation (optional)
    country_code = models.CharField(
        max_length=2,
        blank=True,
        help_text="ISO 3166-1 alpha-2 country code"
    )
    region = models.CharField(
        max_length=100,
        blank=True,
        help_text="Region or state"
    )

    # Anomaly detection
    is_vpn = models.BooleanField(
        default=False,
        help_text="Whether IP is from known VPN provider"
    )
    is_proxy = models.BooleanField(
        default=False,
        help_text="Whether IP is from known proxy"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['course_key', 'student', '-created_at']),
            models.Index(fields=['usage_key', 'student', '-created_at']),
            models.Index(fields=['ip_address_hash', '-created_at']),
            models.Index(fields=['submission_type', '-created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"IP log for {self.student.username} from {self.ip_address}"

    @staticmethod
    def hash_ip(ip_address):
        """Hash IP address for privacy (SHA-256)"""
        return hashlib.sha256(ip_address.encode('utf-8')).hexdigest()

    def save(self, *args, **kwargs):
        """Auto-hash IP on save"""
        if not self.ip_address_hash:
            self.ip_address_hash = self.hash_ip(self.ip_address)
        super().save(*args, **kwargs)


class BulkGradeExport(models.Model):
    """
    Track bulk grade export jobs (AC-ASS-033)

    Produces valid CSV/JSON filtered by section/assignment.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    FORMAT_CHOICES = [
        ('csv', 'CSV'),
        ('json', 'JSON'),
        ('excel', 'Excel (XLSX)'),
    ]

    export_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique export identifier (UUID)"
    )
    course_key = CourseKeyField(max_length=255, db_index=True)

    # Export filters (AC-ASS-033: filter by section/assignment)
    section = models.CharField(
        max_length=255,
        blank=True,
        help_text="Course section to filter (cohort or enrollment track)"
    )
    assignment_type = models.CharField(
        max_length=50,
        blank=True,
        help_text="Assignment type to filter (homework, exam, lab, etc.)"
    )
    usage_keys = models.JSONField(
        default=list,
        help_text="Specific problems to export (empty = all)"
    )

    # Export configuration
    format = models.CharField(
        max_length=10,
        choices=FORMAT_CHOICES,
        default='csv'
    )
    include_metadata = models.BooleanField(
        default=True,
        help_text="Include submission metadata (timestamp, attempts)"
    )

    # Job execution
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_exports'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        db_index=True
    )

    # Results
    file_path = models.CharField(
        max_length=500,
        blank=True,
        help_text="Path to exported file (S3, local storage)"
    )
    file_size_bytes = models.IntegerField(
        null=True,
        blank=True,
        help_text="Size of exported file in bytes"
    )
    total_rows = models.IntegerField(
        null=True,
        blank=True,
        help_text="Number of rows in export"
    )

    # Timing
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    error_message = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['course_key', '-created_at']),
            models.Index(fields=['status', '-created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"Export {self.export_id} ({self.format})"


class BulkGradeImport(models.Model):
    """
    Track bulk grade import jobs (AC-ASS-034)

    Validates CSV, shows preview, applies without duplicating grades.
    """
    STATUS_CHOICES = [
        ('validating', 'Validating'),
        ('preview', 'Preview Ready'),
        ('applying', 'Applying'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]

    import_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique import identifier (UUID)"
    )
    course_key = CourseKeyField(max_length=255, db_index=True)

    # Import source
    uploaded_file_path = models.CharField(
        max_length=500,
        help_text="Path to uploaded CSV file"
    )
    file_size_bytes = models.IntegerField()

    # Validation (AC-ASS-034: validate CSV)
    validation_errors = models.JSONField(
        default=list,
        help_text="List of validation errors found in CSV"
    )
    validation_warnings = models.JSONField(
        default=list,
        help_text="List of validation warnings"
    )
    is_valid = models.BooleanField(
        default=False,
        help_text="Whether CSV passed validation"
    )

    # Preview (AC-ASS-034: show preview)
    preview_data = models.JSONField(
        default=list,
        help_text="Preview of first 10 rows for staff review"
    )
    total_rows = models.IntegerField(
        default=0,
        help_text="Total number of rows to import"
    )

    # Deduplication (AC-ASS-034: no duplicate grades)
    duplicate_detection_enabled = models.BooleanField(
        default=True,
        help_text="Check for existing grades before import"
    )
    duplicates_found = models.IntegerField(
        default=0,
        help_text="Number of duplicate grades detected"
    )
    duplicate_handling = models.CharField(
        max_length=20,
        choices=[
            ('skip', 'Skip Duplicates'),
            ('overwrite', 'Overwrite Existing'),
            ('error', 'Error on Duplicate'),
        ],
        default='skip'
    )

    # Job execution
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_imports'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='validating',
        db_index=True
    )

    # Results
    imported_rows = models.IntegerField(
        default=0,
        help_text="Number of rows successfully imported"
    )
    skipped_rows = models.IntegerField(
        default=0,
        help_text="Number of rows skipped (duplicates, errors)"
    )
    failed_rows = models.IntegerField(
        default=0,
        help_text="Number of rows that failed to import"
    )

    # Timing
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    error_message = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['course_key', '-created_at']),
            models.Index(fields=['status', '-created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"Import {self.import_id} ({self.status})"


class GradeAccessLog(models.Model):
    """
    Track grade access for security auditing (AC-ASS-036)

    Logs every API call that accesses grade data to detect unauthorized access.
    """
    course_key = CourseKeyField(max_length=255, db_index=True)
    accessed_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='grade_accesses_made'
    )

    # Access details
    accessed_student = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='grade_accesses_received',
        help_text="Student whose grades were accessed (null = bulk access)"
    )
    access_type = models.CharField(
        max_length=50,
        choices=[
            ('api_read', 'API Read'),
            ('api_write', 'API Write'),
            ('bulk_export', 'Bulk Export'),
            ('gradebook_view', 'Gradebook View'),
            ('student_view', 'Student View Own Grade'),
        ],
        db_index=True
    )

    # Security (AC-ASS-036: detect unauthorized access)
    is_authorized = models.BooleanField(
        default=True,
        help_text="Whether access was authorized"
    )
    authorization_reason = models.CharField(
        max_length=50,
        choices=[
            ('is_staff', 'User is Staff'),
            ('is_instructor', 'User is Instructor'),
            ('is_ta', 'User is Teaching Assistant'),
            ('is_owner', 'User is Grade Owner'),
            ('unauthorized', 'Unauthorized Access Attempt'),
        ],
        db_index=True
    )

    # Request metadata
    ip_address = models.GenericIPAddressField()
    user_agent = models.TextField(blank=True)
    request_path = models.CharField(max_length=500)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['course_key', 'accessed_by', '-created_at']),
            models.Index(fields=['is_authorized', '-created_at']),
            models.Index(fields=['authorization_reason', '-created_at']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        target = self.accessed_student.username if self.accessed_student else 'bulk'
        return f"{self.accessed_by.username} → {target} ({self.access_type})"
