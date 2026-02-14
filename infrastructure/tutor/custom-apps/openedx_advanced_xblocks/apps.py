"""Django app configuration for Advanced XBlocks"""
from django.apps import AppConfig


class AdvancedXBlocksConfig(AppConfig):
    """Advanced XBlocks app configuration"""

    name = 'openedx_advanced_xblocks'
    verbose_name = 'Advanced XBlocks - Drag-Drop, Math, Randomization'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signals and register XBlocks when app is ready"""
        from . import signals  # noqa: F401
