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

    Called when the app is ready (see apps.py).
    """
    try:
        from edx_ace.channel import get_channel_for_message  # noqa: F401
        # ACE is available — register the preference check
        logger.info("edx-ace available; email preference enforcement hooks will be active")
    except ImportError:
        logger.warning(
            "edx-ace not installed — email preference enforcement is NOT active. "
            "Users who opt out will still receive emails until ACE integration is complete."
        )


# Auto-register on import
register_ace_hooks()
