"""Serializers for Video Content Protection API"""
from rest_framework import serializers


class SignedPlaybackURLRequestSerializer(serializers.Serializer):
    """Request serializer for generating signed playback URLs"""

    playback_id = serializers.CharField(
        max_length=255,
        required=True,
        help_text='Mux playback ID (e.g., "abcd1234efgh5678")',
    )
    course_key = serializers.CharField(
        max_length=255,
        required=True,
        help_text='Course key (e.g., "course-v1:MerekaAcademy+COURSE101+2024")',
    )
    expiry_hours = serializers.IntegerField(
        required=False,
        default=12,
        min_value=1,
        max_value=72,
        help_text='Token validity in hours (1-72, default: 12)',
    )


class SignedPlaybackURLResponseSerializer(serializers.Serializer):
    """Response serializer for signed playback URLs"""

    url = serializers.CharField(
        help_text='Signed playback URL (HLS .m3u8 with JWT token)',
    )
    expires_at = serializers.CharField(
        help_text='Token expiration timestamp (ISO 8601 format)',
    )
    playback_id = serializers.CharField(
        help_text='Mux playback ID',
    )
