# @covers AC-033, AC-034, AC-035
# @spec: email-notifications-pipeline_spec.md
"""
Email suppression list model for bounce and complaint tracking.

AC-033: Hard bounce suppression list processing
AC-034: Soft bounce (3 within 7 days) treatment
AC-035: Complaint handling and preference disabling
"""

from django.db import models
from django.utils import timezone


class EmailSuppression(models.Model):
    """
    Tracks email addresses that should be suppressed from sending.

    Reasons include:
    - hard_bounce: Permanent delivery failure (invalid address, domain doesn't exist)
    - soft_bounce: Temporary delivery failure (mailbox full, temporary error)
    - complaint: User marked email as spam
    """

    REASON_CHOICES = [
        ('hard_bounce', 'Hard Bounce'),
        ('soft_bounce', 'Soft Bounce'),
        ('complaint', 'Complaint'),
    ]

    email = models.EmailField(
        max_length=254,
        unique=True,
        db_index=True,
        help_text="Email address to suppress from sending",
    )
    reason = models.CharField(
        max_length=20,
        choices=REASON_CHOICES,
        help_text="Reason for suppression",
    )
    bounce_count = models.IntegerField(
        default=0,
        help_text="Number of soft bounces within the last 7 days",
    )
    bounced_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp of most recent bounce event",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp when suppression was first added",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Timestamp of last update",
    )

    class Meta:
        app_label = "mereka_email_suppression"
        verbose_name = "Email Suppression"
        verbose_name_plural = "Email Suppressions"
        db_table = "mereka_email_suppression"
        indexes = [
            models.Index(fields=['email', 'reason']),
            models.Index(fields=['bounced_at']),
        ]

    def __str__(self):
        return f"{self.email} ({self.get_reason_display()})"

    def is_suppressed(self):
        """Check if this email address is currently suppressed."""
        if self.reason in ['hard_bounce', 'complaint']:
            return True

        # Soft bounce: suppress if count >= 3 within last 7 days
        if self.reason == 'soft_bounce':
            if self.bounce_count >= 3:
                # Check if last bounce was within 7 days
                if self.bounced_at and (timezone.now() - self.bounced_at).days <= 7:
                    return True

        return False

    @classmethod
    def is_email_suppressed(cls, email_address):
        """
        Check if an email address is suppressed.

        Args:
            email_address: Email address to check

        Returns:
            bool: True if suppressed, False otherwise
        """
        try:
            suppression = cls.objects.get(email=email_address.lower())
            return suppression.is_suppressed()
        except cls.DoesNotExist:
            return False
