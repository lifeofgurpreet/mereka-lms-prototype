"""Django app configuration for Kajabi SSO."""

from django.apps import AppConfig


class KajabiSSOConfig(AppConfig):
    """Configuration for openedx_kajabi_sso app."""

    name = "openedx_kajabi_sso"
    verbose_name = "Kajabi SSO Integration"

    def ready(self):
        """Import signals when app is ready."""
        import openedx_kajabi_sso.signals  # noqa: F401
