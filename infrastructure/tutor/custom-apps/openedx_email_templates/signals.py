"""
Signal handlers for email templates app.

@spec: email-notifications-pipeline_spec.md
"""

import logging

logger = logging.getLogger(__name__)


def register_template_engine():
    """Register the template engine on app startup."""
    logger.info("openedx_email_templates: Template engine registered")


register_template_engine()
