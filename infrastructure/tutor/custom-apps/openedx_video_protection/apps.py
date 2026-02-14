"""Django app configuration for Video Protection"""
from django.apps import AppConfig


class VideoProtectionConfig(AppConfig):
    """Video Protection app configuration"""

    name = 'openedx_video_protection'
    verbose_name = 'Video Content Protection'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signals when app is ready"""
        # Future: Add signal handlers for token cleanup
        pass
