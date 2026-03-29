"""
Management command to import Kajabi users from CSV.

Usage:
    python manage.py import_kajabi_users --csv-file /path/to/users.csv
    python manage.py import_kajabi_users --csv-file /path/to/users.csv --no-welcome
    python manage.py import_kajabi_users --csv-file /path/to/users.csv --dry-run

@spec: kajabi-sso
@covers: AC-SSO-002
"""

import os
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model

from openedx_kajabi_sso.api import import_kajabi_csv

User = get_user_model()


class Command(BaseCommand):
    """Import Kajabi users from CSV file."""

    help = 'Import Kajabi users from CSV file and create SSO links'

    def add_arguments(self, parser):
        parser.add_argument(
            '--csv-file',
            type=str,
            required=True,
            help='Path to CSV file with Kajabi users (email,first_name,last_name,kajabi_user_id)'
        )

        parser.add_argument(
            '--no-welcome',
            action='store_true',
            help='Skip sending welcome emails to new users'
        )

        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview import without making changes (not yet implemented)'
        )

    def handle(self, *args, **options):
        csv_file_path = options['csv_file']
        send_welcome = not options['no_welcome']
        dry_run = options['dry_run']

        # Validate CSV file exists
        if not os.path.exists(csv_file_path):
            raise CommandError(f"CSV file not found: {csv_file_path}")

        self.stdout.write(self.style.NOTICE(f"Importing Kajabi users from {csv_file_path}"))
        self.stdout.write(self.style.NOTICE(f"Welcome emails: {'enabled' if send_welcome else 'disabled'}"))

        if dry_run:
            # Count rows in CSV to give operators a preview without writing to DB
            with open(csv_file_path, newline='') as f:
                import csv as csv_module
                reader = csv_module.DictReader(f)
                rows = list(reader)
            count = len(rows)
            self.stdout.write(self.style.WARNING(f"DRY RUN: {count} user(s) found in CSV — no users will be created."))
            for row in rows:
                self.stdout.write(f"  would import: {row.get('email', '(no email)')} ({row.get('first_name', '')} {row.get('last_name', '')})")
            self.stdout.write(self.style.SUCCESS(f"Dry run complete. {count} user(s) would be imported."))
            return

        try:
            # Import users
            batch = import_kajabi_csv(
                csv_file_path=csv_file_path,
                imported_by=None,  # TODO: Could pass admin user if running from Django admin
                send_welcome=send_welcome
            )

            # Print summary
            self.stdout.write(self.style.SUCCESS("\n=== Import Summary ==="))
            self.stdout.write(f"Total rows processed: {batch.total_rows}")
            self.stdout.write(self.style.SUCCESS(f"New users created: {batch.created_count}"))
            self.stdout.write(self.style.SUCCESS(f"Existing users linked: {batch.linked_count}"))
            self.stdout.write(self.style.WARNING(f"Rows skipped (duplicates): {batch.skipped_count}"))

            if batch.error_count > 0:
                self.stdout.write(self.style.ERROR(f"Errors encountered: {batch.error_count}"))
                self.stdout.write(self.style.ERROR("\nError details:"))
                for error in batch.errors_json[:10]:  # Show first 10 errors
                    self.stdout.write(f"  Row {error['row']}: {error['error']}")
                if len(batch.errors_json) > 10:
                    self.stdout.write(f"  ... and {len(batch.errors_json) - 10} more errors")

            self.stdout.write(self.style.SUCCESS(f"\nImport batch ID: {batch.id}"))
            self.stdout.write(self.style.SUCCESS(f"Status: {batch.status}"))

        except Exception as e:
            raise CommandError(f"Import failed: {e}")
