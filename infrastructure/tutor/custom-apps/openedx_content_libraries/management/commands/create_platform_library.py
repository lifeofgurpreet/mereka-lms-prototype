"""
Create the first platform library: lib:Mereka:platform-templates (AC-LIB-011).

Idempotent — safe to run multiple times.
"""
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Create the lib:Mereka:platform-templates library'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        from openedx_content_libraries.api import create_platform_templates_library

        if options['dry_run']:
            self.stdout.write('Would create: lib:Mereka:platform-templates')
            return

        metadata = create_platform_templates_library()
        self.stdout.write(self.style.SUCCESS(
            f'Library ready: {metadata.library_key} '
            f'({"created" if metadata.created_at == metadata.updated_at else "exists"})'
        ))
