"""Backup all libraries to GCS (nightly OLX export)."""
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    help = 'Export all Content Libraries v2 to OLX backup and upload to GCS'

    def add_arguments(self, parser):
        parser.add_argument('--local-only', action='store_true',
                           help='Save backup locally only (skip GCS upload)')
        parser.add_argument('--include-deleted', action='store_true',
                           help='Include soft-deleted libraries within retention')

    def handle(self, *args, **options):
        from openedx_content_libraries.backup import export_all_libraries, upload_backup_to_gcs

        self.stdout.write("Exporting all libraries...")
        backup = export_all_libraries(
            skip_expired_deleted=not options['include_deleted'],
        )

        manifest = backup['manifest']
        self.stdout.write(f"Exported {manifest['total_libraries']} libraries "
                         f"({manifest['total_errors']} errors, {manifest['elapsed_ms']}ms)")

        if options['local_only']:
            import json, os
            from django.utils import timezone
            path = f"/tmp/library-backup-{timezone.now().strftime('%Y%m%d-%H%M%S')}.json"
            with open(path, 'w') as f:
                json.dump(backup, f, default=str)
            self.stdout.write(self.style.SUCCESS(f"Backup saved to {path}"))
        else:
            location = upload_backup_to_gcs(backup)
            self.stdout.write(self.style.SUCCESS(f"Backup uploaded to {location}"))
