"""
Signal handlers for registering ACE push channel.

@spec: email-notifications-pipeline_spec.md
"""

import logging

logger = logging.getLogger(__name__)


def register_ace_channel():
    """Register the push ACE channel on app startup."""
    try:
        from .ace_channel import PushChannel  # noqa: F401
        logger.info("PushChannel registered for ACE push channel")
    except ImportError:
        logger.warning("edx-ace not installed, skipping PushChannel registration")


register_ace_channel()
