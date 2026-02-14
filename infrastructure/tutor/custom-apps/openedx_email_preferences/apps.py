"""
Django app configuration for openedx_email_preferences.
"""

from django.apps import AppConfig


class OpenedxEmailPreferencesConfig(AppConfig):
    """App configuration for Open edX email preferences."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'openedx_email_preferences'
    verbose_name = 'Open edX Email Preferences'

    def ready(self):
        """Import signal handlers when app is ready."""
        # Import signals to register ACE hooks
        from . import signals  # noqa: F401
