import uuid
from django.db import models


class MctVideoMapping(models.Model):
    """Tracks MCT video migration to Mux with OLX mappings."""

    # MCT and Mux identifiers
    mct_video_id = models.CharField(
        max_length=255, unique=True, db_index=True, help_text="Original MCT video ID"
    )
    mux_asset_id = models.CharField(
        max_length=255, unique=True, db_index=True, help_text="Mux asset ID"
    )
    mux_playback_id = models.CharField(
        max_length=255, db_index=True, null=True, blank=True, help_text="Mux playback ID"
    )

    # Open edX course mapping
    olx_usage_key = models.CharField(
        max_length=255,
        db_index=True,
        null=True,
        blank=True,
        help_text="OLX usage key in Open edX course",
    )
    course_key = models.CharField(max_length=255, db_index=True, help_text="Target Open edX course")

    # Video metadata
    original_filename = models.CharField(max_length=512, null=True, blank=True)
    content_language = models.CharField(
        max_length=10,
        null=True,
        blank=True,
        choices=[('en', 'English'), ('vi', 'Vietnamese'), ('id', 'Indonesian')],
    )

    # Mux status and metrics
    MUX_STATUS_CHOICES = [
        ('preparing', 'Preparing'),
        ('ready', 'Ready'),
        ('errored', 'Errored'),
        ('deleted', 'Deleted'),
    ]
    mux_status = models.CharField(max_length=20, choices=MUX_STATUS_CHOICES, default='preparing')
    duration_seconds = models.FloatField(null=True, blank=True, help_text="Video duration in seconds")
    max_resolution = models.CharField(
        max_length=20, null=True, blank=True, help_text="Max resolution (e.g. '1080p')"
    )
    has_audio = models.BooleanField(default=True)
    has_video = models.BooleanField(default=True)

    # Playback verification
    playback_verified = models.BooleanField(
        default=False, help_text="Whether playback health check passed"
    )
    last_health_check = models.DateTimeField(null=True, blank=True)
    health_check_http_status = models.IntegerField(
        null=True, blank=True, help_text="HTTP status of last playback check"
    )

    # Migration tracking
    migration_batch = models.CharField(max_length=100, default='mct-2025-12-29')

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['mux_status', 'created_at']),
            models.Index(fields=['course_key', 'mux_status']),
        ]

    def __str__(self):
        return f"MctVideo({self.mct_video_id} -> {self.mux_asset_id}, {self.mux_status})"


class MigrationReport(models.Model):
    """Tracks overall MCT video migration status and validation results."""

    report_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    generated_at = models.DateTimeField(auto_now_add=True)

    # Migration counts
    total_expected = models.IntegerField(default=503, help_text="Total videos expected from manifest")
    total_found = models.IntegerField(default=0, help_text="Total videos found in Mux")
    total_ready = models.IntegerField(default=0, help_text="Videos with status=ready")
    total_preparing = models.IntegerField(default=0, help_text="Videos with status=preparing")
    total_errored = models.IntegerField(default=0, help_text="Videos with status=errored")
    total_playback_verified = models.IntegerField(
        default=0, help_text="Videos passing playback check"
    )

    # Failure tracking
    failed_asset_ids = models.JSONField(
        default=list, blank=True, help_text="List of asset_ids that failed"
    )

    # Full report data
    report_data = models.JSONField(default=dict, blank=True, help_text="Full report JSON")

    # Completion status
    is_complete = models.BooleanField(
        default=False, help_text="True when total_ready == total_expected"
    )

    class Meta:
        ordering = ['-generated_at']

    def __str__(self):
        return f"MigrationReport({self.report_id}, {self.total_ready}/{self.total_expected} ready)"


# Phase 2: Learner video completion tracking
# Model is defined in completion.py for separation of concerns
# Import it here so Django discovers it during migration
from .completion import VideoCompletionStatus  # noqa: F401, E402
