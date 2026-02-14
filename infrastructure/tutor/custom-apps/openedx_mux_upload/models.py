"""
Mux Upload Models

Tracks Mux video uploads from Open edX Studio.

@spec: video-pipeline-delivery_spec.md (Phase 3)
@covers: AC-VPD-003, AC-VPD-004
"""

from django.db import models
from django.conf import settings
from django.utils import timezone
from opaque_keys.edx.django.models import CourseKeyField
import logging

logger = logging.getLogger(__name__)

UPLOAD_STATUS_CHOICES = [
    ('pending', 'Pending Upload'),
    ('uploading', 'Uploading'),
    ('processing', 'Processing'),
    ('ready', 'Ready'),
    ('errored', 'Errored'),
]


class MuxUpload(models.Model):
    """
    Tracks Mux direct uploads from Studio authors.

    Lifecycle:
    1. Studio author initiates upload → status=pending, upload_url generated
    2. Browser uploads to Mux → status=uploading
    3. Mux processes video → status=processing
    4. Mux webhook fires asset.ready → status=ready, asset_id & playback_id populated
    5. If error occurs → status=errored
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='mux_uploads',
        db_index=True,
        help_text='Course author who initiated the upload'
    )

    course_key = CourseKeyField(
        max_length=255,
        db_index=True,
        help_text='Course where video will be used'
    )

    # Mux identifiers
    upload_id = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text='Mux direct upload ID (from POST /video/v1/uploads)'
    )

    asset_id = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_index=True,
        help_text='Mux asset ID (populated after upload completes)'
    )

    playback_id = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        db_index=True,
        help_text='Mux playback ID for HLS streaming'
    )

    # Upload status tracking
    status = models.CharField(
        max_length=20,
        choices=UPLOAD_STATUS_CHOICES,
        default='pending',
        db_index=True,
        help_text='Current upload/processing status'
    )

    error_message = models.TextField(
        null=True,
        blank=True,
        help_text='Error details if status=errored'
    )

    # Metadata
    filename = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        help_text='Original filename from author'
    )

    filesize_bytes = models.BigIntegerField(
        null=True,
        blank=True,
        help_text='File size in bytes (if known before upload)'
    )

    video_title = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        help_text='Video title for Studio display'
    )

    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text='When upload was initiated'
    )

    updated_at = models.DateTimeField(
        auto_now=True,
        help_text='Last status update'
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text='When upload reached ready or errored status'
    )

    # Webhook data (for debugging)
    webhook_payload = models.JSONField(
        null=True,
        blank=True,
        help_text='Last webhook payload from Mux (for troubleshooting)'
    )

    class Meta:
        verbose_name = 'Mux Video Upload'
        verbose_name_plural = 'Mux Video Uploads'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'course_key']),
            models.Index(fields=['status', 'created_at']),
            models.Index(fields=['upload_id']),
            models.Index(fields=['asset_id']),
        ]

    def __str__(self):
        return f"MuxUpload({self.upload_id}, status={self.status}, course={self.course_key})"

    def mark_ready(self, asset_id, playback_id):
        """
        Mark upload as ready after Mux webhook asset.ready event.

        Args:
            asset_id (str): Mux asset ID
            playback_id (str): Mux playback ID for HLS
        """
        self.status = 'ready'
        self.asset_id = asset_id
        self.playback_id = playback_id
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'asset_id', 'playback_id', 'completed_at', 'updated_at'])

        logger.info(
            f"Mux upload marked ready: upload_id={self.upload_id}, "
            f"asset_id={asset_id}, playback_id={playback_id}"
        )

    def mark_errored(self, error_message):
        """
        Mark upload as errored after Mux webhook asset.errored event.

        Args:
            error_message (str): Error details from Mux
        """
        self.status = 'errored'
        self.error_message = error_message
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'error_message', 'completed_at', 'updated_at'])

        logger.error(
            f"Mux upload errored: upload_id={self.upload_id}, "
            f"error={error_message}"
        )

    @classmethod
    def get_upload_stats(cls, course_key=None):
        """
        Get upload statistics for monitoring.

        Args:
            course_key (CourseKey, optional): Filter by course

        Returns:
            dict: Upload counts by status
        """
        queryset = cls.objects.all()
        if course_key:
            queryset = queryset.filter(course_key=course_key)

        stats = {
            'total': queryset.count(),
            'pending': queryset.filter(status='pending').count(),
            'uploading': queryset.filter(status='uploading').count(),
            'processing': queryset.filter(status='processing').count(),
            'ready': queryset.filter(status='ready').count(),
            'errored': queryset.filter(status='errored').count(),
        }

        return stats
