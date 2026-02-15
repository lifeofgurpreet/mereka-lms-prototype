"""
iOS offline mode serializers.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019
"""

from rest_framework import serializers
from .ios_offline import OfflineCourse, OfflineVideo, UniversalLinkVerification


class OfflineCourseSerializer(serializers.ModelSerializer):
    """
    Serializer for offline course.

    @covers: AC-MOB-016 - Offline course download tracking
    """

    class Meta:
        model = OfflineCourse
        fields = [
            "id",
            "course_id",
            "course_name",
            "status",
            "total_size_bytes",
            "downloaded_bytes",
            "progress_percent",
            "estimated_time_remaining",
            "content_checksum",
            "last_sync_at",
            "expires_at",
            "download_started_at",
            "download_completed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "progress_percent",
            "content_checksum",
            "download_completed_at",
            "created_at",
            "updated_at",
        ]


class OfflineVideoSerializer(serializers.ModelSerializer):
    """
    Serializer for offline video.

    @covers: AC-MOB-018 - Offline video playback
    """

    class Meta:
        model = OfflineVideo
        fields = [
            "id",
            "video_id",
            "video_title",
            "local_file_path",
            "file_size_bytes",
            "duration_seconds",
            "resolution",
            "is_downloaded",
            "checksum",
            "downloaded_at",
        ]
        read_only_fields = [
            "id",
            "checksum",
            "downloaded_at",
        ]


class UniversalLinkVerificationSerializer(serializers.ModelSerializer):
    """
    Serializer for Universal Link verification.

    @covers: AC-MOB-019 - Universal Links verification
    """

    class Meta:
        model = UniversalLinkVerification
        fields = [
            "verification_id",
            "domain",
            "path",
            "status",
            "verified_at",
            "created_at",
        ]
        read_only_fields = [
            "verification_id",
            "status",
            "verified_at",
            "created_at",
        ]
