"""
Device registration model for push notifications.

@spec: email-notifications-pipeline_spec.md
@covers: AC-015, AC-016, AC-017, AC-019
"""

from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class DeviceRegistration(models.Model):
    """
    FCM device token registration for push notifications.

    Each record links a user to a device token scoped by org_slug
    for multi-tenant notification isolation.
    """

    PLATFORM_IOS = 'ios'
    PLATFORM_ANDROID = 'android'
    PLATFORM_CHOICES = [
        (PLATFORM_IOS, 'iOS'),
        (PLATFORM_ANDROID, 'Android'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='push_devices',
        db_index=True,
        help_text="Device owner",
    )

    device_token = models.CharField(
        max_length=512,
        db_index=True,
        help_text="FCM registration token",
    )

    platform = models.CharField(
        max_length=10,
        choices=PLATFORM_CHOICES,
        db_index=True,
        help_text="Device platform (ios/android)",
    )

    app_version = models.CharField(
        max_length=50,
        blank=True,
        default='',
        help_text="Client app version string",
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Organization slug for multi-tenancy isolation",
    )

    is_active = models.BooleanField(
        default=True,
        db_index=True,
        help_text="False when FCM returns UNREGISTERED/INVALID_ARGUMENT",
    )

    registered_at = models.DateTimeField(
        auto_now_add=True,
        help_text="First registration timestamp (UTC)",
    )

    last_seen_at = models.DateTimeField(
        auto_now=True,
        help_text="Last re-registration or activity timestamp (UTC)",
    )

    class Meta:
        db_table = 'openedx_push_device_registration'
        unique_together = [('device_token', 'org_slug')]
        indexes = [
            models.Index(fields=['user', 'org_slug', 'is_active']),
            models.Index(fields=['device_token']),
        ]
        verbose_name = 'Device Registration'
        verbose_name_plural = 'Device Registrations'

    def __str__(self):
        return f"{self.platform} device for {self.user.username} ({self.org_slug})"

    def deactivate(self):
        """Mark device as inactive (FCM UNREGISTERED). @covers AC-016"""
        if self.is_active:
            self.is_active = False
            self.save(update_fields=['is_active'])

    @classmethod
    def register_or_update(cls, user, device_token, platform, org_slug, app_version=''):
        """
        Register a device token or update if it already exists.

        Deduplication: if the same token+org_slug exists for a different user,
        reassign it (a device can only belong to one user at a time).

        @covers AC-015
        """
        device, created = cls.objects.update_or_create(
            device_token=device_token,
            org_slug=org_slug,
            defaults={
                'user': user,
                'platform': platform,
                'app_version': app_version,
                'is_active': True,
            },
        )
        if not created:
            # Touch last_seen_at
            device.save(update_fields=['last_seen_at'])
        return device, created

    @classmethod
    def unregister(cls, user, device_token):
        """
        Unregister a device token (user logout).

        @covers AC-017
        """
        return cls.objects.filter(
            user=user,
            device_token=device_token,
        ).update(is_active=False)

    @classmethod
    def get_active_tokens(cls, user_ids, org_slug):
        """
        Get active device tokens for a set of users in a specific org.

        @covers AC-019 (no cross-tenant delivery)
        """
        return cls.objects.filter(
            user_id__in=user_ids,
            org_slug=org_slug,
            is_active=True,
        ).values_list('device_token', 'platform', 'user_id')
