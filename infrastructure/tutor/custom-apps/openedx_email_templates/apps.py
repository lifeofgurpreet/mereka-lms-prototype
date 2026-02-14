"""
Django app configuration for openedx_email_templates.

@spec: email-notifications-pipeline_spec.md
"""

from django.apps import AppConfig


class OpenedxEmailTemplatesConfig(AppConfig):
    """App configuration for email templates and bulk campaigns."""

    name = 'openedx_email_templates'
    verbose_name = 'Email Templates & Bulk Campaigns'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Register signal handlers on app startup."""
        from . import signals  # noqa: F401
