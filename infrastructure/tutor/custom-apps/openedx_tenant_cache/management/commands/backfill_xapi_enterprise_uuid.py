"""
Backfill existing xAPI events with enterprise_customer_uuid.

@spec: multi-tenancy-architecture_spec.md
@covers: Historical xAPI events backfilled with enterprise UUID
"""
import logging

from django.core.management.base import BaseCommand

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Backfill existing xAPI events with enterprise_customer_uuid'

    def add_arguments(self, parser):
        parser.add_argument(
            '--enterprise-uuid', required=True,
            help='Enterprise UUID to backfill for',
        )
        parser.add_argument(
            '--org-id', default='',
            help='Organization ID to filter events (e.g., Mereka)',
        )
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Show what would be updated without making changes',
        )
        parser.add_argument(
            '--batch-size', type=int, default=10000,
            help='Number of rows per batch (default: 10000)',
        )

    def handle(self, *args, **options):
        enterprise_uuid = options['enterprise_uuid']
        org_id = options['org_id']
        dry_run = options['dry_run']
        batch_size = options['batch_size']

        self.stdout.write(f'\n=== xAPI Enterprise UUID Backfill ===')
        self.stdout.write(f'  Enterprise UUID: {enterprise_uuid}')
        self.stdout.write(f'  Org ID filter:   {org_id or "(all)"}')
        self.stdout.write(f'  Batch size:      {batch_size}')
        self.stdout.write(f'  Dry run:         {dry_run}')
        self.stdout.write('')

        # First ensure the ClickHouse column exists
        from openedx_tenant_cache.xapi import get_clickhouse_schema_extension
        alter_sql = get_clickhouse_schema_extension()
        self.stdout.write(f'  Column DDL: {alter_sql}')

        try:
            from event_sink_clickhouse.sinks import ClickHouseConnection
            conn = ClickHouseConnection()

            # Step 1: Add column if not exists
            if not dry_run:
                try:
                    conn.execute(alter_sql)
                    self.stdout.write(self.style.SUCCESS('  Column added/verified.'))
                except Exception as e:
                    self.stdout.write(f'  Column check: {e} (may already exist)')

            # Step 2: Count affected rows
            where_clause = "WHERE enterprise_customer_uuid IS NULL"
            if org_id:
                where_clause += f" AND org_id = '{org_id}'"

            count_sql = f"SELECT count() FROM xapi_events_all {where_clause}"
            if not dry_run:
                result = conn.execute(count_sql)
                total = result[0][0] if result else 0
            else:
                total = '(dry run — not queried)'
            self.stdout.write(f'  Events to backfill: {total}')

            if dry_run:
                update_sql = (
                    f"ALTER TABLE xapi_events_all UPDATE "
                    f"enterprise_customer_uuid = '{enterprise_uuid}' "
                    f"{where_clause}"
                )
                self.stdout.write(f'\n  Would execute:\n    {update_sql}\n')
                self.stdout.write(self.style.WARNING('  DRY RUN — no changes made.'))
                return

            # Step 3: Backfill in batches
            update_sql = (
                f"ALTER TABLE xapi_events_all UPDATE "
                f"enterprise_customer_uuid = '{enterprise_uuid}' "
                f"{where_clause}"
            )
            self.stdout.write(f'  Executing backfill...')
            conn.execute(update_sql)
            self.stdout.write(self.style.SUCCESS(
                f'  Backfill complete. {total} events updated.'
            ))

        except ImportError:
            self.stdout.write(self.style.WARNING(
                '  ClickHouse sink not available (event_sink_clickhouse not installed).\n'
                '  Backfill must be run manually with ClickHouse client:\n'
                f'    {alter_sql};\n'
                f'    ALTER TABLE xapi_events_all UPDATE '
                f"enterprise_customer_uuid = '{enterprise_uuid}' "
                f'WHERE enterprise_customer_uuid IS NULL'
                + (f" AND org_id = '{org_id}'" if org_id else '') + ';'
            ))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'  Backfill failed: {e}'))
            raise
