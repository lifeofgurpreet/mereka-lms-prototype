"""
Django app configuration for openedx_notifications.
"""

from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:
    PluginURLs = None
    ProjectType = None


class OpenedxNotificationsConfig(AppConfig):
    """App configuration for Open edX in-app notifications."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'openedx_notifications'
    verbose_name = 'Open edX In-App Notifications'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: 'openedx_notifications',
                    PluginURLs.REGEX: r'^api/notifications/v1/',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }

    def ready(self):
        """Import signal handlers when app is ready."""
        # Import signals to register ACE channel
        from . import signals  # noqa: F401
