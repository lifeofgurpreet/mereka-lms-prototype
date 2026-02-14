"""Django admin configuration for Mobile API."""

from django.contrib import admin
from django.utils.html import format_html
from .models import MobileDevice, MobileBrandingConfig, MobileAppVersion


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
