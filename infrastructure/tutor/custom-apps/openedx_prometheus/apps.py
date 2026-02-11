"""
Django app configuration for Open edX Prometheus integration.
"""

# @spec platform-middleware-custom-apps AC-MPC-017: Django app config for Prometheus metrics integration
# @spec observability-stack: Application-level metrics instrumentation via django-prometheus

from django.apps import AppConfig


class OpenEdxPrometheusConfig(AppConfig):
    """Configuration for the Open edX Prometheus metrics app."""

    name = 'openedx_prometheus'
    verbose_name = 'Open edX Prometheus Metrics'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Initialize Prometheus exporters when the app is ready."""
        pass
