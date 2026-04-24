"""Django app configuration for Assessment Bulk Operations"""
from django.apps import AppConfig


class AssessmentBulkConfig(AppConfig):
    """Assessment Bulk Operations app configuration"""

    name = 'openedx_assessment_bulk'
    verbose_name = 'Assessment Bulk Operations - Regrade, Export, Import, Security'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Import signals and middleware when app is ready"""
        from . import signals  # noqa: F401
