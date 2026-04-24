"""
Django app configuration for Open edX Prometheus integration.
"""

# @covers AC-017, AC-020
# @spec: platform-middleware-custom-apps_spec.md

from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:
    PluginURLs = None
    ProjectType = None


class OpenEdxPrometheusConfig(AppConfig):
    """Configuration for the Open edX Prometheus metrics app."""

    name = 'openedx_prometheus'
    verbose_name = 'Open edX Prometheus Metrics'
    default_auto_field = 'django.db.models.BigAutoField'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: '',
                    PluginURLs.REGEX: r'^',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
                ProjectType.CMS: {
                    PluginURLs.NAMESPACE: '',
                    PluginURLs.REGEX: r'^',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }

    def ready(self):
        """Initialize Prometheus exporters when the app is ready."""
        pass
