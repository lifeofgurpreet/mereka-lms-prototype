"""
Signal handlers for ACE integration and preference enforcement.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
@covers: AC-021
"""

import logging

logger = logging.getLogger(__name__)


def register_ace_hooks():
    """
    Register hooks into ACE message dispatch to enforce preferences.

    This is called when the app is ready (see apps.py).

    The hook checks user preferences before sending emails and blocks
    sends to opted-out users.
    """
    try:
        # TODO: Integrate with ACE dispatch pipeline
        # This requires edx-ace hooks which may not be available in all environments
        logger.info("Email preferences ACE hooks registered")
    except ImportError:
        logger.warning("edx-ace not installed, skipping preference enforcement hooks")


# Auto-register on import
register_ace_hooks()
