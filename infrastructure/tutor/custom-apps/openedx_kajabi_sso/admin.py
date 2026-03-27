"""
Django admin interface for Kajabi SSO models.
"""

from django.contrib import admin
from django.utils.html import format_html
from .models import KajabiSsoLink, KajabiImportBatch


@admin.register(KajabiSsoLink)
class KajabiSsoLinkAdmin(admin.ModelAdmin):
    """Admin interface for Kajabi SSO links."""

    list_display = [
        'user',
        'kajabi_email',
        'is_active',
        'welcome_email_status',
        'last_login_display',
        'sso_failures_count',
        'migrated_at',
    ]

    list_filter = [
        'is_active',
        'welcome_email_sent',
        'sso_provider',
        'migrated_at',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'kajabi_email',
        'kajabi_user_id',
    ]

    readonly_fields = [
        'id',
        'migrated_at',
        'created_at',
        'updated_at',
        'last_sso_login_at',
        'welcome_email_sent_at',
    ]

    fieldsets = [
        ('User Information', {
            'fields': ['user', 'kajabi_email', 'kajabi_user_id']
        }),
        ('SSO Configuration', {
            'fields': ['sso_provider', 'is_active']
        }),
        ('Welcome Email', {
            'fields': ['welcome_email_sent', 'welcome_email_sent_at']
        }),
        ('Authentication Tracking', {
            'fields': ['last_sso_login_at', 'sso_failures_count']
        }),
        ('Timestamps', {
            'fields': ['migrated_at', 'created_at', 'updated_at'],
            'classes': ['collapse'],
        }),
    ]

    def welcome_email_status(self, obj):
        """Display welcome email status with color coding."""
        if obj.welcome_email_sent:
            return format_html(
                '<span style="color: green;">✓ Sent</span>'
            )
        return format_html(
            '<span style="color: orange;">✗ Not Sent</span>'
        )
    welcome_email_status.short_description = 'Welcome Email'

    def last_login_display(self, obj):
        """Display last SSO login timestamp."""
        if obj.last_sso_login_at:
            return obj.last_sso_login_at.strftime('%Y-%m-%d %H:%M')
        return '—'
    last_login_display.short_description = 'Last SSO Login'


@admin.register(KajabiImportBatch)
class KajabiImportBatchAdmin(admin.ModelAdmin):
    """Admin interface for Kajabi import batches."""

    list_display = [
        'csv_filename',
        'status_display',
        'total_rows',
        'created_count',
        'linked_count',
        'skipped_count',
        'error_count',
        'imported_by',
        'created_at',
    ]

    list_filter = [
        'status',
        'created_at',
        'imported_by',
    ]

    search_fields = [
        'csv_filename',
        'imported_by__username',
    ]

    readonly_fields = [
        'id',
        'csv_filename',
        'total_rows',
        'created_count',
        'linked_count',
        'skipped_count',
        'error_count',
        'status',
        'imported_by',
        'started_at',
        'completed_at',
        'created_at',
        'errors_display',
    ]

    fieldsets = [
        ('Import Information', {
            'fields': ['csv_filename', 'imported_by', 'status']
        }),
        ('Statistics', {
            'fields': [
                'total_rows',
                'created_count',
                'linked_count',
                'skipped_count',
                'error_count',
            ]
        }),
        ('Timestamps', {
            'fields': ['created_at', 'started_at', 'completed_at']
        }),
        ('Errors', {
            'fields': ['errors_display'],
            'classes': ['collapse'],
        }),
    ]

    def status_display(self, obj):
        """Display status with color coding."""
        colors = {
            'pending': 'gray',
            'in_progress': 'blue',
            'completed': 'green',
            'failed': 'red',
        }
        color = colors.get(obj.status, 'black')
        return format_html(
            '<span style="color: {};">{}</span>',
            color,
            obj.get_status_display()
        )
    status_display.short_description = 'Status'

    def errors_display(self, obj):
        """Display errors in a readable format."""
        if not obj.errors_json:
            return "No errors"

        errors_html = "<ul>"
        for error in obj.errors_json[:50]:  # Limit to first 50 errors
            row = error.get('row', 'N/A')
            message = error.get('error', 'Unknown error')
            errors_html += f"<li><strong>Row {row}:</strong> {message}</li>"
        errors_html += "</ul>"

        if len(obj.errors_json) > 50:
            errors_html += f"<p><em>... and {len(obj.errors_json) - 50} more errors</em></p>"

        return format_html(errors_html)
    errors_display.short_description = 'Import Errors'

    def has_add_permission(self, request):
        """Disable manual creation of import batches (should be created via management command)."""
        return False

    def has_delete_permission(self, request, obj=None):
        """Allow deletion of old import batches for cleanup."""
        return True
