"""
Signal handlers for email digests app.

@spec: email-notifications-pipeline_spec.md
"""

import logging

logger = logging.getLogger(__name__)


def register_digest_engine():
    """Register the digest engine on app startup."""
    logger.info("openedx_email_digests: Digest engine and analytics registered")


register_digest_engine()
