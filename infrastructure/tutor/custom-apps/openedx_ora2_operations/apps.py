"""Django app configuration for ORA2 Operations"""
from django.apps import AppConfig


class ORA2OperationsConfig(AppConfig):
    """ORA2 Operations app configuration"""

    name = 'openedx_ora2_operations'
    verbose_name = 'ORA2 Operations & Observability'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signals and connect to ORA2 when app is ready"""
        from . import signals  # noqa: F401
        from .signals import connect_ora2_signals

        # Connect to ORA2 signals
        connect_ora2_signals()
