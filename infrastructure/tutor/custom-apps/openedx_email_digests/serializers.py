"""
DRF serializers for email digests and analytics.

@spec: email-notifications-pipeline_spec.md
"""

from rest_framework import serializers

from .models import DigestPreference, DigestRun, EmailEvent


class DigestPreferenceSerializer(serializers.ModelSerializer):
    """Serializer for digest preferences."""

    class Meta:
        model = DigestPreference
        fields = [
            'id', 'frequency', 'org_slug', 'message_types',
            'user_timezone', 'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class DigestRunSerializer(serializers.ModelSerializer):
    """Serializer for digest run records."""

    class Meta:
        model = DigestRun
        fields = [
            'id', 'run_id', 'frequency', 'period_start', 'period_end',
            'org_slug', 'status', 'total_users', 'emails_sent',
            'emails_skipped', 'emails_failed', 'started_at', 'completed_at',
            'error_message', 'created_at',
        ]


class EmailEventSerializer(serializers.ModelSerializer):
    """Serializer for email events."""

    class Meta:
        model = EmailEvent
        fields = [
            'id', 'message_id', 'event_type', 'user', 'campaign_id',
            'template_category', 'org_slug', 'tracking_id', 'url',
            'bounce_type', 'timestamp', 'created_at',
        ]


class EmailAnalyticsQuerySerializer(serializers.Serializer):
    """Serializer for analytics query parameters."""

    org_slug = serializers.CharField(required=True)
    template = serializers.CharField(required=False)
    campaign_id = serializers.UUIDField(required=False)
    days = serializers.IntegerField(required=False, default=30, min_value=1, max_value=365)
