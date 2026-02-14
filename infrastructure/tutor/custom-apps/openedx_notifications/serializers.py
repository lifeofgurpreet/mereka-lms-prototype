"""
DRF serializers for notification API.

@spec: email-notifications-pipeline_spec.md
"""

from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for notification objects."""

    class Meta:
        model = Notification
        fields = [
            'id',
            'message_type',
            'title',
            'body',
            'course_id',
            'org_slug',
            'deep_link_url',
            'read',
            'created_at',
            'expires_at',
        ]
        read_only_fields = [
            'id',
            'message_type',
            'title',
            'body',
            'course_id',
            'org_slug',
            'deep_link_url',
            'created_at',
            'expires_at',
        ]


class UnreadCountSerializer(serializers.Serializer):
    """Serializer for unread count response."""

    unread_count = serializers.IntegerField()
