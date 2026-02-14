"""Django app configuration for XQueue Graders"""
from django.apps import AppConfig


class XQueueGradersConfig(AppConfig):
    """XQueue Graders app configuration"""

    name = 'openedx_xqueue_graders'
    verbose_name = 'XQueue Graders - Python Code Sandbox'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import metrics when app is ready"""
        from . import metrics  # noqa: F401
