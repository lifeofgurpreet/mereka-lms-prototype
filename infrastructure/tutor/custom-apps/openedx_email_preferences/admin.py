"""
Django admin interface for email preferences.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
"""

from django.contrib import admin
from .models import UserEmailPreference, ConsentRecord


@admin.register(UserEmailPreference)
class UserEmailPreferenceAdmin(admin.ModelAdmin):
    """Admin interface for email preferences."""

    list_display = [
        'user',
        'category',
        'opted_in',
        'consent_version',
        'created_at',
        'updated_at',
    ]

    list_filter = [
        'category',
        'opted_in',
        'consent_version',
        'created_at',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'category',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    fieldsets = (
        ('User & Category', {
            'fields': ('user', 'category')
        }),
        ('Preference', {
            'fields': ('opted_in', 'consent_version')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )

    date_hierarchy = 'created_at'


@admin.register(ConsentRecord)
class ConsentRecordAdmin(admin.ModelAdmin):
    """Admin interface for consent records (read-only, immutable)."""

    list_display = [
        'user',
        'category',
        'old_value',
        'new_value',
        'consent_version',
        'source',
        'timestamp',
    ]

    list_filter = [
        'category',
        'source',
        'timestamp',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'category',
    ]

    readonly_fields = [
        'user',
        'category',
        'old_value',
        'new_value',
        'consent_version',
        'ip_address_hash',
        'source',
        'timestamp',
    ]

    fieldsets = (
        ('User & Category', {
            'fields': ('user', 'category')
        }),
        ('Change', {
            'fields': ('old_value', 'new_value', 'consent_version')
        }),
        ('Audit Trail', {
            'fields': ('source', 'ip_address_hash', 'timestamp')
        }),
    )

    date_hierarchy = 'timestamp'

    def has_add_permission(self, request):
        """Disable manual creation (records created automatically)."""
        return False

    def has_delete_permission(self, request, obj=None):
        """Disable deletion (immutable audit trail)."""
        return False
