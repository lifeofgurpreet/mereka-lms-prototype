"""
Video Analytics Signal Handlers

Django signals for video analytics integration.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import VideoPlaybackEvent

logger = logging.getLogger(__name__)


@receiver(post_save, sender=VideoPlaybackEvent)
def on_video_event_created(sender, instance, created, **kwargs):
    """
    Signal handler for when a video playback event is created.

    Can be used to trigger real-time analytics updates or notifications.

    Args:
        sender: VideoPlaybackEvent model class
        instance: Created VideoPlaybackEvent instance
        created (bool): True if this is a new record
        **kwargs: Additional signal arguments
    """
    if created:
        logger.debug(
            f"Video event created: type={instance.event_type}, "
            f"video_id={instance.video_id}, user={instance.user.username}"
        )

        # Example: Trigger real-time analytics update for critical events
        if instance.event_type == 'completed':
            logger.info(
                f"Video completion event: video_id={instance.video_id}, "
                f"user={instance.user.username}, position={instance.position:.1f}s"
            )

            # Future: Trigger real-time dashboard update via websocket
            # send_websocket_update('video_completed', instance.video_id)
