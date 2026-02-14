"""
Django app configuration for openedx_notifications.
"""

from django.apps import AppConfig


class OpenedxNotificationsConfig(AppConfig):
    """App configuration for Open edX in-app notifications."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'openedx_notifications'
    verbose_name = 'Open edX In-App Notifications'

    def ready(self):
        """Import signal handlers when app is ready."""
        # Import signals to register ACE channel
        from . import signals  # noqa: F401
