"""
Notification store models for in-app notifications.

@spec: email-notifications-pipeline_spec.md
@covers: AC-010, AC-011, AC-012, AC-013, AC-014
"""

import uuid
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class Notification(models.Model):
    """
    In-app notification record.

    Each notification is scoped to a user and org_slug (multi-tenant isolation).
    Expired notifications are filtered out of API responses and purged after 90 days.
    """

    # Primary key (UUID for deduplication across distributed systems)
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # User association
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notifications',
        db_index=True,
        help_text="Recipient user"
    )

    # Notification metadata
    message_type = models.CharField(
        max_length=50,
        db_index=True,
        help_text="ACE message type (e.g., course_announcement, assignment_reminder)"
    )

    title = models.CharField(
        max_length=255,
        help_text="Notification title (shown in notification bell)"
    )

    body = models.TextField(
        help_text="Notification body text (supports Markdown)"
    )

    # Context
    course_id = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_index=True,
        help_text="Course ID (if notification is course-specific)"
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Organization slug for multi-tenancy isolation"
    )

    deep_link_url = models.URLField(
        max_length=1024,
        null=True,
        blank=True,
        help_text="Deep link URL for mobile apps and MFE navigation"
    )

    # State
    read = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Whether the notification has been read"
    )

    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="When the notification was created (UTC)"
    )

    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        help_text="When the notification expires and should not be shown (UTC)"
    )

    class Meta:
        db_table = 'openedx_notifications_notification'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'read', 'created_at']),
            models.Index(fields=['user', 'org_slug', 'read']),
            models.Index(fields=['expires_at']),
        ]
        verbose_name = 'Notification'
        verbose_name_plural = 'Notifications'

    def __str__(self):
        return f"{self.message_type} for {self.user.username} ({self.id})"

    def is_expired(self):
        """Check if notification has expired."""
        if self.expires_at is None:
            return False
        return timezone.now() > self.expires_at

    def mark_read(self):
        """Mark notification as read."""
        if not self.read:
            self.read = True
            self.save(update_fields=['read'])

    @classmethod
    def get_unread_count(cls, user, org_slug):
        """
        Get count of unread notifications for user in org.

        @covers AC-010
        """
        return cls.objects.filter(
            user=user,
            org_slug=org_slug,
            read=False
        ).exclude(
            expires_at__lt=timezone.now()
        ).count()

    @classmethod
    def get_active_notifications(cls, user, org_slug):
        """
        Get all active (non-expired) notifications for user in org.

        @covers AC-011, AC-012, AC-014
        """
        queryset = cls.objects.filter(
            user=user,
            org_slug=org_slug
        ).select_related('user')

        # Exclude expired notifications (AC-012)
        queryset = queryset.exclude(
            expires_at__lt=timezone.now()
        )

        return queryset

    @classmethod
    def mark_all_read(cls, user, org_slug):
        """
        Mark all unread notifications as read for user in org.

        @covers AC-013
        """
        return cls.objects.filter(
            user=user,
            org_slug=org_slug,
            read=False
        ).exclude(
            expires_at__lt=timezone.now()
        ).update(read=True)

    @classmethod
    def purge_expired(cls, retention_days=90):
        """
        Delete expired notifications older than retention_days.

        This is called by a scheduled Celery task daily.
        """
        cutoff = timezone.now() - timezone.timedelta(days=retention_days)
        return cls.objects.filter(
            expires_at__lt=cutoff
        ).delete()
