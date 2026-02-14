"""
Django app configuration for openedx_tenant_cache.

@spec: multi-tenancy-architecture_spec.md
"""

from django.apps import AppConfig


class OpenedxTenantCacheConfig(AppConfig):
    """App configuration for tenant cache namespacing and metrics."""

    name = 'openedx_tenant_cache'
    verbose_name = 'Tenant Cache & Foundation'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Register signal handlers and metrics on app startup."""
        from . import signals  # noqa: F401
