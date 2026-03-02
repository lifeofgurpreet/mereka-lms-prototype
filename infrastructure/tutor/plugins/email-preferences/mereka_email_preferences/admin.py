"""
Django admin configuration for email preferences.
"""

from django.contrib import admin

from .models import NotificationPreference, PreferenceAuditLog


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
    list_display = ("user_id", "message_type", "channel", "enabled", "updated_at")
    list_filter = ("message_type", "channel", "enabled")
    search_fields = ("user_id",)
    readonly_fields = ("updated_at",)
    ordering = ("-updated_at",)

    fieldsets = (
        (None, {"fields": ("user_id", "message_type", "channel", "enabled")}),
        ("Consent", {"fields": ("consent_version",)}),
        ("Timestamps", {"fields": ("updated_at",), "classes": ("collapse",)}),
    )


@admin.register(PreferenceAuditLog)
class PreferenceAuditLogAdmin(admin.ModelAdmin):
    list_display = (
        "user_id",
        "message_type",
        "channel",
        "old_value",
        "new_value",
        "change_source",
        "timestamp",
    )
    list_filter = ("message_type", "channel", "change_source", "timestamp")
    search_fields = ("user_id",)
    readonly_fields = (
        "user_id",
        "message_type",
        "channel",
        "old_value",
        "new_value",
        "consent_version",
        "ip_address_hash",
        "timestamp",
        "change_source",
    )
    ordering = ("-timestamp",)

    # Audit logs are read-only
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    fieldsets = (
        ("User", {"fields": ("user_id",)}),
        ("Preference Change", {"fields": ("message_type", "channel", "old_value", "new_value")}),
        (
            "Metadata",
            {"fields": ("change_source", "consent_version", "ip_address_hash", "timestamp")},
        ),
    )
