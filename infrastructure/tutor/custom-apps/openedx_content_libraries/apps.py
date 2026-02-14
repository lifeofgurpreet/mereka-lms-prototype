"""Django app configuration."""
from django.apps import AppConfig


class OpenedxContentLibrariesConfig(AppConfig):
    name = 'openedx_content_libraries'
    verbose_name = 'Content Libraries v2 Extensions'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        from . import signals  # noqa: F401
