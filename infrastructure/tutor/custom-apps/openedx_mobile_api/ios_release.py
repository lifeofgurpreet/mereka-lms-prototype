"""
iOS App Store release metadata and configuration.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023
"""

from django.db import models
from django.utils import timezone


class AppStoreMetadata(models.Model):
    """
    App Store listing metadata (description, keywords, etc.).

    @covers: AC-MOB-020 - App Store metadata configuration
    """

    LANGUAGE_CHOICES = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("ms-MY", "Malay"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
    ]

    language = models.CharField(
        max_length=10,
        choices=LANGUAGE_CHOICES,
        default="en-US",
        help_text="App Store listing language"
    )

    app_name = models.CharField(
        max_length=30,
        default="Mereka Academy",
        help_text="App name (max 30 characters)"
    )

    subtitle = models.CharField(
        max_length=30,
        blank=True,
        help_text="App subtitle (max 30 characters, iOS 11+)"
    )

    promotional_text = models.CharField(
        max_length=170,
        blank=True,
        help_text="Promotional text (max 170 characters, updatable without review)"
    )

    description = models.TextField(
        help_text="App description (max 4000 characters)"
    )

    keywords = models.CharField(
        max_length=100,
        help_text="Comma-separated keywords (max 100 characters total)"
    )

    marketing_url = models.URLField(
        blank=True,
        help_text="Marketing website URL"
    )

    support_url = models.URLField(
        help_text="Support/help URL (required)"
    )

    privacy_policy_url = models.URLField(
        help_text="Privacy policy URL (required)"
    )

    version_whats_new = models.TextField(
        blank=True,
        help_text="What's new in this version (max 4000 characters)"
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether this metadata is currently active"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "app_store_metadata"
        verbose_name = "App Store Metadata"
        verbose_name_plural = "App Store Metadata"
        unique_together = [["language", "is_active"]]
        ordering = ["language"]

    def __str__(self):
        return f"{self.app_name} ({self.get_language_display()})"


class AppStoreScreenshot(models.Model):
    """
    App Store screenshot configuration.

    @covers: AC-MOB-021 - Screenshots and preview media configuration
    """

    DEVICE_TYPE_CHOICES = [
        ("iphone_67", "iPhone 6.7\" (14 Pro Max, 15 Pro Max)"),
        ("iphone_65", "iPhone 6.5\" (Xs Max, 11 Pro Max, 12/13/14 Plus)"),
        ("iphone_58", "iPhone 5.8\" (X, Xs, 11 Pro, 12 mini)"),
        ("iphone_55", "iPhone 5.5\" (6s Plus, 7 Plus, 8 Plus)"),
        ("ipad_129", "iPad Pro 12.9\" (3rd gen+)"),
        ("ipad_11", "iPad Pro 11\" / iPad Air 10.9\""),
    ]

    metadata = models.ForeignKey(
        AppStoreMetadata,
        on_delete=models.CASCADE,
        related_name="screenshots",
        help_text="Parent metadata"
    )

    device_type = models.CharField(
        max_length=20,
        choices=DEVICE_TYPE_CHOICES,
        help_text="Device type/size for this screenshot"
    )

    screenshot_url = models.URLField(
        help_text="URL to screenshot image (PNG/JPEG)"
    )

    display_order = models.IntegerField(
        default=0,
        help_text="Display order (0-indexed, max 10 screenshots per device)"
    )

    caption = models.CharField(
        max_length=100,
        blank=True,
        help_text="Optional caption for screenshot"
    )

    width_pixels = models.IntegerField(
        help_text="Screenshot width in pixels"
    )

    height_pixels = models.IntegerField(
        help_text="Screenshot height in pixels"
    )

    is_preview_frame = models.BooleanField(
        default=False,
        help_text="Whether this is a preview video frame"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "app_store_screenshot"
        verbose_name = "App Store Screenshot"
        verbose_name_plural = "App Store Screenshots"
        unique_together = [["metadata", "device_type", "display_order"]]
        ordering = ["device_type", "display_order"]

    def __str__(self):
        return f"{self.get_device_type_display()} - #{self.display_order + 1}"


class AppStoreReviewNotes(models.Model):
    """
    App Store review submission notes.

    @covers: AC-MOB-022 - Review notes and test account credentials
    """

    version = models.CharField(
        max_length=50,
        unique=True,
        db_index=True,
        help_text="App version (e.g., 1.0.0)"
    )

    review_notes = models.TextField(
        help_text="Notes for App Store review team"
    )

    demo_username = models.CharField(
        max_length=150,
        help_text="Demo account username for reviewers"
    )

    demo_password = models.CharField(
        max_length=255,
        help_text="Demo account password (encrypted in production)"
    )

    demo_account_notes = models.TextField(
        blank=True,
        help_text="Special instructions for demo account (e.g., course enrollment)"
    )

    requires_idfa = models.BooleanField(
        default=False,
        help_text="Whether app uses IDFA (affects privacy questions)"
    )

    uses_encryption = models.BooleanField(
        default=True,
        help_text="Whether app uses encryption (HTTPS qualifies as yes)"
    )

    export_compliance_code = models.CharField(
        max_length=100,
        blank=True,
        help_text="Export compliance code if applicable"
    )

    content_rights_declaration = models.TextField(
        blank=True,
        help_text="Declaration of content rights for third-party content"
    )

    submitted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When review was submitted"
    )

    approved_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When review was approved"
    )

    rejection_reason = models.TextField(
        blank=True,
        help_text="Reason for rejection (if rejected)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "app_store_review_notes"
        verbose_name = "App Store Review Notes"
        verbose_name_plural = "App Store Review Notes"
        ordering = ["-created_at"]

    def __str__(self):
        return f"v{self.version} Review Notes"

    def mark_submitted(self):
        """Mark review as submitted."""
        self.submitted_at = timezone.now()
        self.save(update_fields=["submitted_at", "updated_at"])

    def mark_approved(self):
        """Mark review as approved."""
        self.approved_at = timezone.now()
        self.save(update_fields=["approved_at", "updated_at"])

    def mark_rejected(self, reason):
        """Mark review as rejected."""
        self.rejection_reason = reason
        self.save(update_fields=["rejection_reason", "updated_at"])


class IOSBrandingExtension(models.Model):
    """
    iOS-specific branding extensions (icons, splash screens, etc.).

    @covers: AC-MOB-023 - iOS-specific branding (multi-tenant)
    """

    org_slug = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        help_text="Organization slug (links to MobileBrandingConfig)"
    )

    app_icon_1024 = models.URLField(
        help_text="App icon 1024x1024 (for App Store)"
    )

    app_icon_180 = models.URLField(
        blank=True,
        help_text="App icon 180x180 (iPhone)"
    )

    app_icon_167 = models.URLField(
        blank=True,
        help_text="App icon 167x167 (iPad Pro)"
    )

    splash_screen_portrait = models.URLField(
        blank=True,
        help_text="Splash screen portrait (1125x2436 for iPhone X+)"
    )

    splash_screen_landscape = models.URLField(
        blank=True,
        help_text="Splash screen landscape (2436x1125 for iPhone X+)"
    )

    splash_screen_ipad = models.URLField(
        blank=True,
        help_text="Splash screen iPad (2048x2732)"
    )

    status_bar_style = models.CharField(
        max_length=20,
        default="default",
        choices=[
            ("default", "Default (Dark content)"),
            ("light", "Light (Light content)"),
        ],
        help_text="Status bar style"
    )

    tint_color = models.CharField(
        max_length=7,
        default="#1a73e8",
        help_text="iOS tint color (hex, for buttons and links)"
    )

    navigation_bar_color = models.CharField(
        max_length=7,
        default="#ffffff",
        help_text="Navigation bar background color"
    )

    tab_bar_color = models.CharField(
        max_length=7,
        default="#ffffff",
        help_text="Tab bar background color"
    )

    enable_haptic_feedback = models.BooleanField(
        default=True,
        help_text="Whether haptic feedback is enabled"
    )

    enable_3d_touch = models.BooleanField(
        default=True,
        help_text="Whether 3D Touch quick actions are enabled"
    )

    custom_fonts = models.JSONField(
        default=list,
        blank=True,
        help_text="Custom font URLs (iOS-specific)"
    )

    launch_screen_config = models.JSONField(
        default=dict,
        blank=True,
        help_text="Launch screen configuration (colors, images)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "ios_branding_extension"
        verbose_name = "iOS Branding Extension"
        verbose_name_plural = "iOS Branding Extensions"

    def __str__(self):
        return f"iOS Branding: {self.org_slug}"
