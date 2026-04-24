"""
Django app configuration for Mux video upload.

@spec: video-pipeline-delivery_spec.md (Phase 3)
"""

from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:
    PluginURLs = None
    ProjectType = None


class MuxUploadConfig(AppConfig):
    """App configuration for Mux video upload in Open edX Studio."""

    name = 'openedx_mux_upload'
    verbose_name = 'Mux Video Upload'
    default_auto_field = 'django.db.models.BigAutoField'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: 'openedx_mux_upload',
                    PluginURLs.REGEX: r'^api/mux/upload/',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }
