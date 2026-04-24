"""
Django admin interface for notifications.

@spec: email-notifications-pipeline_spec.md
"""

from django.contrib import admin
from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    """Admin interface for notifications."""

    list_display = [
        'id',
        'user',
        'message_type',
        'title',
        'org_slug',
        'read',
        'created_at',
        'expires_at',
    ]

    list_filter = [
        'message_type',
        'read',
        'org_slug',
        'created_at',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'title',
        'body',
        'org_slug',
    ]

    readonly_fields = [
        'id',
        'created_at',
    ]

    fieldsets = (
        ('Notification', {
            'fields': ('id', 'user', 'message_type', 'title', 'body')
        }),
        ('Context', {
            'fields': ('course_id', 'org_slug', 'deep_link_url')
        }),
        ('State', {
            'fields': ('read', 'created_at', 'expires_at')
        }),
    )

    date_hierarchy = 'created_at'

    def has_add_permission(self, request):
        """Disable manual creation (notifications come from ACE)."""
        return False
