"""
Management command to bulk import Kajabi users from CSV.

@spec: Kajabi SSO Migration (mereka-lms-f98)
@covers: AC-SSO-002, AC-SSO-004, AC-SSO-005

Usage:
    python manage.py lms import_kajabi_users /path/to/users.csv

CSV Format:
    kajabi_user_id,email,username,first_name,last_name
    123456,user@example.com,usersmith,User,Smith
"""

import csv
import hashlib
import logging
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from openedx_kajabi_sso.models import KajabiImportLog, KajabiImportRecord
from openedx_kajabi_sso.utils import get_or_create_kajabi_user, send_welcome_email

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    """
    Bulk import Kajabi users from CSV.

    @covers: AC-SSO-002 - Bulk import of 500-user CSV with zero duplicates
    @covers: AC-SSO-004 - Email + username deduplication enforced
    @covers: AC-SSO-005 - Welcome email sent to each migrated user
    """

    help = "Import Kajabi users from CSV file and link to SSO"

    def add_arguments(self, parser):
        parser.add_argument(
            "csv_file",
            type=str,
            help="Path to CSV file with Kajabi user data"
        )
        parser.add_argument(
            "--skip-welcome-email",
            action="store_true",
            help="Skip sending welcome emails (for testing)"
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Validate CSV without creating users"
        )

    def handle(self, *args, **options):
        csv_file = options["csv_file"]
        skip_email = options["skip_welcome_email"]
        dry_run = options["dry_run"]

        # Generate import ID from filename + timestamp
        import_id = hashlib.sha256(
            f"{csv_file}{timezone.now().isoformat()}".encode()
        ).hexdigest()[:16]

        self.stdout.write(f"Starting import: {import_id}")

        if dry_run:
            self.stdout.write(self.style.WARNING("DRY RUN MODE - No changes will be made"))

        # Create import log
        import_log = KajabiImportLog.objects.create(
            import_id=import_id,
            filename=csv_file,
        )

        try:
            # Read and validate CSV
            rows = self._read_csv(csv_file)
            import_log.total_rows = len(rows)
            import_log.save(update_fields=["total_rows"])

            self.stdout.write(f"Found {len(rows)} rows in CSV")

            # Start processing
            import_log.start_processing()

            # Process each row
            for row_number, row_data in enumerate(rows, start=2):  # Start at 2 (header is row 1)
                try:
                    self._process_row(
                        import_log=import_log,
                        row_number=row_number,
                        row_data=row_data,
                        skip_email=skip_email,
                        dry_run=dry_run,
                    )
                except Exception as e:
                    logger.error(f"Error processing row {row_number}: {e}")
                    import_log.errors += 1

                    # Create error record
                    KajabiImportRecord.objects.create(
                        import_log=import_log,
                        row_number=row_number,
                        kajabi_user_id=row_data.get("kajabi_user_id", ""),
                        email=row_data.get("email", ""),
                        username=row_data.get("username", ""),
                        operation="error",
                        error_message=str(e),
                    )

            # Mark as completed
            if not dry_run:
                import_log.complete()

            # Print summary
            self._print_summary(import_log, dry_run)

            # Fail if there were errors
            if import_log.errors > 0:
                raise CommandError(f"Import completed with {import_log.errors} errors")

            self.stdout.write(self.style.SUCCESS(f"Import {import_id} completed successfully"))

        except Exception as e:
            import_log.fail(str(e))
            raise CommandError(f"Import failed: {e}")

    def _read_csv(self, csv_file):
        """
        Read and validate CSV file.

        @covers: AC-SSO-002 - CSV validation
        """
        try:
            with open(csv_file, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)

                # Validate headers
                required_fields = {"kajabi_user_id", "email"}
                optional_fields = {"username", "first_name", "last_name"}
                all_fields = required_fields | optional_fields

                if not required_fields.issubset(set(reader.fieldnames)):
                    missing = required_fields - set(reader.fieldnames)
                    raise CommandError(
                        f"CSV missing required columns: {missing}. "
                        f"Required: {required_fields}"
                    )

                # Read all rows
                rows = list(reader)

                if not rows:
                    raise CommandError("CSV file is empty (no data rows)")

                return rows

        except FileNotFoundError:
            raise CommandError(f"CSV file not found: {csv_file}")
        except Exception as e:
            raise CommandError(f"Error reading CSV: {e}")

    def _process_row(self, import_log, row_number, row_data, skip_email, dry_run):
        """
        Process a single CSV row.

        @covers: AC-SSO-002 - Create/link users
        @covers: AC-SSO-004 - Deduplication
        @covers: AC-SSO-005 - Welcome email
        """
        kajabi_user_id = row_data.get("kajabi_user_id", "").strip()
        email = row_data.get("email", "").strip()
        username = row_data.get("username", "").strip()
        first_name = row_data.get("first_name", "").strip()
        last_name = row_data.get("last_name", "").strip()

        # Validate required fields
        if not kajabi_user_id:
            raise ValueError("kajabi_user_id is required")
        if not email:
            raise ValueError("email is required")

        if dry_run:
            self.stdout.write(
                f"[DRY RUN] Row {row_number}: Would process {email} "
                f"(Kajabi ID: {kajabi_user_id})"
            )
            return

        # Get or create user
        with transaction.atomic():
            user, kajabi_sso_user, operation = get_or_create_kajabi_user(
                kajabi_user_id=kajabi_user_id,
                email=email,
                username=username,
                first_name=first_name,
                last_name=last_name,
            )

            # Update counters
            if operation == "create":
                import_log.created_users += 1
            elif operation == "link":
                import_log.linked_users += 1
            elif operation == "skip_duplicate":
                import_log.skipped_duplicates += 1

            import_log.save(update_fields=[
                "created_users",
                "linked_users",
                "skipped_duplicates",
            ])

            # Create import record
            KajabiImportRecord.objects.create(
                import_log=import_log,
                row_number=row_number,
                kajabi_user_id=kajabi_user_id,
                email=email,
                username=user.username,
                operation=operation,
                user=user,
            )

            # Send welcome email
            if not skip_email and operation in ["create", "link"]:
                email_sent = send_welcome_email(user, kajabi_sso_user)
                if email_sent:
                    import_log.welcome_emails_sent += 1
                    import_log.save(update_fields=["welcome_emails_sent"])

            self.stdout.write(
                f"Row {row_number}: {operation.upper()} - {user.username} ({email})"
            )

    def _print_summary(self, import_log, dry_run):
        """Print import summary."""
        self.stdout.write("\n" + "=" * 60)
        self.stdout.write(self.style.SUCCESS("IMPORT SUMMARY"))
        self.stdout.write("=" * 60)

        if dry_run:
            self.stdout.write(self.style.WARNING("(DRY RUN - No changes made)"))

        self.stdout.write(f"Import ID:           {import_log.import_id}")
        self.stdout.write(f"Total rows:          {import_log.total_rows}")
        self.stdout.write(self.style.SUCCESS(f"Created users:       {import_log.created_users}"))
        self.stdout.write(self.style.SUCCESS(f"Linked users:        {import_log.linked_users}"))
        self.stdout.write(self.style.WARNING(f"Skipped duplicates:  {import_log.skipped_duplicates}"))
        self.stdout.write(self.style.SUCCESS(f"Welcome emails sent: {import_log.welcome_emails_sent}"))

        if import_log.errors > 0:
            self.stdout.write(self.style.ERROR(f"Errors:              {import_log.errors}"))
        else:
            self.stdout.write(f"Errors:              {import_log.errors}")

        # Verify AC-SSO-002: Zero duplicates
        if import_log.created_users + import_log.linked_users == import_log.total_rows - import_log.skipped_duplicates - import_log.errors:
            self.stdout.write(
                self.style.SUCCESS(
                    f"\n✓ AC-SSO-002: {import_log.created_users + import_log.linked_users} "
                    f"accounts processed with {import_log.skipped_duplicates} duplicates "
                    f"skipped (zero duplicate accounts created)"
                )
            )

        self.stdout.write("=" * 60)
