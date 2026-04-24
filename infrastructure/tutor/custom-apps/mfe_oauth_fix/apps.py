"""
Django app configuration for MFE OAuth fix.
"""

from django.apps import AppConfig


class MFEOAuthFixConfig(AppConfig):
    """Configuration for the MFE OAuth fix app."""

    name = 'mfe_oauth_fix'
    verbose_name = 'MFE OAuth Provider Fix'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signal handlers when the app is ready."""
        pass
