"""
Django app configuration for openedx_push_notifications.
"""

from django.apps import AppConfig


class OpenedxPushNotificationsConfig(AppConfig):
    """App configuration for Open edX push notifications via FCM."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'openedx_push_notifications'
    verbose_name = 'Open edX Push Notifications (FCM)'

    def ready(self):
        """Register ACE push channel on startup."""
        from . import signals  # noqa: F401
