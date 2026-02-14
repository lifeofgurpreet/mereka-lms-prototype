"""
Email preference and GDPR consent models.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
@covers: AC-020, AC-021, AC-022, AC-023, AC-024, AC-043, AC-044, AC-045
"""

import hashlib
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


# Email category choices
EMAIL_CATEGORY_CHOICES = [
    ('marketing', 'Marketing Communications'),
    ('transactional', 'Transactional Emails'),
    ('announcements', 'Course Announcements'),
    ('reminders', 'Assignment Reminders'),
    ('discussions', 'Discussion Notifications'),
]


class UserEmailPreference(models.Model):
    """
    Per-user, per-category email preferences.

    Default state: all categories enabled except marketing (GDPR opt-in required).
    """

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='email_preferences',
        db_index=True,
        help_text="User whose preferences these are"
    )

    category = models.CharField(
        max_length=50,
        choices=EMAIL_CATEGORY_CHOICES,
        db_index=True,
        help_text="Email category (marketing, transactional, etc.)"
    )

    opted_in = models.BooleanField(
        default=True,
        help_text="Whether user has opted in to this category"
    )

    consent_version = models.CharField(
        max_length=50,
        default='v1.0-2026-02-14',
        help_text="Version of consent text shown to user (for GDPR audit)"
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="When preference was first created (UTC)"
    )

    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When preference was last modified (UTC)"
    )

    class Meta:
        db_table = 'openedx_email_preferences_user_preference'
        unique_together = [('user', 'category')]
        ordering = ['user', 'category']
        indexes = [
            models.Index(fields=['user', 'category']),
            models.Index(fields=['updated_at']),
        ]
        verbose_name = 'Email Preference'
        verbose_name_plural = 'Email Preferences'

    def __str__(self):
        return f"{self.user.username} - {self.category}: {'opted-in' if self.opted_in else 'opted-out'}"

    @classmethod
    def get_default_preferences(cls):
        """
        Return default preferences for new users.

        @covers AC-020
        """
        return {
            'marketing': False,  # GDPR: opt-in required
            'transactional': True,
            'announcements': True,
            'reminders': True,
            'discussions': True,
        }

    @classmethod
    def get_user_preferences(cls, user):
        """
        Get all preferences for a user, with defaults for missing categories.

        @covers AC-020
        """
        existing = {
            pref.category: pref.opted_in
            for pref in cls.objects.filter(user=user)
        }

        defaults = cls.get_default_preferences()

        # Merge existing with defaults
        result = {}
        for category, default_value in defaults.items():
            result[category] = existing.get(category, default_value)

        return result

    @classmethod
    def update_user_preference(cls, user, category, opted_in, consent_version='v1.0-2026-02-14', ip_address=None):
        """
        Update a user's preference for a category, creating audit trail.

        @covers AC-021, AC-023
        """
        # Get or create preference
        preference, created = cls.objects.get_or_create(
            user=user,
            category=category,
            defaults={
                'opted_in': opted_in,
                'consent_version': consent_version,
            }
        )

        old_value = preference.opted_in

        # Update if changed
        if old_value != opted_in:
            preference.opted_in = opted_in
            preference.consent_version = consent_version
            preference.save(update_fields=['opted_in', 'consent_version', 'updated_at'])

            # Create audit trail
            ConsentRecord.objects.create(
                user=user,
                category=category,
                old_value=old_value,
                new_value=opted_in,
                consent_version=consent_version,
                ip_address_hash=cls._hash_ip(ip_address) if ip_address else None,
                source='api' if not created else 'default',
            )

        return preference

    @staticmethod
    def _hash_ip(ip_address):
        """Hash IP address for GDPR compliance (don't store plaintext IPs)."""
        if not ip_address:
            return None
        return hashlib.sha256(ip_address.encode('utf-8')).hexdigest()[:16]


class ConsentRecord(models.Model):
    """
    Immutable audit trail of consent changes for GDPR compliance.

    Required by GDPR Article 7 (consent) and Article 21 (right to object).
    """

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='consent_records',
        db_index=True,
        help_text="User whose consent this records"
    )

    category = models.CharField(
        max_length=50,
        db_index=True,
        help_text="Email category affected"
    )

    old_value = models.BooleanField(
        help_text="Previous opted-in state (null for initial creation)"
    )

    new_value = models.BooleanField(
        help_text="New opted-in state"
    )

    consent_version = models.CharField(
        max_length=50,
        help_text="Version of consent text shown (e.g., v1.0-2026-02-14)"
    )

    ip_address_hash = models.CharField(
        max_length=64,
        null=True,
        blank=True,
        help_text="SHA-256 hash of IP address (GDPR: not full IP)"
    )

    source = models.CharField(
        max_length=50,
        default='api',
        help_text="How change was made (api, one_click_unsubscribe, admin)"
    )

    timestamp = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="When consent was recorded (UTC)"
    )

    class Meta:
        db_table = 'openedx_email_preferences_consent_record'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', 'timestamp']),
            models.Index(fields=['category', 'timestamp']),
        ]
        verbose_name = 'Consent Record'
        verbose_name_plural = 'Consent Records'

    def __str__(self):
        return f"{self.user.username} - {self.category}: {self.old_value} -> {self.new_value} ({self.timestamp})"

    @classmethod
    def get_user_consent_history(cls, user):
        """
        Get full consent history for a user (for GDPR SAR).

        @covers AC-044
        """
        return cls.objects.filter(user=user).order_by('-timestamp')
