"""
Mux Upload Django Admin

Admin interface for managing Mux video uploads.

@spec: video-pipeline-delivery_spec.md (Phase 3)
"""

from django.contrib import admin
from .models import MuxUpload


@admin.register(MuxUpload)
class MuxUploadAdmin(admin.ModelAdmin):
    """
    Django admin for MuxUpload model.

    Features:
    - List view with filters by status, course, user
    - Search by upload_id, asset_id, playback_id
    - Read-only view of webhook payloads
    - Upload statistics in admin dashboard
    """

    list_display = [
        'upload_id',
        'user',
        'course_key',
        'status',
        'video_title',
        'created_at',
        'completed_at',
    ]

    list_filter = [
        'status',
        'created_at',
        'updated_at',
    ]

    search_fields = [
        'upload_id',
        'asset_id',
        'playback_id',
        'user__username',
        'user__email',
        'video_title',
        'filename',
    ]

    readonly_fields = [
        'upload_id',
        'asset_id',
        'playback_id',
        'status',
        'error_message',
        'created_at',
        'updated_at',
        'completed_at',
        'webhook_payload',
    ]

    fieldsets = [
        ('Upload Information', {
            'fields': [
                'user',
                'course_key',
                'upload_id',
                'asset_id',
                'playback_id',
            ]
        }),
        ('Status', {
            'fields': [
                'status',
                'error_message',
            ]
        }),
        ('Video Metadata', {
            'fields': [
                'filename',
                'filesize_bytes',
                'video_title',
            ]
        }),
        ('Timestamps', {
            'fields': [
                'created_at',
                'updated_at',
                'completed_at',
            ]
        }),
        ('Debug Information', {
            'fields': [
                'webhook_payload',
            ],
            'classes': ['collapse'],
        }),
    ]

    def has_add_permission(self, request):
        """
        Disable manual creation of uploads via admin.
        Uploads must be created through the API.
        """
        return False

    def has_delete_permission(self, request, obj=None):
        """
        Allow deletion for cleanup purposes.
        """
        return True
