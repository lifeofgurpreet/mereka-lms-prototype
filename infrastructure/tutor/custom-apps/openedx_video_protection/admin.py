"""Django admin for Video Content Protection"""
from django.contrib import admin
from django.utils.html import format_html

from .models import SignedPlaybackToken, VideoAccessLog


@admin.register(SignedPlaybackToken)
class SignedPlaybackTokenAdmin(admin.ModelAdmin):
    """Admin interface for SignedPlaybackToken model"""

    list_display = [
        'user',
        'video_id',
        'course_key',
        'created_at',
        'expires_at',
        'is_expired_badge',
        'org_slug',
    ]
    list_filter = ['created_at', 'expires_at', 'org_slug']
    search_fields = ['user__username', 'video_id', 'course_key', 'org_slug']
    readonly_fields = ['user', 'course_key', 'video_id', 'token', 'created_at', 'expires_at']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']

    fieldsets = [
        (
            'Token Info',
            {
                'fields': ['user', 'course_key', 'video_id', 'org_slug'],
            },
        ),
        (
            'Token Data',
            {
                'fields': ['token', 'expires_at', 'created_at'],
            },
        ),
        (
            'Privacy',
            {
                'fields': ['ip_address_hash', 'user_agent'],
            },
        ),
    ]

    def is_expired_badge(self, obj):
        """Show colored badge for expired status"""
        if obj.is_expired:
            return format_html('<span style="color: red;">Expired</span>')
        return format_html('<span style="color: green;">Valid</span>')

    is_expired_badge.short_description = 'Status'

    def has_add_permission(self, request):
        """Disable manual token creation in admin"""
        return False


@admin.register(VideoAccessLog)
class VideoAccessLogAdmin(admin.ModelAdmin):
    """Admin interface for VideoAccessLog model"""

    list_display = [
        'user',
        'video_id',
        'course_key',
        'status_badge',
        'denial_reason',
        'timestamp',
        'org_slug',
    ]
    list_filter = ['status', 'denial_reason', 'timestamp', 'org_slug']
    search_fields = ['user__username', 'video_id', 'course_key', 'org_slug']
    readonly_fields = [
        'user',
        'course_key',
        'video_id',
        'status',
        'denial_reason',
        'timestamp',
        'ip_address_hash',
        'org_slug',
    ]
    date_hierarchy = 'timestamp'
    ordering = ['-timestamp']

    fieldsets = [
        (
            'Access Info',
            {
                'fields': ['user', 'course_key', 'video_id', 'org_slug'],
            },
        ),
        (
            'Access Decision',
            {
                'fields': ['status', 'denial_reason', 'timestamp'],
            },
        ),
        (
            'Privacy',
            {
                'fields': ['ip_address_hash'],
            },
        ),
    ]

    def status_badge(self, obj):
        """Show colored badge for access status"""
        if obj.status == VideoAccessLog.ACCESS_GRANTED:
            return format_html('<span style="color: green;">✓ Granted</span>')
        return format_html('<span style="color: red;">✗ Denied</span>')

    status_badge.short_description = 'Status'

    def has_add_permission(self, request):
        """Disable manual log creation in admin"""
        return False

    def has_delete_permission(self, request, obj=None):
        """Disable deletion of access logs (audit trail)"""
        return False
