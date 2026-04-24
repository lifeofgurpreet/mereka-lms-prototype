"""
Django app configuration for video analytics.
"""

from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:
    PluginURLs = None
    ProjectType = None


class VideoAnalyticsConfig(AppConfig):
    """
    Configuration for the video analytics Django app.
    """
    name = 'openedx_video_analytics'
    verbose_name = 'Open edX Video Analytics'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: 'openedx_video_analytics',
                    PluginURLs.REGEX: r'^api/video/v1/',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }

    def ready(self):
        """
        Import signal handlers when app is ready.
        """
        # Import signals to register handlers
        try:
            from . import signals  # noqa: F401
        except ImportError:
            pass
