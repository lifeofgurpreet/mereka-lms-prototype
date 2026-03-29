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
    Placeholder for ACE dispatch preference enforcement.

    WARNING: This function does NOT register any hooks. Email preference
    opt-out enforcement is NOT active. Users who opt out will still
    receive emails until the ACE dispatch integration is implemented.
    """
    logger.warning(
        "Email preference enforcement is NOT active. "
        "No ACE dispatch hook is registered. "
        "Opted-out users will still receive emails. "
        "Implement ACE dispatch integration to close this gap."
    )
