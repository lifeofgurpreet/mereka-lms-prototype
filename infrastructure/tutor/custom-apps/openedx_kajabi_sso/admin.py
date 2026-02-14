"""Django admin configuration for Kajabi SSO."""

from django.contrib import admin
from django.utils.html import format_html
from .models import KajabiSSOUser, KajabiImportLog, KajabiImportRecord


@admin.register(KajabiSSOUser)
class KajabiSSOUserAdmin(admin.ModelAdmin):
    """Admin interface for KajabiSSOUser."""

    list_display = [
        "user",
        "kajabi_email",
        "sso_enabled",
        "fallback_to_password",
        "welcome_email_status",
        "last_sso_login",
        "created_at",
    ]
    list_filter = ["sso_enabled", "fallback_to_password", "welcome_email_sent", "created_at"]
    search_fields = ["user__username", "user__email", "kajabi_email", "kajabi_user_id"]
    readonly_fields = ["created_at", "updated_at", "welcome_email_sent_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("User Information", {
            "fields": ("user", "kajabi_user_id", "kajabi_email")
        }),
        ("SSO Settings", {
            "fields": ("sso_enabled", "fallback_to_password", "last_sso_login")
        }),
        ("Welcome Email", {
            "fields": ("welcome_email_sent", "welcome_email_sent_at")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def welcome_email_status(self, obj):
        """Display welcome email status with icon."""
        if obj.welcome_email_sent:
            return format_html(
                '<span style="color: green;">✓ Sent</span>'
            )
        return format_html(
            '<span style="color: orange;">⊘ Not sent</span>'
        )
    welcome_email_status.short_description = "Welcome Email"


@admin.register(KajabiImportLog)
class KajabiImportLogAdmin(admin.ModelAdmin):
    """Admin interface for KajabiImportLog."""

    list_display = [
        "import_id",
        "filename",
        "status_badge",
        "total_rows",
        "created_users",
        "linked_users",
        "skipped_duplicates",
        "errors",
        "welcome_emails_sent",
        "started_at",
        "completed_at",
    ]
    list_filter = ["status", "started_at", "completed_at"]
    search_fields = ["import_id", "filename"]
    readonly_fields = [
        "import_id",
        "started_at",
        "completed_at",
        "created_at",
    ]
    date_hierarchy = "created_at"

    fieldsets = (
        ("Import Information", {
            "fields": ("import_id", "filename", "status")
        }),
        ("Statistics", {
            "fields": (
                "total_rows",
                "created_users",
                "linked_users",
                "skipped_duplicates",
                "errors",
                "welcome_emails_sent",
            )
        }),
        ("Error Log", {
            "fields": ("error_log",),
            "classes": ("collapse",)
        }),
        ("Timestamps", {
            "fields": ("started_at", "completed_at", "created_at")
        }),
    )

    def status_badge(self, obj):
        """Display status with color badge."""
        colors = {
            "pending": "gray",
            "processing": "blue",
            "completed": "green",
            "failed": "red",
        }
        color = colors.get(obj.status, "gray")
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            color,
            obj.status.upper()
        )
    status_badge.short_description = "Status"


@admin.register(KajabiImportRecord)
class KajabiImportRecordAdmin(admin.ModelAdmin):
    """Admin interface for KajabiImportRecord."""

    list_display = [
        "row_number",
        "import_log",
        "email",
        "username",
        "operation_badge",
        "user_link",
        "created_at",
    ]
    list_filter = ["operation", "import_log", "created_at"]
    search_fields = ["email", "username", "kajabi_user_id", "import_log__import_id"]
    readonly_fields = ["created_at"]
    date_hierarchy = "created_at"

    fieldsets = (
        ("Import Information", {
            "fields": ("import_log", "row_number")
        }),
        ("User Data", {
            "fields": ("kajabi_user_id", "email", "username", "user")
        }),
        ("Operation", {
            "fields": ("operation", "error_message")
        }),
        ("Timestamps", {
            "fields": ("created_at",)
        }),
    )

    def operation_badge(self, obj):
        """Display operation with color badge."""
        colors = {
            "create": "green",
            "link": "blue",
            "skip_duplicate": "orange",
            "error": "red",
        }
        color = colors.get(obj.operation, "gray")
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px;">{}</span>',
            color,
            obj.operation.upper()
        )
    operation_badge.short_description = "Operation"

    def user_link(self, obj):
        """Link to user in admin."""
        if obj.user:
            return format_html(
                '<a href="/admin/auth/user/{}/change/">{}</a>',
                obj.user.id,
                obj.user.username
            )
        return "-"
    user_link.short_description = "User"
