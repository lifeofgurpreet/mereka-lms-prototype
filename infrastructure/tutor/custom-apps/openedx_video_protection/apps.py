"""Django app configuration for Video Protection"""
from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:
    PluginURLs = None
    ProjectType = None


class VideoProtectionConfig(AppConfig):
    """Video Protection app configuration"""

    name = 'openedx_video_protection'
    verbose_name = 'Video Content Protection'
    default_auto_field = 'django.db.models.BigAutoField'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: 'openedx_video_protection',
                    PluginURLs.REGEX: r'^api/mux/protection/',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }

    def ready(self):
        """Import signals when app is ready"""
        # Future: Add signal handlers for token cleanup
        pass
