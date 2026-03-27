"""
Django admin configuration for email digests and analytics.

@spec: email-notifications-pipeline_spec.md
"""

from django.contrib import admin

from .models import DigestPreference, DigestRun, EmailEvent


@admin.register(DigestPreference)
class DigestPreferenceAdmin(admin.ModelAdmin):
    """Admin for digest preferences."""

    list_display = ['user', 'frequency', 'org_slug', 'user_timezone', 'is_active', 'updated_at']
    list_filter = ['frequency', 'org_slug', 'is_active']
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['id', 'created_at', 'updated_at']
    raw_id_fields = ['user']


@admin.register(DigestRun)
class DigestRunAdmin(admin.ModelAdmin):
    """Admin for digest runs."""

    list_display = [
        'run_id', 'frequency', 'status', 'org_slug',
        'total_users', 'emails_sent', 'emails_failed',
        'started_at', 'completed_at',
    ]
    list_filter = ['frequency', 'status', 'org_slug']
    search_fields = ['run_id']
    readonly_fields = [
        'id', 'started_at', 'completed_at',
        'total_users', 'emails_sent', 'emails_skipped', 'emails_failed',
        'created_at',
    ]


@admin.register(EmailEvent)
class EmailEventAdmin(admin.ModelAdmin):
    """Admin for email events."""

    list_display = [
        'event_type', 'message_id', 'template_category',
        'org_slug', 'timestamp',
    ]
    list_filter = ['event_type', 'org_slug', 'template_category']
    search_fields = ['message_id', 'tracking_id']
    readonly_fields = ['id', 'created_at']
    raw_id_fields = ['user']
    date_hierarchy = 'timestamp'
