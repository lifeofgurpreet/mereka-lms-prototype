"""
ACE in_app channel for creating in-app notifications.

@spec: email-notifications-pipeline_spec.md
"""

import logging
from django.contrib.auth import get_user_model
from edx_ace.channel import Channel, ChannelType
from edx_ace.errors import RecoverableChannelDeliveryError

from .models import Notification

logger = logging.getLogger(__name__)

IN_APP_CHANNEL_TYPE = getattr(ChannelType, "IN_APP", "in_app")

User = get_user_model()


class InAppChannel(Channel):
    """
    ACE channel for in-app notifications.

    Creates a notification record in the database when an ACE message
    is dispatched through the in_app channel.
    """

    channel_type = IN_APP_CHANNEL_TYPE

    @classmethod
    def enabled(cls):
        """Check if in-app channel is enabled."""
        from django.conf import settings
        return getattr(settings, 'NOTIFICATION_INAPP_ENABLED', True)

    def deliver(self, message, rendered_message):
        """
        Create an in-app notification from an ACE message.

        Args:
            message: ACE Message object
            rendered_message: Rendered message content (subject, body, etc.)

        Raises:
            RecoverableChannelDeliveryError: If notification creation fails
        """
        if not self.enabled():
            logger.info(f"In-app notifications disabled, skipping {message.name}")
            return

        try:
            # Extract recipient user
            recipient = message.recipient

            # Get user object
            if isinstance(recipient, User):
                user = recipient
            elif hasattr(recipient, 'lms_user_id'):
                user = User.objects.get(id=recipient.lms_user_id)
            elif hasattr(recipient, 'username'):
                user = User.objects.get(username=recipient.username)
            elif hasattr(recipient, 'email_address'):
                user = User.objects.get(email=recipient.email_address)
            else:
                logger.error(f"Cannot resolve user from recipient: {recipient}")
                return

            # Extract notification metadata from message context
            context = message.context
            title = rendered_message.get('subject', message.name)
            body = rendered_message.get('body', '')
            course_id = context.get('course_id')
            org_slug = context.get('org_slug', 'default')
            deep_link_url = context.get('deep_link_url')
            expires_at = context.get('expires_at')

            # Create notification
            notification = Notification.objects.create(
                user=user,
                message_type=message.name,
                title=title,
                body=body,
                course_id=course_id,
                org_slug=org_slug,
                deep_link_url=deep_link_url,
                expires_at=expires_at,
            )

            logger.info(
                f"Created in-app notification {notification.id} "
                f"for user {user.username} (type: {message.name})"
            )

        except User.DoesNotExist:
            logger.error(f"User not found for recipient: {recipient}")
            raise RecoverableChannelDeliveryError(
                f"User not found: {recipient}",
                next_attempt_time=None
            )

        except Exception as e:
            logger.exception(f"Failed to create in-app notification: {e}")
            raise RecoverableChannelDeliveryError(
                f"In-app notification delivery failed: {e}",
                next_attempt_time=None
            )
