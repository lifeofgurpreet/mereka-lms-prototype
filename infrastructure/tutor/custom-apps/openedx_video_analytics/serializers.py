"""
Video Analytics Serializers

REST API serializers for video playback events and analytics.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

from rest_framework import serializers
from .models import VideoPlaybackEvent, VideoAnalyticsSummary


class VideoPlaybackEventSerializer(serializers.ModelSerializer):
    """
    Serializer for VideoPlaybackEvent model.
    """

    class Meta:
        model = VideoPlaybackEvent
        fields = [
            'id',
            'user',
            'course_key',
            'video_id',
            'event_type',
            'position',
            'duration',
            'timestamp',
            'org_slug',
            'session_id',
        ]
        read_only_fields = ['id', 'user', 'timestamp']


class RecordVideoEventSerializer(serializers.Serializer):
    """
    Request serializer for recording video playback events.

    Input:
        - course_key (str): Course ID
        - video_id (str): Video identifier (playback_id or usage_key)
        - event_type (str): played, paused, seeked, completed, ended
        - position (float): Playback position in seconds
        - duration (float, optional): Total video duration in seconds
        - session_id (str, optional): Session identifier
    """

    course_key = serializers.CharField(
        required=True,
        help_text='Course ID where video is located'
    )

    video_id = serializers.CharField(
        required=True,
        help_text='Video identifier (Mux playback_id or XBlock usage_key)'
    )

    event_type = serializers.ChoiceField(
        choices=['played', 'paused', 'seeked', 'completed', 'ended'],
        required=True,
        help_text='Type of playback event'
    )

    position = serializers.FloatField(
        required=True,
        min_value=0.0,
        help_text='Playback position in seconds'
    )

    duration = serializers.FloatField(
        required=False,
        allow_null=True,
        min_value=0.0,
        help_text='Total video duration in seconds (if known)'
    )

    session_id = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=100,
        help_text='Session identifier for grouping events'
    )


class VideoAnalyticsSummarySerializer(serializers.ModelSerializer):
    """
    Serializer for VideoAnalyticsSummary (aggregated metrics).
    """

    completion_rate_percent = serializers.SerializerMethodField()

    class Meta:
        model = VideoAnalyticsSummary
        fields = [
            'course_key',
            'video_id',
            'org_slug',
            'date',
            'play_count',
            'unique_viewers',
            'completion_count',
            'completion_rate',
            'completion_rate_percent',
            'avg_watch_time',
            'total_watch_time',
            'avg_position_reached',
        ]

    def get_completion_rate_percent(self, obj):
        """
        Return completion rate as percentage (0-100).
        """
        return round(obj.completion_rate * 100, 1)


class VideoAnalyticsQuerySerializer(serializers.Serializer):
    """
    Query parameter serializer for analytics API.

    Filters:
        - course_key (str, optional): Filter by course
        - video_id (str, optional): Filter by video
        - start_date (date, optional): Filter from date (YYYY-MM-DD)
        - end_date (date, optional): Filter to date (YYYY-MM-DD)
        - org_slug (str, optional): Filter by organization
    """

    course_key = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text='Course ID to filter by'
    )

    video_id = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text='Video ID to filter by'
    )

    start_date = serializers.DateField(
        required=False,
        allow_null=True,
        help_text='Start date for analytics range (YYYY-MM-DD)'
    )

    end_date = serializers.DateField(
        required=False,
        allow_null=True,
        help_text='End date for analytics range (YYYY-MM-DD)'
    )

    org_slug = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text='Organization slug to filter by'
    )
