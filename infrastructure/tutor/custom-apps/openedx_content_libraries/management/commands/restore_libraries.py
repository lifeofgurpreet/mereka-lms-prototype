"""Restore libraries from backup (disaster recovery)."""
import json
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    help = 'Restore Content Libraries v2 from OLX backup'

    def add_arguments(self, parser):
        parser.add_argument('backup_file', help='Path to backup JSON file')
        parser.add_argument('--dry-run', action='store_true',
                           help='Show what would be restored without making changes')
        parser.add_argument('--force', action='store_true',
                           help='Overwrite libraries modified after backup (AC-NEG-LIB-012: disabled by default)')

    def handle(self, *args, **options):
        from openedx_content_libraries.backup import restore_from_backup

        with open(options['backup_file'], 'r') as f:
            backup_data = json.load(f)

        self.stdout.write(f"Restoring from backup: {options['backup_file']}")
        if options['dry_run']:
            self.stdout.write("DRY RUN — no changes will be made")

        report = restore_from_backup(
            backup_data,
            dry_run=options['dry_run'],
            skip_newer=not options['force'],
        )

        self.stdout.write(f"Restored: {report['restored']}")
        self.stdout.write(f"Skipped (newer): {report['skipped_newer']}")
        self.stdout.write(f"Skipped (exists): {report['skipped_exists']}")
        self.stdout.write(f"Errors: {len(report['errors'])}")
        self.stdout.write(f"Components pre: {report['component_count_pre']}, post: {report['component_count_post']}")

        if report['errors']:
            for err in report['errors']:
                self.stderr.write(f"  ERROR: {err}")

        if not report['errors']:
            self.stdout.write(self.style.SUCCESS("Restore completed successfully"))
        else:
            self.stdout.write(self.style.WARNING(f"Restore completed with {len(report['errors'])} errors"))
