"""Django admin configuration for Mobile API."""

from django.contrib import admin
from django.utils.html import format_html
from .models import MobileDevice, MobileBrandingConfig, MobileAppVersion
from .ios_auth import PKCEChallenge, MobileToken, APNsNotification
from .ios_offline import OfflineCourse, OfflineVideo, UniversalLinkVerification
from .ios_release import (
    AppStoreMetadata,
    AppStoreScreenshot,
    AppStoreReviewNotes,
    IOSBrandingExtension,
)


@admin.register(MobileDevice)
class MobileDeviceAdmin(admin.ModelAdmin):
    """Admin interface for MobileDevice."""

    list_display = [
        "user",
        "platform_badge",
        "device_name",
        "app_version",
        "os_version",
        "is_active",
        "last_active",
        "created_at",
    ]
    list_filter = ["platform", "is_active", "created_at", "last_active"]
    search_fields = ["user__username", "user__email", "device_token", "device_name"]
    readonly_fields = ["device_token", "created_at", "updated_at", "last_active"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("User Information", {
            "fields": ("user", "device_token")
        }),
        ("Device Information", {
            "fields": ("platform", "device_name", "app_version", "os_version")
        }),
        ("Status", {
            "fields": ("is_active", "last_active")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def platform_badge(self, obj):
        """Display platform with icon."""
        colors = {
            "ios": "#007AFF",
            "android": "#3DDC84",
        }
        icons = {
            "ios": "📱",
            "android": "🤖",
        }
        color = colors.get(obj.platform, "gray")
        icon = icons.get(obj.platform, "📱")
        return format_html(
            '{} <span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            icon,
            color,
            obj.platform.upper()
        )
    platform_badge.short_description = "Platform"


@admin.register(MobileBrandingConfig)
class MobileBrandingConfigAdmin(admin.ModelAdmin):
    """Admin interface for MobileBrandingConfig."""

    list_display = [
        "org_name",
        "org_slug",
        "color_preview",
        "enable_push_notifications",
        "enable_offline_mode",
        "updated_at",
    ]
    list_filter = [
        "enable_dark_mode",
        "enable_push_notifications",
        "enable_offline_mode",
        "updated_at"
    ]
    search_fields = ["org_slug", "org_name"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        ("Organization", {
            "fields": ("org_slug", "org_name")
        }),
        ("Branding Colors", {
            "fields": (
                "primary_color",
                "secondary_color",
                "splash_background_color"
            )
        }),
        ("Logos", {
            "fields": ("logo_url", "logo_square_url")
        }),
        ("Feature Flags", {
            "fields": (
                "enable_dark_mode",
                "enable_push_notifications",
                "enable_offline_mode"
            )
        }),
        ("App Version Compatibility", {
            "fields": ("min_ios_version", "min_android_version")
        }),
        ("Custom Configuration", {
            "fields": ("custom_config",),
            "classes": ("collapse",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def color_preview(self, obj):
        """Display color swatches."""
        return format_html(
            '<span style="display:inline-block;width:20px;height:20px;'
            'background-color:{};border:1px solid #ccc;margin-right:5px;"></span>'
            '<span style="display:inline-block;width:20px;height:20px;'
            'background-color:{};border:1px solid #ccc;"></span>',
            obj.primary_color,
            obj.secondary_color
        )
    color_preview.short_description = "Colors"


@admin.register(MobileAppVersion)
class MobileAppVersionAdmin(admin.ModelAdmin):
    """Admin interface for MobileAppVersion."""

    list_display = [
        "platform_badge",
        "version",
        "min_supported_version",
        "status_badge",
        "force_update",
        "released_at",
    ]
    list_filter = ["platform", "is_deprecated", "force_update", "released_at"]
    search_fields = ["version", "release_notes"]
    readonly_fields = ["created_at", "updated_at"]
    date_hierarchy = "released_at"

    fieldsets = (
        ("Version Information", {
            "fields": ("platform", "version", "min_supported_version")
        }),
        ("Status", {
            "fields": ("is_deprecated", "force_update")
        }),
        ("Release Information", {
            "fields": ("release_notes", "released_at")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def platform_badge(self, obj):
        """Display platform with icon."""
        colors = {
            "ios": "#007AFF",
            "android": "#3DDC84",
        }
        icons = {
            "ios": "📱",
            "android": "🤖",
        }
        color = colors.get(obj.platform, "gray")
        icon = icons.get(obj.platform, "📱")
        return format_html(
            '{} <span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            icon,
            color,
            obj.platform.upper()
        )
    platform_badge.short_description = "Platform"

    def status_badge(self, obj):
        """Display status badge."""
        if obj.is_deprecated:
            return format_html(
                '<span style="background-color: red; color: white; padding: 3px 8px; '
                'border-radius: 3px;">DEPRECATED</span>'
            )
        return format_html(
            '<span style="background-color: green; color: white; padding: 3px 8px; '
            'border-radius: 3px;">ACTIVE</span>'
        )
    status_badge.short_description = "Status"


@admin.register(PKCEChallenge)
class PKCEChallengeAdmin(admin.ModelAdmin):
    """Admin interface for PKCEChallenge."""

    list_display = [
        "state",
        "user",
        "code_challenge_method",
        "expires_at",
        "created_at",
    ]
    list_filter = ["code_challenge_method", "expires_at", "created_at"]
    search_fields = ["state", "user__username"]
    readonly_fields = ["code_verifier", "code_challenge", "state", "created_at"]

    fieldsets = (
        ("PKCE Parameters", {
            "fields": ("code_verifier", "code_challenge", "code_challenge_method", "state")
        }),
        ("User", {
            "fields": ("user",)
        }),
        ("Timestamps", {
            "fields": ("expires_at", "created_at")
        }),
    )


@admin.register(MobileToken)
class MobileTokenAdmin(admin.ModelAdmin):
    """Admin interface for MobileToken."""

    list_display = [
        "user",
        "device_token_preview",
        "is_active",
        "expires_at",
        "refresh_count",
        "last_refreshed_at",
    ]
    list_filter = ["is_active", "created_at", "expires_at"]
    search_fields = ["user__username", "device_token"]
    readonly_fields = ["access_token", "refresh_token", "created_at", "updated_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("User", {
            "fields": ("user", "device_token")
        }),
        ("Tokens", {
            "fields": ("access_token", "refresh_token")
        }),
        ("Expiry", {
            "fields": ("expires_at", "refresh_expires_at")
        }),
        ("Refresh Tracking", {
            "fields": ("last_refreshed_at", "refresh_count")
        }),
        ("Status", {
            "fields": ("is_active",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def device_token_preview(self, obj):
        """Show truncated device token."""
        if obj.device_token:
            return f"{obj.device_token[:20]}..."
        return "-"
    device_token_preview.short_description = "Device Token"


@admin.register(APNsNotification)
class APNsNotificationAdmin(admin.ModelAdmin):
    """Admin interface for APNsNotification."""

    list_display = [
        "notification_type",
        "user",
        "title_preview",
        "delivery_status",
        "sent_at",
        "opened_at",
    ]
    list_filter = ["notification_type", "sent_at", "opened_at"]
    search_fields = ["user__username", "title", "course_id"]
    readonly_fields = ["created_at", "apns_response"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("User & Device", {
            "fields": ("user", "device_token")
        }),
        ("Notification Content", {
            "fields": ("notification_type", "title", "body")
        }),
        ("Deep Link (AC-MOB-012)", {
            "fields": ("deep_link_url", "course_id", "content_id")
        }),
        ("Delivery Tracking", {
            "fields": ("sent_at", "delivered_at", "opened_at", "apns_response")
        }),
        ("Timestamps", {
            "fields": ("created_at",)
        }),
    )

    def title_preview(self, obj):
        """Show truncated title."""
        if len(obj.title) > 50:
            return f"{obj.title[:50]}..."
        return obj.title
    title_preview.short_description = "Title"

    def delivery_status(self, obj):
        """Display delivery status with badge."""
        if obj.opened_at:
            return format_html(
                '<span style="background-color: green; color: white; padding: 3px 8px; '
                'border-radius: 3px;">OPENED</span>'
            )
        elif obj.delivered_at:
            return format_html(
                '<span style="background-color: blue; color: white; padding: 3px 8px; '
                'border-radius: 3px;">DELIVERED</span>'
            )
        elif obj.sent_at:
            return format_html(
                '<span style="background-color: orange; color: white; padding: 3px 8px; '
                'border-radius: 3px;">SENT</span>'
            )
        else:
            return format_html(
                '<span style="background-color: gray; color: white; padding: 3px 8px; '
                'border-radius: 3px;">PENDING</span>'
            )
    delivery_status.short_description = "Status"

# =============================================================================
# Phase 4: Offline Mode Admin (AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019)
# =============================================================================


@admin.register(OfflineCourse)
class OfflineCourseAdmin(admin.ModelAdmin):
    """Admin interface for OfflineCourse."""

    list_display = [
        "user",
        "course_name",
        "status_badge",
        "progress_bar",
        "total_size_mb",
        "download_started_at",
        "download_completed_at",
    ]
    list_filter = ["status", "download_started_at", "download_completed_at"]
    search_fields = ["user__username", "course_id", "course_name"]
    readonly_fields = ["created_at", "updated_at", "download_completed_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("User & Course", {
            "fields": ("user", "course_id", "course_name")
        }),
        ("Download Status", {
            "fields": ("status", "progress_percent", "estimated_time_remaining")
        }),
        ("Size & Progress", {
            "fields": ("total_size_bytes", "downloaded_bytes")
        }),
        ("Content Integrity", {
            "fields": ("content_checksum", "last_sync_at", "expires_at")
        }),
        ("Timestamps", {
            "fields": ("download_started_at", "download_completed_at", "created_at", "updated_at")
        }),
        ("Error Handling", {
            "fields": ("error_message", "retry_count"),
            "classes": ("collapse",)
        }),
    )

    def status_badge(self, obj):
        """Display status with badge."""
        colors = {
            "pending": "gray",
            "downloading": "blue",
            "completed": "green",
            "failed": "red",
            "paused": "orange",
        }
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            colors.get(obj.status, "gray"),
            obj.get_status_display().upper()
        )
    status_badge.short_description = "Status"

    def progress_bar(self, obj):
        """Display progress bar."""
        percent = float(obj.progress_percent)
        return format_html(
            '<div style="width:100px;background:#f0f0f0;border:1px solid #ccc;">'
            '<div style="width:{}%;background:#4CAF50;height:20px;line-height:20px;'
            'color:white;text-align:center;font-size:11px;">{:.1f}%</div></div>',
            percent,
            percent
        )
    progress_bar.short_description = "Progress"

    def total_size_mb(self, obj):
        """Display size in MB."""
        return f"{obj.total_size_bytes / 1024 / 1024:.2f} MB"
    total_size_mb.short_description = "Size"


@admin.register(OfflineVideo)
class OfflineVideoAdmin(admin.ModelAdmin):
    """Admin interface for OfflineVideo."""

    list_display = [
        "video_title",
        "offline_course",
        "resolution",
        "file_size_mb",
        "duration_display",
        "is_downloaded",
        "downloaded_at",
    ]
    list_filter = ["resolution", "is_downloaded", "downloaded_at"]
    search_fields = ["video_id", "video_title", "offline_course__course_name"]
    readonly_fields = ["checksum", "downloaded_at", "created_at", "updated_at"]
    date_hierarchy = "downloaded_at"

    fieldsets = (
        ("Video Information", {
            "fields": ("offline_course", "video_id", "video_title")
        }),
        ("Media Details", {
            "fields": ("video_url", "resolution", "file_size_bytes", "duration_seconds")
        }),
        ("Local Storage", {
            "fields": ("local_file_path", "is_downloaded", "checksum")
        }),
        ("Timestamps", {
            "fields": ("downloaded_at", "created_at", "updated_at")
        }),
    )

    def file_size_mb(self, obj):
        """Display size in MB."""
        return f"{obj.file_size_bytes / 1024 / 1024:.2f} MB"
    file_size_mb.short_description = "Size"

    def duration_display(self, obj):
        """Display duration in mm:ss format."""
        minutes = obj.duration_seconds // 60
        seconds = obj.duration_seconds % 60
        return f"{minutes}:{seconds:02d}"
    duration_display.short_description = "Duration"


@admin.register(UniversalLinkVerification)
class UniversalLinkVerificationAdmin(admin.ModelAdmin):
    """Admin interface for UniversalLinkVerification."""

    list_display = [
        "verification_id",
        "domain",
        "path_preview",
        "status_badge",
        "verified_at",
        "created_at",
    ]
    list_filter = ["domain", "status", "verified_at", "created_at"]
    search_fields = ["verification_id", "domain", "path", "ip_address"]
    readonly_fields = ["verification_id", "created_at", "updated_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("Verification Details", {
            "fields": ("verification_id", "domain", "path", "status")
        }),
        ("Request Information", {
            "fields": ("user_agent", "ip_address")
        }),
        ("Timestamps", {
            "fields": ("verified_at", "created_at", "updated_at")
        }),
        ("Error Information", {
            "fields": ("error_message",),
            "classes": ("collapse",)
        }),
    )

    def path_preview(self, obj):
        """Show truncated path."""
        if len(obj.path) > 50:
            return f"{obj.path[:50]}..."
        return obj.path
    path_preview.short_description = "Path"

    def status_badge(self, obj):
        """Display status with badge."""
        colors = {
            "pending": "gray",
            "verified": "green",
            "failed": "red",
        }
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            colors.get(obj.status, "gray"),
            obj.get_status_display().upper()
        )
    status_badge.short_description = "Status"


# =============================================================================
# Phase 4: App Store Release Admin (AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023)
# =============================================================================


@admin.register(AppStoreMetadata)
class AppStoreMetadataAdmin(admin.ModelAdmin):
    """Admin interface for AppStoreMetadata."""

    list_display = [
        "app_name",
        "language",
        "subtitle",
        "is_active",
        "updated_at",
    ]
    list_filter = ["language", "is_active", "updated_at"]
    search_fields = ["app_name", "subtitle", "description", "keywords"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        ("App Information", {
            "fields": ("language", "app_name", "subtitle")
        }),
        ("Marketing Text", {
            "fields": ("promotional_text", "description", "keywords")
        }),
        ("URLs", {
            "fields": ("marketing_url", "support_url", "privacy_policy_url")
        }),
        ("Version Information", {
            "fields": ("version_whats_new",)
        }),
        ("Status", {
            "fields": ("is_active",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )


@admin.register(AppStoreScreenshot)
class AppStoreScreenshotAdmin(admin.ModelAdmin):
    """Admin interface for AppStoreScreenshot."""

    list_display = [
        "metadata",
        "device_type",
        "display_order",
        "dimensions",
        "caption_preview",
        "is_preview_frame",
    ]
    list_filter = ["device_type", "is_preview_frame"]
    search_fields = ["caption", "metadata__app_name"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        ("Metadata", {
            "fields": ("metadata", "device_type", "display_order")
        }),
        ("Screenshot", {
            "fields": ("screenshot_url", "caption")
        }),
        ("Dimensions", {
            "fields": ("width_pixels", "height_pixels")
        }),
        ("Preview", {
            "fields": ("is_preview_frame",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def dimensions(self, obj):
        """Display dimensions."""
        return f"{obj.width_pixels}×{obj.height_pixels}"
    dimensions.short_description = "Dimensions"

    def caption_preview(self, obj):
        """Show truncated caption."""
        if obj.caption and len(obj.caption) > 30:
            return f"{obj.caption[:30]}..."
        return obj.caption or "-"
    caption_preview.short_description = "Caption"


@admin.register(AppStoreReviewNotes)
class AppStoreReviewNotesAdmin(admin.ModelAdmin):
    """Admin interface for AppStoreReviewNotes."""

    list_display = [
        "version",
        "demo_username",
        "review_status",
        "submitted_at",
        "approved_at",
    ]
    list_filter = ["submitted_at", "approved_at", "requires_idfa", "uses_encryption"]
    search_fields = ["version", "review_notes", "demo_username"]
    readonly_fields = ["created_at", "updated_at"]
    date_hierarchy = "submitted_at"

    fieldsets = (
        ("Version", {
            "fields": ("version",)
        }),
        ("Review Notes", {
            "fields": ("review_notes",)
        }),
        ("Demo Account (for App Review Team)", {
            "fields": ("demo_username", "demo_password", "demo_account_notes")
        }),
        ("Privacy & Compliance", {
            "fields": ("requires_idfa", "uses_encryption", "export_compliance_code")
        }),
        ("Content Rights", {
            "fields": ("content_rights_declaration",),
            "classes": ("collapse",)
        }),
        ("Review Status", {
            "fields": ("submitted_at", "approved_at", "rejection_reason")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def review_status(self, obj):
        """Display review status."""
        if obj.approved_at:
            return format_html(
                '<span style="background-color: green; color: white; padding: 3px 8px; '
                'border-radius: 3px;">APPROVED</span>'
            )
        elif obj.rejection_reason:
            return format_html(
                '<span style="background-color: red; color: white; padding: 3px 8px; '
                'border-radius: 3px;">REJECTED</span>'
            )
        elif obj.submitted_at:
            return format_html(
                '<span style="background-color: blue; color: white; padding: 3px 8px; '
                'border-radius: 3px;">IN REVIEW</span>'
            )
        else:
            return format_html(
                '<span style="background-color: gray; color: white; padding: 3px 8px; '
                'border-radius: 3px;">DRAFT</span>'
            )
    review_status.short_description = "Status"


@admin.register(IOSBrandingExtension)
class IOSBrandingExtensionAdmin(admin.ModelAdmin):
    """Admin interface for IOSBrandingExtension."""

    list_display = [
        "org_slug",
        "color_preview",
        "enable_haptic_feedback",
        "enable_3d_touch",
        "updated_at",
    ]
    list_filter = ["enable_haptic_feedback", "enable_3d_touch", "status_bar_style"]
    search_fields = ["org_slug"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        ("Organization", {
            "fields": ("org_slug",)
        }),
        ("App Icons", {
            "fields": ("app_icon_1024", "app_icon_180", "app_icon_167")
        }),
        ("Splash Screens", {
            "fields": ("splash_screen_portrait", "splash_screen_landscape", "splash_screen_ipad")
        }),
        ("UI Colors", {
            "fields": ("status_bar_style", "tint_color", "navigation_bar_color", "tab_bar_color")
        }),
        ("iOS Features", {
            "fields": ("enable_haptic_feedback", "enable_3d_touch")
        }),
        ("Custom Assets", {
            "fields": ("custom_fonts", "launch_screen_config"),
            "classes": ("collapse",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def color_preview(self, obj):
        """Display color swatches."""
        return format_html(
            '<span style="display:inline-block;width:20px;height:20px;'
            'background-color:{};border:1px solid #ccc;margin-right:5px;"></span>'
            '<span style="display:inline-block;width:20px;height:20px;'
            'background-color:{};border:1px solid #ccc;margin-right:5px;"></span>'
            '<span style="display:inline-block;width:20px;height:20px;'
            'background-color:{};border:1px solid #ccc;"></span>',
            obj.tint_color,
            obj.navigation_bar_color,
            obj.tab_bar_color
        )
    color_preview.short_description = "Colors"
