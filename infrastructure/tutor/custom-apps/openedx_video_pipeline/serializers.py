from rest_framework import serializers

from .models import MctVideoMapping, MigrationReport


class MctVideoMappingSerializer(serializers.ModelSerializer):
    """Serializer for MctVideoMapping model."""

    class Meta:
        model = MctVideoMapping
        fields = '__all__'


class MigrationReportSerializer(serializers.ModelSerializer):
    """Serializer for MigrationReport model."""

    class Meta:
        model = MigrationReport
        fields = '__all__'


class PlaybackCheckRequestSerializer(serializers.Serializer):
    """Serializer for playback check API requests."""

    sample_size = serializers.IntegerField(required=False, min_value=1, help_text="Number of videos to sample")
    asset_ids = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        help_text="List of specific asset IDs to check",
    )


class VideoHealthSerializer(serializers.Serializer):
    """Serializer for overall video health status."""

    total_videos = serializers.IntegerField()
    ready_count = serializers.IntegerField()
    preparing_count = serializers.IntegerField()
    errored_count = serializers.IntegerField()
    playback_verified_count = serializers.IntegerField()
    is_migration_complete = serializers.BooleanField()
