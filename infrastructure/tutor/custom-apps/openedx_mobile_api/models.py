"""
Models for Mobile Backend API.

@spec: Mobile Backend API (mereka-lms-2gck)
@covers: AC-MOB-002, AC-MOB-003, AC-MOB-006
"""

from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class MobileDevice(models.Model):
    """
    Mobile device registration for push notifications.

    @covers: AC-MOB-002 - Idempotent device token registration
    @covers: AC-MOB-003 - Device deletion support
    """

    PLATFORM_CHOICES = [
        ("ios", "iOS"),
        ("android", "Android"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="mobile_devices",
        help_text="User who owns this device"
    )

    device_token = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="FCM device token (idempotent - AC-MOB-002)"
    )

    platform = models.CharField(
        max_length=10,
        choices=PLATFORM_CHOICES,
        help_text="Device platform (iOS or Android)"
    )

    app_version = models.CharField(
        max_length=50,
        blank=True,
        help_text="App version string (e.g., 1.2.3)"
    )

    os_version = models.CharField(
        max_length=50,
        blank=True,
        help_text="OS version string (e.g., iOS 17.0, Android 14)"
    )

    device_name = models.CharField(
        max_length=100,
        blank=True,
        help_text="Device name (e.g., iPhone 15 Pro, Pixel 8)"
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether device is active for notifications"
    )

    last_active = models.DateTimeField(
        auto_now=True,
        help_text="Last time device was active (updated on re-registration)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mobile_device"
        verbose_name = "Mobile Device"
        verbose_name_plural = "Mobile Devices"
        indexes = [
            models.Index(fields=["user", "platform", "is_active"]),
            models.Index(fields=["last_active"]),
        ]
        ordering = ["-last_active"]

    def __str__(self):
        return f"{self.user.username} - {self.platform} ({self.device_name or 'Unknown'})"

    def deactivate(self):
        """Deactivate device (AC-MOB-003)."""
        self.is_active = False
        self.save(update_fields=["is_active", "updated_at"])

    def reactivate(self):
        """Reactivate device on re-registration (AC-MOB-002)."""
        self.is_active = True
        self.last_active = timezone.now()
        self.save(update_fields=["is_active", "last_active", "updated_at"])


class MobileBrandingConfig(models.Model):
    """
    Per-tenant branding configuration for mobile apps.

    @covers: AC-MOB-001 - Branding config API
    """

    org_slug = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        help_text="Organization slug (e.g., 'mereka')"
    )

    org_name = models.CharField(
        max_length=255,
        help_text="Organization display name"
    )

    primary_color = models.CharField(
        max_length=7,
        default="#1a73e8",
        help_text="Primary brand color (hex, e.g., #1a73e8)"
    )

    secondary_color = models.CharField(
        max_length=7,
        default="#34a853",
        help_text="Secondary brand color (hex)"
    )

    logo_url = models.URLField(
        blank=True,
        help_text="URL to organization logo (PNG/SVG)"
    )

    logo_square_url = models.URLField(
        blank=True,
        help_text="URL to square logo for app icon"
    )

    splash_background_color = models.CharField(
        max_length=7,
        default="#ffffff",
        help_text="Splash screen background color"
    )

    enable_dark_mode = models.BooleanField(
        default=True,
        help_text="Whether dark mode is enabled"
    )

    enable_push_notifications = models.BooleanField(
        default=True,
        help_text="Whether push notifications are enabled"
    )

    enable_offline_mode = models.BooleanField(
        default=True,
        help_text="Whether offline content download is enabled"
    )

    min_ios_version = models.CharField(
        max_length=20,
        default="1.0.0",
        help_text="Minimum supported iOS app version"
    )

    min_android_version = models.CharField(
        max_length=20,
        default="1.0.0",
        help_text="Minimum supported Android app version"
    )

    custom_config = models.JSONField(
        default=dict,
        blank=True,
        help_text="Additional custom configuration (JSON)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mobile_branding_config"
        verbose_name = "Mobile Branding Config"
        verbose_name_plural = "Mobile Branding Configs"

    def __str__(self):
        return f"{self.org_name} ({self.org_slug})"


class MobileAppVersion(models.Model):
    """
    Mobile app version compatibility tracking.

    @covers: AC-MOB-001 - App version compatibility check
    """

    PLATFORM_CHOICES = MobileDevice.PLATFORM_CHOICES

    platform = models.CharField(
        max_length=10,
        choices=PLATFORM_CHOICES,
        help_text="Platform (iOS or Android)"
    )

    version = models.CharField(
        max_length=50,
        help_text="App version string (e.g., 1.2.3)"
    )

    min_supported_version = models.CharField(
        max_length=50,
        help_text="Minimum supported backend API version"
    )

    is_deprecated = models.BooleanField(
        default=False,
        help_text="Whether this version is deprecated"
    )

    force_update = models.BooleanField(
        default=False,
        help_text="Whether users must update to continue using the app"
    )

    release_notes = models.TextField(
        blank=True,
        help_text="Release notes for this version"
    )

    released_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When this version was released"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "mobile_app_version"
        verbose_name = "Mobile App Version"
        verbose_name_plural = "Mobile App Versions"
        unique_together = [["platform", "version"]]
        ordering = ["-released_at"]

    def __str__(self):
        return f"{self.platform} v{self.version}"
