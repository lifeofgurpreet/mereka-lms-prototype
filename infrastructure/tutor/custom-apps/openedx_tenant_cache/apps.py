"""
Django app configuration for openedx_tenant_cache.

@spec: multi-tenancy-architecture_spec.md
"""

from django.apps import AppConfig

try:
    from openedx.core.djangoapps.plugins.constants import PluginURLs, ProjectType
except ImportError:  # pragma: no cover
    PluginURLs = None
    ProjectType = None


class OpenedxTenantCacheConfig(AppConfig):
    """App configuration for tenant cache namespacing and metrics."""

    name = 'openedx_tenant_cache'
    verbose_name = 'Tenant Cache & Foundation'
    default_auto_field = 'django.db.models.BigAutoField'

    if PluginURLs is not None:
        plugin_app = {
            PluginURLs.CONFIG: {
                ProjectType.LMS: {
                    PluginURLs.NAMESPACE: 'openedx_tenant_cache',
                    PluginURLs.REGEX: r'^api/tenant/v1/',
                    PluginURLs.RELATIVE_PATH: 'urls',
                },
            },
        }

    def ready(self):
        """Register signal handlers and metrics on app startup."""
        from . import signals  # noqa: F401
