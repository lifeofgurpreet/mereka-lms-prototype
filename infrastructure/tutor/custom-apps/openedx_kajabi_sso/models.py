"""
Data models for Kajabi SSO integration.

@spec: kajabi-sso
@covers: AC-SSO-001, AC-SSO-002, AC-SSO-004, AC-SSO-005
"""

import uuid
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class KajabiSsoLink(models.Model):
    """
    Links an Open edX user account to their Kajabi SSO credentials.

    Each link represents a Kajabi user who has been migrated to the LMS.
    The link tracks SSO authentication attempts and manages the welcome email flow.

    @covers AC-SSO-001, AC-SSO-004, AC-SSO-005
    """

    # Primary key (UUID for distributed systems)
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # User association (one-to-one: each user can have only one Kajabi SSO link)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='kajabi_sso_link',
        db_index=True,
        help_text="Open edX user account linked to Kajabi SSO"
    )

    # Kajabi identity information
    kajabi_email = models.EmailField(
        max_length=254,
        db_index=True,
        help_text="Original Kajabi email (stored for reference and deduplication)"
    )

    kajabi_user_id = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_index=True,
        help_text="External Kajabi user ID (if available from migration CSV)"
    )

    # SSO configuration
    sso_provider = models.CharField(
        max_length=100,
        default='mereka-kajabi-sso',
        help_text="OAuth2 client slug for this SSO provider"
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
        help_text="Whether SSO is active for this user (can be disabled without deleting link)"
    )

    # Migration and welcome email tracking (AC-SSO-005)
    migrated_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the Kajabi user was migrated to LMS"
    )

    welcome_email_sent = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Whether welcome email with SSO setup instructions has been sent"
    )

    welcome_email_sent_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the welcome email was sent"
    )

    # SSO authentication tracking (AC-SSO-003)
    last_sso_login_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last successful SSO login timestamp"
    )

    sso_failures_count = models.IntegerField(
        default=0,
        help_text="Count of consecutive SSO authentication failures (reset on success)"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_kajabi_sso_link'
        unique_together = [('kajabi_email',)]  # Prevent duplicate migrations of same email
        indexes = [
            models.Index(fields=['kajabi_email']),
            models.Index(fields=['kajabi_user_id']),
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['welcome_email_sent']),
        ]
        verbose_name = 'Kajabi SSO Link'
        verbose_name_plural = 'Kajabi SSO Links'

    def __str__(self):
        return f"Kajabi SSO: {self.user.username} ({self.kajabi_email})"

    def record_sso_success(self):
        """Record a successful SSO login. @covers AC-SSO-003"""
        self.last_sso_login_at = timezone.now()
        self.sso_failures_count = 0
        self.save(update_fields=['last_sso_login_at', 'sso_failures_count', 'updated_at'])

    def record_sso_failure(self):
        """Record a failed SSO login attempt. @covers AC-SSO-003"""
        self.sso_failures_count += 1
        self.save(update_fields=['sso_failures_count', 'updated_at'])

    def mark_welcome_email_sent(self):
        """Mark welcome email as sent. @covers AC-SSO-005, AC-NEG-SSO-003"""
        if not self.welcome_email_sent:
            self.welcome_email_sent = True
            self.welcome_email_sent_at = timezone.now()
            self.save(update_fields=['welcome_email_sent', 'welcome_email_sent_at', 'updated_at'])


class KajabiImportBatch(models.Model):
    """
    Tracks bulk imports of Kajabi users from CSV files.

    Each batch represents a single CSV import operation and tracks success/failure stats.

    @covers AC-SSO-002, AC-NEG-SSO-001
    """

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    # Primary key
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Import metadata
    csv_filename = models.CharField(
        max_length=255,
        help_text="Name of the CSV file being imported"
    )

    total_rows = models.IntegerField(
        default=0,
        help_text="Total number of rows in CSV (excluding header)"
    )

    # Import statistics (AC-SSO-002, AC-NEG-SSO-001)
    created_count = models.IntegerField(
        default=0,
        help_text="Number of new user accounts created"
    )

    linked_count = models.IntegerField(
        default=0,
        help_text="Number of existing users linked to Kajabi SSO"
    )

    skipped_count = models.IntegerField(
        default=0,
        help_text="Number of rows skipped (duplicates or already migrated)"
    )

    error_count = models.IntegerField(
        default=0,
        help_text="Number of rows that failed to import"
    )

    # Status tracking
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        db_index=True,
        help_text="Current status of the import batch"
    )

    # Audit trail
    imported_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='kajabi_imports',
        help_text="Admin user who initiated the import"
    )

    started_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the import started processing"
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the import completed (success or failure)"
    )

    # Error logging (row-by-row errors stored as JSON)
    errors_json = models.JSONField(
        default=list,
        help_text="List of errors encountered during import (row number + error message)"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_kajabi_import_batch'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'created_at']),
            models.Index(fields=['imported_by']),
        ]
        verbose_name = 'Kajabi Import Batch'
        verbose_name_plural = 'Kajabi Import Batches'

    def __str__(self):
        return f"{self.csv_filename} ({self.status}) - {self.created_count} created, {self.linked_count} linked"

    def add_error(self, row_number, error_message):
        """Add an error to the errors_json field."""
        if not isinstance(self.errors_json, list):
            self.errors_json = []
        self.errors_json.append({
            'row': row_number,
            'error': str(error_message)
        })
        self.error_count = len(self.errors_json)
        self.save(update_fields=['errors_json', 'error_count'])

    def mark_in_progress(self):
        """Mark batch as in progress."""
        self.status = 'in_progress'
        self.started_at = timezone.now()
        self.save(update_fields=['status', 'started_at'])

    def mark_completed(self):
        """Mark batch as completed."""
        self.status = 'completed'
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'completed_at'])

    def mark_failed(self, error_message=None):
        """Mark batch as failed."""
        self.status = 'failed'
        self.completed_at = timezone.now()
        if error_message:
            self.add_error(0, f"Batch failed: {error_message}")
        self.save(update_fields=['status', 'completed_at'])
