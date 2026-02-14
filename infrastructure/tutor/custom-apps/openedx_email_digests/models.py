"""
Models for email digests and engagement analytics.

@spec: email-notifications-pipeline_spec.md
@covers: AC-037, AC-038, AC-039, AC-040, AC-041, AC-042
"""

import uuid

from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()

# Default timezone for users without timezone set (spec requirement)
DEFAULT_TIMEZONE = 'Asia/Kuala_Lumpur'

DIGEST_FREQUENCY_CHOICES = [
    ('none', 'No Digest (Immediate)'),
    ('daily', 'Daily Digest'),
    ('weekly', 'Weekly Digest'),
]

DIGEST_RUN_STATUS_CHOICES = [
    ('pending', 'Pending'),
    ('running', 'Running'),
    ('completed', 'Completed'),
    ('failed', 'Failed'),
]

EMAIL_EVENT_TYPE_CHOICES = [
    ('send', 'Send'),
    ('delivery', 'Delivery'),
    ('bounce', 'Bounce'),
    ('complaint', 'Complaint'),
    ('open', 'Open'),
    ('click', 'Click'),
    ('reject', 'Reject'),
]


class DigestPreference(models.Model):
    """
    Per-user digest frequency preference.

    Controls whether a user receives immediate notifications or
    batched daily/weekly digests per message type and org.

    @covers AC-037, AC-038
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='digest_preferences',
        db_index=True,
        help_text="User who owns this preference"
    )

    frequency = models.CharField(
        max_length=10,
        choices=DIGEST_FREQUENCY_CHOICES,
        default='none',
        help_text="Digest frequency: none (immediate), daily, weekly"
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Organization slug for multi-tenancy"
    )

    message_types = models.JSONField(
        default=list,
        blank=True,
        help_text=(
            "List of message types to batch into digest "
            "(e.g., ['course_announcement', 'discussion_reply', 'discussion_mention']). "
            "Empty list means all non-urgent types."
        )
    )

    user_timezone = models.CharField(
        max_length=50,
        default=DEFAULT_TIMEZONE,
        help_text="User timezone for digest scheduling (e.g., Asia/Kuala_Lumpur)"
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether digest is active for this user"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_email_digests_digestpreference'
        unique_together = [('user', 'org_slug')]
        indexes = [
            models.Index(fields=['frequency', 'org_slug']),
        ]
        verbose_name = 'Digest Preference'
        verbose_name_plural = 'Digest Preferences'

    def __str__(self):
        return f"{self.user.username} ({self.frequency}/{self.org_slug})"

    @classmethod
    def get_preference(cls, user, org_slug):
        """Get digest preference for a user in an org, or default (immediate)."""
        return cls.objects.filter(
            user=user, org_slug=org_slug, is_active=True
        ).first()

    @classmethod
    def should_suppress_immediate(cls, user, org_slug, message_type):
        """
        Check if immediate email should be suppressed for this user/type.

        If user is on daily/weekly digest for this message type, suppress
        the immediate email (push and in-app may still be immediate).

        @covers AC-038
        """
        pref = cls.get_preference(user, org_slug)
        if not pref or pref.frequency == 'none':
            return False

        # If message_types is empty, all non-urgent types are batched
        if not pref.message_types:
            return True

        return message_type in pref.message_types

    @classmethod
    def get_users_for_digest(cls, frequency, org_slug=None):
        """
        Get all users due for a digest of the given frequency.

        Returns queryset of DigestPreference objects.
        """
        queryset = cls.objects.filter(
            frequency=frequency,
            is_active=True,
        ).select_related('user')

        if org_slug:
            queryset = queryset.filter(org_slug=org_slug)

        return queryset


class DigestRun(models.Model):
    """
    Tracks a digest generation run.

    Each run covers a specific time period and records how many
    digest emails were generated and sent.

    @covers AC-037, AC-039
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    run_id = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        help_text="Unique identifier for this run (e.g., daily-2026-02-14)"
    )

    frequency = models.CharField(
        max_length=10,
        choices=DIGEST_FREQUENCY_CHOICES,
        help_text="Digest frequency this run covers"
    )

    period_start = models.DateTimeField(
        help_text="Start of the digest period (UTC)"
    )

    period_end = models.DateTimeField(
        help_text="End of the digest period (UTC)"
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        default='default',
        help_text="Organization slug"
    )

    status = models.CharField(
        max_length=20,
        choices=DIGEST_RUN_STATUS_CHOICES,
        default='pending',
        db_index=True,
    )

    total_users = models.PositiveIntegerField(
        default=0,
        help_text="Number of users eligible for this digest run"
    )

    emails_sent = models.PositiveIntegerField(
        default=0,
        help_text="Number of digest emails successfully sent"
    )

    emails_skipped = models.PositiveIntegerField(
        default=0,
        help_text="Number skipped (no notifications in period)"
    )

    emails_failed = models.PositiveIntegerField(
        default=0,
        help_text="Number of digest emails that failed to send"
    )

    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    error_message = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_email_digests_digestrun'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['frequency', 'status']),
            models.Index(fields=['period_start', 'period_end']),
        ]
        verbose_name = 'Digest Run'
        verbose_name_plural = 'Digest Runs'

    def __str__(self):
        return f"{self.run_id} ({self.status})"

    def mark_running(self):
        """Mark run as in progress."""
        self.status = 'running'
        self.started_at = timezone.now()
        self.save(update_fields=['status', 'started_at'])

    def mark_completed(self):
        """Mark run as completed."""
        self.status = 'completed'
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'completed_at'])

    def mark_failed(self, error):
        """Mark run as failed."""
        self.status = 'failed'
        self.error_message = str(error)[:2000]
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'error_message', 'completed_at'])


class EmailEvent(models.Model):
    """
    Email engagement event for analytics.

    Tracks send, delivery, open, click, bounce, complaint, and reject events.
    Stored with message_id and campaign_id for per-campaign analytics.
    Retention: 12 months, then purged.

    @covers AC-040, AC-041, AC-042
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    message_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Email message ID (from SES or internal)"
    )

    event_type = models.CharField(
        max_length=20,
        choices=EMAIL_EVENT_TYPE_CHOICES,
        db_index=True,
        help_text="Type of email event"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='email_events',
        null=True,
        blank=True,
        help_text="Recipient user"
    )

    campaign_id = models.UUIDField(
        null=True,
        blank=True,
        db_index=True,
        help_text="Campaign ID if from a bulk campaign"
    )

    template_category = models.CharField(
        max_length=50,
        blank=True,
        default='',
        db_index=True,
        help_text="Template category (message type)"
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        default='default',
        help_text="Organization slug for multi-tenancy"
    )

    tracking_id = models.CharField(
        max_length=100,
        unique=True,
        null=True,
        blank=True,
        help_text="Unique tracking ID for click/open tracking"
    )

    url = models.URLField(
        max_length=2048,
        blank=True,
        default='',
        help_text="Original URL (for click events)"
    )

    user_agent = models.TextField(
        blank=True,
        default='',
        help_text="User agent string (for open/click events)"
    )

    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        help_text="Client IP (for open/click events)"
    )

    bounce_type = models.CharField(
        max_length=20,
        blank=True,
        default='',
        help_text="Bounce type: hard, soft, undetermined"
    )

    metadata = models.JSONField(
        default=dict,
        blank=True,
        help_text="Additional event metadata"
    )

    timestamp = models.DateTimeField(
        db_index=True,
        help_text="When the event occurred"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_email_digests_emailevent'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['message_id', 'event_type']),
            models.Index(fields=['campaign_id', 'event_type']),
            models.Index(fields=['org_slug', 'event_type', 'timestamp']),
            models.Index(fields=['template_category', 'event_type']),
            models.Index(fields=['timestamp']),
        ]
        verbose_name = 'Email Event'
        verbose_name_plural = 'Email Events'

    def __str__(self):
        return f"{self.event_type} for {self.message_id} at {self.timestamp}"

    @classmethod
    def record_event(cls, message_id, event_type, **kwargs):
        """
        Record an email engagement event.

        @covers AC-040, AC-041
        """
        return cls.objects.create(
            message_id=message_id,
            event_type=event_type,
            timestamp=kwargs.pop('timestamp', timezone.now()),
            **kwargs
        )

    @classmethod
    def get_aggregate_stats(cls, org_slug, template_category=None,
                            campaign_id=None, days=30):
        """
        Get aggregate engagement statistics.

        Returns dict with send_count, delivery_count, open_count,
        click_count, bounce_count, complaint_count, and computed rates.

        @covers AC-042
        """
        cutoff = timezone.now() - timezone.timedelta(days=days)
        queryset = cls.objects.filter(
            org_slug=org_slug,
            timestamp__gte=cutoff,
        )

        if template_category:
            queryset = queryset.filter(template_category=template_category)
        if campaign_id:
            queryset = queryset.filter(campaign_id=campaign_id)

        from django.db.models import Count, Q

        stats = queryset.aggregate(
            send_count=Count('id', filter=Q(event_type='send')),
            delivery_count=Count('id', filter=Q(event_type='delivery')),
            open_count=Count('id', filter=Q(event_type='open')),
            click_count=Count('id', filter=Q(event_type='click')),
            bounce_count=Count('id', filter=Q(event_type='bounce')),
            complaint_count=Count('id', filter=Q(event_type='complaint')),
            reject_count=Count('id', filter=Q(event_type='reject')),
        )

        # Compute rates
        sent = stats['send_count'] or 1  # avoid division by zero
        stats['delivery_rate'] = round((stats['delivery_count'] / sent) * 100, 2)
        stats['open_rate'] = round((stats['open_count'] / sent) * 100, 2)
        stats['click_rate'] = round((stats['click_count'] / sent) * 100, 2)
        stats['bounce_rate'] = round((stats['bounce_count'] / sent) * 100, 2)
        stats['complaint_rate'] = round((stats['complaint_count'] / sent) * 100, 2)

        return stats

    @classmethod
    def purge_old_events(cls, retention_months=12):
        """
        Purge engagement data older than retention period.

        Spec: 12-month retention policy.
        """
        cutoff = timezone.now() - timezone.timedelta(days=retention_months * 30)
        deleted_count, _ = cls.objects.filter(timestamp__lt=cutoff).delete()
        return deleted_count
