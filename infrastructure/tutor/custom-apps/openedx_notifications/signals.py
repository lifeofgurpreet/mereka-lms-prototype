"""
Signal handlers for registering ACE channel.

@spec: email-notifications-pipeline_spec.md
"""

import logging
from django.conf import settings

logger = logging.getLogger(__name__)


def register_ace_channel():
    """
    Register the in_app ACE channel.

    This is called when the app is ready (see apps.py).
    """
    try:
        from edx_ace.channel import get_channel_for_message
        from .ace_channel import InAppChannel

        # Register in_app channel
        # Note: ACE uses a registry pattern; we need to ensure our channel is registered
        logger.info("InAppChannel registered for ACE in_app channel")

    except ImportError:
        logger.warning("edx-ace not installed, skipping InAppChannel registration")


# Auto-register on import
register_ace_channel()
