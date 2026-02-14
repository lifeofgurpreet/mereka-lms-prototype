"""
ACE push channel for delivering notifications via Firebase Cloud Messaging.

@spec: email-notifications-pipeline_spec.md
@covers: AC-015, AC-016, AC-018, AC-019
"""

import logging

from django.conf import settings
from edx_ace.channel import Channel, ChannelType

logger = logging.getLogger(__name__)


class PushChannel(Channel):
    """
    ACE channel that dispatches push notifications via FCM.

    Enqueues a Celery task for async batch delivery rather than
    sending synchronously during the request cycle.
    """

    channel_type = ChannelType.PUSH

    @classmethod
    def enabled(cls):
        """Check if push channel is globally enabled."""
        return getattr(settings, 'NOTIFICATION_PUSH_ENABLED', False)

    def deliver(self, message, rendered_message):
        """
        Enqueue a push notification for async FCM delivery.

        Args:
            message: ACE Message object
            rendered_message: Rendered message content
        """
        if not self.enabled():
            logger.debug("Push notifications disabled, skipping %s", message.name)
            return

        from .tasks import send_push_notification

        context = message.context
        recipient = message.recipient

        # Resolve user ID
        user_id = None
        if hasattr(recipient, 'lms_user_id'):
            user_id = recipient.lms_user_id
        elif hasattr(recipient, 'id'):
            user_id = recipient.id

        if not user_id:
            logger.error("Cannot resolve user_id from recipient: %s", recipient)
            return

        notification_data = {
            'notification_id': str(message.uuid),
            'type': message.name,
            'title': rendered_message.get('subject', message.name),
            'body': rendered_message.get('body', ''),
            'course_id': context.get('course_id', ''),
            'deep_link_url': context.get('deep_link_url', ''),
            'org_slug': context.get('org_slug', 'default'),
            'timestamp': context.get('timestamp', ''),
        }

        send_push_notification.delay(user_id, notification_data)
        logger.info(
            "Enqueued push notification %s for user %s (type=%s)",
            message.uuid, user_id, message.name,
        )
