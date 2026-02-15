"""
iOS App Store release serializers.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023
"""

from rest_framework import serializers
from .ios_release import (
    AppStoreMetadata,
    AppStoreScreenshot,
    AppStoreReviewNotes,
    IOSBrandingExtension,
)


class AppStoreMetadataSerializer(serializers.ModelSerializer):
    """
    Serializer for App Store metadata.

    @covers: AC-MOB-020 - App Store metadata
    """

    class Meta:
        model = AppStoreMetadata
        fields = [
            "language",
            "app_name",
            "subtitle",
            "promotional_text",
            "description",
            "keywords",
            "marketing_url",
            "support_url",
            "privacy_policy_url",
            "version_whats_new",
        ]


class AppStoreScreenshotSerializer(serializers.ModelSerializer):
    """
    Serializer for App Store screenshots.

    @covers: AC-MOB-021 - Screenshots and preview media
    """

    class Meta:
        model = AppStoreScreenshot
        fields = [
            "device_type",
            "screenshot_url",
            "display_order",
            "caption",
            "width_pixels",
            "height_pixels",
            "is_preview_frame",
        ]


class AppStoreReviewNotesSerializer(serializers.ModelSerializer):
    """
    Serializer for App Store review notes.

    @covers: AC-MOB-022 - Review notes (staff only)
    """

    class Meta:
        model = AppStoreReviewNotes
        fields = [
            "version",
            "review_notes",
            "demo_username",
            "demo_password",
            "demo_account_notes",
            "requires_idfa",
            "uses_encryption",
            "export_compliance_code",
            "content_rights_declaration",
            "submitted_at",
            "approved_at",
            "rejection_reason",
        ]
        # NOTE: demo_password is included but should be encrypted in production


class IOSBrandingExtensionSerializer(serializers.ModelSerializer):
    """
    Serializer for iOS-specific branding.

    @covers: AC-MOB-023 - iOS multi-tenant branding
    """

    class Meta:
        model = IOSBrandingExtension
        fields = [
            "org_slug",
            "app_icon_1024",
            "app_icon_180",
            "app_icon_167",
            "splash_screen_portrait",
            "splash_screen_landscape",
            "splash_screen_ipad",
            "status_bar_style",
            "tint_color",
            "navigation_bar_color",
            "tab_bar_color",
            "enable_haptic_feedback",
            "enable_3d_touch",
            "custom_fonts",
            "launch_screen_config",
        ]
