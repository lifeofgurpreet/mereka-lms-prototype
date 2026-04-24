"""
iOS offline mode models and utilities.

@spec: Mobile Phase 4 - iOS Release (mereka-lms-39ty)
@covers: AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019
"""

import hashlib
from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class OfflineCourse(models.Model):
    """
    Course downloaded for offline viewing.

    @covers: AC-MOB-016 - Offline course download tracking
    @covers: AC-MOB-017 - Background download support
    """

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("downloading", "Downloading"),
        ("completed", "Completed"),
        ("failed", "Failed"),
        ("paused", "Paused"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="offline_courses",
        help_text="User who downloaded this course"
    )

    course_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Open edX course ID (e.g., course-v1:Org+Course+Run)"
    )

    course_name = models.CharField(
        max_length=255,
        help_text="Course display name"
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending",
        help_text="Download status"
    )

    total_size_bytes = models.BigIntegerField(
        default=0,
        help_text="Total download size in bytes"
    )

    downloaded_bytes = models.BigIntegerField(
        default=0,
        help_text="Bytes downloaded so far"
    )

    progress_percent = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0.00,
        help_text="Download progress percentage (0-100)"
    )

    estimated_time_remaining = models.IntegerField(
        null=True,
        blank=True,
        help_text="Estimated seconds remaining (null if unknown)"
    )

    content_checksum = models.CharField(
        max_length=64,
        blank=True,
        help_text="SHA-256 checksum of downloaded content"
    )

    last_sync_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last time content was synced from server"
    )

    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When offline content expires (for DRM/licensing)"
    )

    download_started_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When download started"
    )

    download_completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When download completed"
    )

    error_message = models.TextField(
        blank=True,
        help_text="Error message if download failed"
    )

    retry_count = models.IntegerField(
        default=0,
        help_text="Number of download retry attempts"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "offline_course"
        verbose_name = "Offline Course"
        verbose_name_plural = "Offline Courses"
        unique_together = [["user", "course_id"]]
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["status", "updated_at"]),
        ]
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user.username} - {self.course_name} ({self.get_status_display()})"

    def update_progress(self, downloaded_bytes):
        """
        Update download progress.

        @covers: AC-MOB-017 - Background download progress tracking
        """
        self.downloaded_bytes = downloaded_bytes
        if self.total_size_bytes > 0:
            self.progress_percent = (downloaded_bytes / self.total_size_bytes) * 100
        self.save(update_fields=["downloaded_bytes", "progress_percent", "updated_at"])

    def mark_completed(self, checksum):
        """
        Mark download as completed.

        @covers: AC-MOB-016 - Download completion tracking
        """
        self.status = "completed"
        self.progress_percent = 100.00
        self.content_checksum = checksum
        self.download_completed_at = timezone.now()
        self.save(update_fields=[
            "status",
            "progress_percent",
            "content_checksum",
            "download_completed_at",
            "updated_at"
        ])

    def mark_failed(self, error_message):
        """Mark download as failed."""
        self.status = "failed"
        self.error_message = error_message
        self.retry_count += 1
        self.save(update_fields=["status", "error_message", "retry_count", "updated_at"])

    def pause(self):
        """
        Pause download (AC-MOB-017 - Background download pause/resume).
        """
        self.status = "paused"
        self.save(update_fields=["status", "updated_at"])

    def resume(self):
        """Resume paused download."""
        self.status = "downloading"
        self.save(update_fields=["status", "updated_at"])


class OfflineVideo(models.Model):
    """
    Individual video downloaded for offline viewing.

    @covers: AC-MOB-018 - Offline video playback
    """

    offline_course = models.ForeignKey(
        OfflineCourse,
        on_delete=models.CASCADE,
        related_name="videos",
        help_text="Parent offline course"
    )

    video_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Video ID from Open edX"
    )

    video_title = models.CharField(
        max_length=255,
        help_text="Video title"
    )

    video_url = models.URLField(
        help_text="Original video URL (for re-sync)"
    )

    local_file_path = models.CharField(
        max_length=500,
        blank=True,
        help_text="Local file path on device (relative)"
    )

    file_size_bytes = models.BigIntegerField(
        default=0,
        help_text="Video file size in bytes"
    )

    duration_seconds = models.IntegerField(
        default=0,
        help_text="Video duration in seconds"
    )

    resolution = models.CharField(
        max_length=20,
        default="720p",
        help_text="Video resolution (e.g., 720p, 1080p)"
    )

    is_downloaded = models.BooleanField(
        default=False,
        help_text="Whether video is fully downloaded"
    )

    checksum = models.CharField(
        max_length=64,
        blank=True,
        help_text="SHA-256 checksum of video file"
    )

    downloaded_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When video was downloaded"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "offline_video"
        verbose_name = "Offline Video"
        verbose_name_plural = "Offline Videos"
        unique_together = [["offline_course", "video_id"]]
        indexes = [
            models.Index(fields=["offline_course", "is_downloaded"]),
        ]
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.video_title} ({self.resolution})"


class UniversalLinkVerification(models.Model):
    """
    Universal Link verification log for iOS deep linking.

    @covers: AC-MOB-019 - Universal Links verification and testing
    """

    VERIFICATION_STATUS_CHOICES = [
        ("pending", "Pending"),
        ("verified", "Verified"),
        ("failed", "Failed"),
    ]

    verification_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique verification ID"
    )

    domain = models.CharField(
        max_length=255,
        help_text="Domain being verified (e.g., academyv2.mereka.io)"
    )

    path = models.CharField(
        max_length=500,
        help_text="URL path being verified (e.g., /courses/course-v1:...)"
    )

    status = models.CharField(
        max_length=20,
        choices=VERIFICATION_STATUS_CHOICES,
        default="pending",
        help_text="Verification status"
    )

    user_agent = models.CharField(
        max_length=500,
        blank=True,
        help_text="User agent string from verification request"
    )

    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        help_text="IP address of verification request"
    )

    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When verification succeeded"
    )

    error_message = models.TextField(
        blank=True,
        help_text="Error message if verification failed"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "universal_link_verification"
        verbose_name = "Universal Link Verification"
        verbose_name_plural = "Universal Link Verifications"
        indexes = [
            models.Index(fields=["domain", "status"]),
            models.Index(fields=["created_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.domain}{self.path} - {self.get_status_display()}"

    @classmethod
    def create_verification(cls, domain, path, user_agent="", ip_address=None):
        """
        Create a new verification record.

        @covers: AC-MOB-019 - Universal Links verification tracking
        """
        verification_id = hashlib.sha256(
            f"{domain}{path}{timezone.now().isoformat()}".encode()
        ).hexdigest()[:32]

        return cls.objects.create(
            verification_id=verification_id,
            domain=domain,
            path=path,
            user_agent=user_agent,
            ip_address=ip_address,
        )

    def mark_verified(self):
        """Mark verification as successful."""
        self.status = "verified"
        self.verified_at = timezone.now()
        self.save(update_fields=["status", "verified_at", "updated_at"])

    def mark_failed(self, error_message):
        """Mark verification as failed."""
        self.status = "failed"
        self.error_message = error_message
        self.save(update_fields=["status", "error_message", "updated_at"])
