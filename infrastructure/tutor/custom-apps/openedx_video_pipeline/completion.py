"""
Learner video completion tracking.

Tracks video completion percentage per learner per video.
Completion is defined as watching >= 90% of the video duration.

@spec: video-pipeline-delivery_spec.md (Phase 2)
@covers: AC-VPD-014, AC-VPD-016
"""
import logging

from django.conf import settings
from django.db import models
from django.utils import timezone

logger = logging.getLogger(__name__)


class VideoCompletionStatus(models.Model):
    """
    Tracks video completion progress per learner per video.

    Updated on each 'played', 'seeked', or 'completed' event.
    A video is "complete" when max_position_reached / duration >= 0.90.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='video_completions',
        db_index=True,
    )

    video_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text='Mux playback ID (never asset ID)',
    )

    course_key = models.CharField(
        max_length=255,
        db_index=True,
        help_text='Course key string',
    )

    # Progress tracking
    max_position_reached = models.FloatField(
        default=0.0,
        help_text='Furthest position reached in seconds',
    )

    duration = models.FloatField(
        default=0.0,
        help_text='Video total duration in seconds',
    )

    completion_percentage = models.FloatField(
        default=0.0,
        help_text='Completion percentage (0.0 to 1.0)',
    )

    is_complete = models.BooleanField(
        default=False,
        help_text='True when completion_percentage >= 0.90',
    )

    # Event tracking
    play_count = models.IntegerField(
        default=0,
        help_text='Number of times video was played',
    )

    last_position = models.FloatField(
        default=0.0,
        help_text='Last known playback position (for resume)',
    )

    first_played_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the video was first played',
    )

    completed_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the video was first completed (90%+)',
    )

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [('user', 'video_id', 'course_key')]
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['user', 'course_key']),
            models.Index(fields=['video_id', 'is_complete']),
            models.Index(fields=['course_key', 'is_complete']),
        ]
        verbose_name = 'Video Completion Status'
        verbose_name_plural = 'Video Completion Statuses'

    def __str__(self):
        pct = self.completion_percentage * 100
        return f'{self.user_id}:{self.video_id} — {pct:.0f}% {"✓" if self.is_complete else ""}'

    @classmethod
    def update_progress(cls, user, video_id, course_key, position, duration=None,
                        event_type='played'):
        """
        Update video completion progress for a learner.

        Called when a playback event occurs. Updates max_position_reached
        and recalculates completion_percentage.

        Args:
            user: User instance
            video_id (str): Mux playback ID
            course_key (str): Course key string
            position (float): Current playback position in seconds
            duration (float, optional): Video total duration
            event_type (str): Event type (played, paused, seeked, completed)

        Returns:
            VideoCompletionStatus: Updated completion record
        """
        status_obj, created = cls.objects.get_or_create(
            user=user,
            video_id=video_id,
            course_key=course_key,
            defaults={
                'first_played_at': timezone.now(),
                'duration': duration or 0.0,
            },
        )

        # Update duration if provided and not set
        if duration and (not status_obj.duration or duration > status_obj.duration):
            status_obj.duration = duration

        # Update position tracking
        status_obj.last_position = position
        if position > status_obj.max_position_reached:
            status_obj.max_position_reached = position

        # Increment play count on 'played' events
        if event_type == 'played':
            status_obj.play_count += 1
            if not status_obj.first_played_at:
                status_obj.first_played_at = timezone.now()

        # Recalculate completion percentage
        if status_obj.duration > 0:
            status_obj.completion_percentage = min(
                status_obj.max_position_reached / status_obj.duration, 1.0
            )
        elif event_type == 'completed':
            status_obj.completion_percentage = 1.0

        # Mark complete at 90%
        was_complete = status_obj.is_complete
        status_obj.is_complete = status_obj.completion_percentage >= 0.90
        if status_obj.is_complete and not was_complete:
            status_obj.completed_at = timezone.now()
            logger.info(
                f'Video completed: user={user.id}, video={video_id}, '
                f'course={course_key}, pct={status_obj.completion_percentage:.0%}'
            )

        status_obj.save()
        return status_obj

    @classmethod
    def get_course_completion_summary(cls, course_key):
        """
        Get video completion summary for a course.

        Returns:
            dict: Summary with total_videos, avg_completion, completed_count
        """
        from django.db.models import Avg, Count, Q

        stats = cls.objects.filter(course_key=course_key).aggregate(
            total_records=Count('id'),
            avg_completion=Avg('completion_percentage'),
            completed_count=Count('id', filter=Q(is_complete=True)),
            unique_videos=Count('video_id', distinct=True),
            unique_users=Count('user', distinct=True),
        )

        return {
            'course_key': course_key,
            'total_records': stats['total_records'],
            'unique_videos': stats['unique_videos'],
            'unique_users': stats['unique_users'],
            'avg_completion': round(stats['avg_completion'] or 0, 3),
            'completed_count': stats['completed_count'],
        }
