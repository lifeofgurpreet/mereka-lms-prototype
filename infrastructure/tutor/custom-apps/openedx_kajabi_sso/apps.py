"""
Django app configuration for openedx_kajabi_sso.
"""

from django.apps import AppConfig


class OpenedxKajabiSsoConfig(AppConfig):
    """App configuration for Kajabi SSO Integration."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'openedx_kajabi_sso'
    verbose_name = 'Kajabi SSO Integration'

    def ready(self):
        """Import signal handlers when app is ready."""
        # Future: Import signals here if needed
        pass
