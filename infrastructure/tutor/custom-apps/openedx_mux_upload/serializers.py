"""
Mux Upload Serializers

REST API serializers for Mux video upload endpoints.

@spec: video-pipeline-delivery_spec.md (Phase 3)
@covers: AC-VPD-003
"""

from rest_framework import serializers
from .models import MuxUpload


class MuxUploadSerializer(serializers.ModelSerializer):
    """
    Serializer for MuxUpload model.

    Read-only fields: status, asset_id, playback_id (populated by webhooks)
    Write fields: course_key, filename, filesize_bytes, video_title
    """

    user_username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = MuxUpload
        fields = [
            'id',
            'user',
            'user_username',
            'course_key',
            'upload_id',
            'asset_id',
            'playback_id',
            'status',
            'error_message',
            'filename',
            'filesize_bytes',
            'video_title',
            'created_at',
            'updated_at',
            'completed_at',
        ]
        read_only_fields = [
            'id',
            'user',
            'user_username',
            'upload_id',
            'asset_id',
            'playback_id',
            'status',
            'error_message',
            'created_at',
            'updated_at',
            'completed_at',
        ]


class CreateDirectUploadSerializer(serializers.Serializer):
    """
    Request serializer for creating Mux direct upload URLs.

    Input:
        - course_key (str): Course ID where video will be used
        - filename (str, optional): Original filename
        - filesize_bytes (int, optional): File size in bytes
        - video_title (str, optional): Video title for display

    Output:
        - upload_id (str): Mux upload ID
        - upload_url (str): Pre-signed upload URL for browser
        - timeout (int): URL expiry timestamp
        - mux_upload_id (int): Database ID of MuxUpload record
    """

    course_key = serializers.CharField(
        required=True,
        help_text='Course ID where video will be used'
    )

    filename = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text='Original filename from author'
    )

    filesize_bytes = serializers.IntegerField(
        required=False,
        allow_null=True,
        help_text='File size in bytes (if known before upload)'
    )

    video_title = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text='Video title for Studio display'
    )


class MuxWebhookEventSerializer(serializers.Serializer):
    """
    Serializer for Mux webhook event payloads.

    Mux webhook event structure:
    {
        "type": "video.upload.asset_created" | "video.asset.ready" | "video.asset.errored",
        "data": {
            "id": "upload_id or asset_id",
            "status": "asset_created" | "ready" | "errored",
            ...
        }
    }
    """

    type = serializers.CharField(
        help_text='Webhook event type (e.g., video.asset.ready)'
    )

    data = serializers.DictField(
        help_text='Event payload data'
    )
