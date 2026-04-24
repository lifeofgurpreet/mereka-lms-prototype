"""
Django app configuration for openedx_email_digests.

@spec: email-notifications-pipeline_spec.md
"""

from django.apps import AppConfig


class OpenedxEmailDigestsConfig(AppConfig):
    """App configuration for email digests and analytics."""

    name = 'openedx_email_digests'
    verbose_name = 'Email Digests & Analytics'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Register signal handlers on app startup."""
        from . import signals  # noqa: F401
