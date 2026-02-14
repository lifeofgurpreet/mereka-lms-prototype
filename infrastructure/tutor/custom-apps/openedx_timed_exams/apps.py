"""Django app configuration for Timed Exams"""
from django.apps import AppConfig


class TimedExamsConfig(AppConfig):
    """Timed Exams app configuration"""

    name = 'openedx_timed_exams'
    verbose_name = 'Timed Exams - Server-Side Enforcement & Accommodations'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signals when app is ready"""
        from . import signals  # noqa: F401
