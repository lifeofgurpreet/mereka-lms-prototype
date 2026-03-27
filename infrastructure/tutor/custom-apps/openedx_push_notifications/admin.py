"""
Django admin interface for push notification device registrations.
"""

from django.contrib import admin

from .models import DeviceRegistration


@admin.register(DeviceRegistration)
class DeviceRegistrationAdmin(admin.ModelAdmin):
    """Admin interface for device registrations."""

    list_display = [
        'id',
        'user',
        'platform',
        'org_slug',
        'is_active',
        'registered_at',
        'last_seen_at',
    ]

    list_filter = [
        'platform',
        'is_active',
        'org_slug',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'device_token',
        'org_slug',
    ]

    readonly_fields = [
        'id',
        'registered_at',
        'last_seen_at',
    ]

    date_hierarchy = 'registered_at'
