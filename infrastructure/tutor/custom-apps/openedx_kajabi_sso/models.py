"""
Models for Kajabi SSO integration.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-001, AC-SSO-002, AC-SSO-004
"""

from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class KajabiSSOUser(models.Model):
    """
    Links Open edX users to Kajabi SSO identities.

    @covers: AC-SSO-001 - OAuth2 user matching via email
    @covers: AC-SSO-004 - Email + username deduplication
    """

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="kajabi_sso",
        help_text="Open edX user account"
    )

    kajabi_user_id = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="Kajabi user ID from OAuth2 provider"
    )

    kajabi_email = models.EmailField(
        db_index=True,
        help_text="Email address from Kajabi (for deduplication)"
    )

    sso_enabled = models.BooleanField(
        default=True,
        help_text="Whether SSO is enabled for this user"
    )

    fallback_to_password = models.BooleanField(
        default=True,
        help_text="Allow fallback to email/password if SSO fails (AC-SSO-003)"
    )

    last_sso_login = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp of last successful SSO login"
    )

    welcome_email_sent = models.BooleanField(
        default=False,
        help_text="Whether welcome email with SSO instructions was sent (AC-SSO-005)"
    )

    welcome_email_sent_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when welcome email was sent"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "kajabi_sso_user"
        verbose_name = "Kajabi SSO User"
        verbose_name_plural = "Kajabi SSO Users"
        indexes = [
            models.Index(fields=["kajabi_email", "sso_enabled"]),
            models.Index(fields=["last_sso_login"]),
        ]

    def __str__(self):
        return f"{self.user.username} ({self.kajabi_email})"

    def record_sso_login(self):
        """Record successful SSO login timestamp."""
        self.last_sso_login = timezone.now()
        self.save(update_fields=["last_sso_login", "updated_at"])

    def mark_welcome_email_sent(self):
        """Mark welcome email as sent (AC-SSO-005)."""
        self.welcome_email_sent = True
        self.welcome_email_sent_at = timezone.now()
        self.save(update_fields=["welcome_email_sent", "welcome_email_sent_at", "updated_at"])


class KajabiImportLog(models.Model):
    """
    Audit log for bulk CSV imports.

    @covers: AC-SSO-002 - Bulk import tracking
    @covers: AC-SSO-004 - Deduplication enforcement
    """

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("processing", "Processing"),
        ("completed", "Completed"),
        ("failed", "Failed"),
    ]

    OPERATION_CHOICES = [
        ("create", "Create New User"),
        ("link", "Link Existing User"),
        ("skip_duplicate", "Skip Duplicate"),
        ("error", "Error"),
    ]

    import_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique identifier for import batch"
    )

    filename = models.CharField(
        max_length=255,
        help_text="CSV filename"
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending",
        help_text="Import job status"
    )

    total_rows = models.IntegerField(
        default=0,
        help_text="Total rows in CSV"
    )

    created_users = models.IntegerField(
        default=0,
        help_text="Number of new users created"
    )

    linked_users = models.IntegerField(
        default=0,
        help_text="Number of existing users linked to SSO"
    )

    skipped_duplicates = models.IntegerField(
        default=0,
        help_text="Number of duplicates skipped (AC-SSO-004)"
    )

    errors = models.IntegerField(
        default=0,
        help_text="Number of errors encountered"
    )

    welcome_emails_sent = models.IntegerField(
        default=0,
        help_text="Number of welcome emails sent (AC-SSO-005)"
    )

    error_log = models.TextField(
        blank=True,
        help_text="Detailed error log"
    )

    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "kajabi_import_log"
        verbose_name = "Kajabi Import Log"
        verbose_name_plural = "Kajabi Import Logs"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.import_id} ({self.status})"

    def start_processing(self):
        """Mark import as started."""
        self.status = "processing"
        self.started_at = timezone.now()
        self.save(update_fields=["status", "started_at"])

    def complete(self):
        """Mark import as completed."""
        self.status = "completed"
        self.completed_at = timezone.now()
        self.save(update_fields=["status", "completed_at"])

    def fail(self, error_message):
        """Mark import as failed."""
        self.status = "failed"
        self.completed_at = timezone.now()
        self.error_log = error_message
        self.save(update_fields=["status", "completed_at", "error_log"])


class KajabiImportRecord(models.Model):
    """
    Individual record from CSV import.

    @covers: AC-SSO-002 - Per-row import tracking
    @covers: AC-SSO-004 - Duplicate detection
    """

    import_log = models.ForeignKey(
        KajabiImportLog,
        on_delete=models.CASCADE,
        related_name="records"
    )

    row_number = models.IntegerField(
        help_text="CSV row number (for error reporting)"
    )

    kajabi_user_id = models.CharField(
        max_length=255,
        help_text="Kajabi user ID from CSV"
    )

    email = models.EmailField(
        help_text="Email from CSV"
    )

    username = models.CharField(
        max_length=150,
        blank=True,
        help_text="Username from CSV (optional)"
    )

    operation = models.CharField(
        max_length=20,
        choices=KajabiImportLog.OPERATION_CHOICES,
        help_text="Operation performed"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text="Created/linked user"
    )

    error_message = models.TextField(
        blank=True,
        help_text="Error details (if operation=error)"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "kajabi_import_record"
        verbose_name = "Kajabi Import Record"
        verbose_name_plural = "Kajabi Import Records"
        ordering = ["row_number"]

    def __str__(self):
        return f"Row {self.row_number}: {self.email} ({self.operation})"
