"""
Django app configuration for video analytics.
"""

from django.apps import AppConfig


class VideoAnalyticsConfig(AppConfig):
    """
    Configuration for the video analytics Django app.
    """
    name = 'openedx_video_analytics'
    verbose_name = 'Open edX Video Analytics'

    def ready(self):
        """
        Import signal handlers when app is ready.
        """
        # Import signals to register handlers
        try:
            from . import signals  # noqa: F401
        except ImportError:
            pass
