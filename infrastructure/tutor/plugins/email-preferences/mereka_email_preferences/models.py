# @covers AC-020, AC-021, AC-022, AC-023, AC-043
# @spec: email-notifications-pipeline_spec.md
"""
Email notification preference models.

AC-020: Default preferences API (all enabled except bulk_campaign email)
AC-021: User preference update (PUT preferences, per-channel toggles)
AC-022: One-click unsubscribe (HMAC token, disables bulk_campaign)
AC-023: Audit log for preference changes
AC-043: GDPR compliance (bulk_campaign disabled by default)
"""

from django.db import models

# 15 ACE message types as defined in the spec
MESSAGE_TYPE_CHOICES = [
    ("password_reset", "Password Reset"),
    ("account_activation", "Account Activation"),
    ("enrollment_confirmation", "Enrollment Confirmation"),
    ("course_announcement", "Course Announcement"),
    ("assignment_reminder", "Assignment Reminder"),
    ("grade_posted", "Grade Posted"),
    ("discussion_reply", "Discussion Reply"),
    ("discussion_mention", "Discussion Mention"),
    ("certificate_issued", "Certificate Issued"),
    ("course_start_reminder", "Course Start Reminder"),
    ("course_completion", "Course Completion"),
    ("license_expiry_warning", "License Expiry Warning"),
    ("enterprise_welcome", "Enterprise Welcome"),
    ("bulk_campaign", "Bulk Campaign"),
    ("forum_digest", "Forum Digest"),
]

CHANNEL_CHOICES = [
    ("email", "Email"),
    ("push", "Push Notification"),
    ("in_app", "In-App Notification"),
]

CHANGE_SOURCE_CHOICES = [
    ("api", "API"),
    ("unsubscribe", "One-Click Unsubscribe"),
    ("admin", "Admin"),
    ("system", "System"),
]


class NotificationPreference(models.Model):
    """
    User notification preferences per message type and channel.

    Default behavior (AC-020, AC-043):
    - All message types enabled EXCEPT bulk_campaign email (GDPR)
    - System-critical types (password_reset, account_activation) are non-suppressible
    """

    user_id = models.IntegerField(
        db_index=True,
        help_text="Open edX user ID (references auth_user.id)",
    )
    message_type = models.CharField(
        max_length=50,
        choices=MESSAGE_TYPE_CHOICES,
        help_text="Type of notification message",
    )
    channel = models.CharField(
        max_length=20,
        choices=CHANNEL_CHOICES,
        help_text="Notification channel (email, push, in_app)",
    )
    enabled = models.BooleanField(
        default=True,
        help_text="Whether this notification is enabled for the user",
    )
    consent_version = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        help_text="Version of consent policy accepted by user",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Timestamp of last update",
    )

    class Meta:
        app_label = "mereka_email_preferences"
        verbose_name = "Notification Preference"
        verbose_name_plural = "Notification Preferences"
        db_table = "mereka_notification_preference"
        unique_together = [["user_id", "message_type", "channel"]]
        indexes = [
            models.Index(fields=["user_id", "message_type", "channel"]),
            models.Index(fields=["user_id", "enabled"]),
        ]

    def __str__(self):
        return (
            f"User {self.user_id}: {self.message_type} via {self.channel} (enabled={self.enabled})"
        )

    @classmethod
    def is_enabled(cls, user_id, message_type, channel="email"):
        """
        Check if a notification is enabled for a user.

        System-critical types (password_reset, account_activation) always return True.

        Returns:
            bool: True if enabled or not explicitly set, False if disabled
        """
        # System-critical types are always enabled
        if message_type in ["password_reset", "account_activation"]:
            return True

        try:
            pref = cls.objects.get(user_id=user_id, message_type=message_type, channel=channel)
            return pref.enabled
        except cls.DoesNotExist:
            # Default: enabled for all except bulk_campaign email (GDPR - AC-043)
            if message_type == "bulk_campaign" and channel == "email":
                return False
            return True


class PreferenceAuditLog(models.Model):
    """
    Audit log for notification preference changes.

    AC-023: Tracks user_id, old_value, new_value, consent_version, ip_address_hash, timestamp
    """

    user_id = models.IntegerField(
        db_index=True,
        help_text="Open edX user ID (references auth_user.id)",
    )
    message_type = models.CharField(
        max_length=50,
        choices=MESSAGE_TYPE_CHOICES,
        help_text="Type of notification message",
    )
    channel = models.CharField(
        max_length=20,
        choices=CHANNEL_CHOICES,
        help_text="Notification channel",
    )
    old_value = models.BooleanField(
        null=True,
        blank=True,
        help_text="Previous enabled state (null if new preference)",
    )
    new_value = models.BooleanField(
        help_text="New enabled state",
    )
    consent_version = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        help_text="Version of consent policy at time of change",
    )
    ip_address_hash = models.CharField(
        max_length=64,
        null=True,
        blank=True,
        help_text="SHA256 hash of IP address (privacy)",
    )
    timestamp = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="Timestamp of preference change",
    )
    change_source = models.CharField(
        max_length=20,
        choices=CHANGE_SOURCE_CHOICES,
        default="api",
        help_text="Source of the preference change",
    )

    class Meta:
        app_label = "mereka_email_preferences"
        verbose_name = "Preference Audit Log"
        verbose_name_plural = "Preference Audit Logs"
        db_table = "mereka_preference_audit_log"
        ordering = ["-timestamp"]
        indexes = [
            models.Index(fields=["user_id", "timestamp"]),
            models.Index(fields=["message_type", "timestamp"]),
        ]

    def __str__(self):
        return f"User {self.user_id}: {self.message_type}/{self.channel} {self.old_value}→{self.new_value} at {self.timestamp}"
