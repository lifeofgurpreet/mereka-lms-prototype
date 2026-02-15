import json
import os
import sys

from django.core.management.base import BaseCommand

from openedx_video_pipeline.validators import (
    generate_migration_report,
    validate_playback_health,
)
from openedx_video_pipeline.models import MctVideoMapping
from openedx_video_pipeline.mux_client import get_asset_metadata


class Command(BaseCommand):
    help = 'Validate MCT video migration status and health'

    def add_arguments(self, parser):
        parser.add_argument(
            '--manifest',
            type=str,
            default='exports/mct/mux_upload_complete.json',
            help='Path to mux_upload_complete.json manifest',
        )
        parser.add_argument(
            '--check-playback',
            action='store_true',
            help='Run playback health checks',
        )
        parser.add_argument(
            '--sample-size',
            type=int,
            default=10,
            help='Number of videos to spot-check for playback (default: 10)',
        )
        parser.add_argument(
            '--refresh-metadata',
            action='store_true',
            help='Pull latest metadata from Mux API',
        )
        parser.add_argument(
            '--output',
            type=str,
            help='Path to write JSON report',
        )

    def handle(self, *args, **options):
        manifest_path = options['manifest']
        check_playback = options['check_playback']
        sample_size = options['sample_size']
        refresh_metadata = options['refresh_metadata']
        output_path = options['output']

        self.stdout.write(self.style.SUCCESS('=== MCT Video Migration Validation ===\n'))

        # Refresh metadata if requested
        if refresh_metadata:
            self.stdout.write('Refreshing metadata from Mux API...')
            mappings = MctVideoMapping.objects.all()
            updated = 0

            for mapping in mappings:
                metadata = get_asset_metadata(mapping.mux_asset_id)
                if metadata:
                    mapping.duration_seconds = metadata.get('duration')
                    mapping.max_resolution = metadata.get('max_stored_resolution')
                    mapping.has_audio = metadata.get('has_audio', True)
                    mapping.has_video = metadata.get('has_video', True)
                    mapping.mux_status = metadata.get('status', 'preparing')
                    mapping.save()
                    updated += 1

            self.stdout.write(self.style.SUCCESS(f'Updated metadata for {updated} videos\n'))

        # Run playback health checks if requested
        if check_playback:
            self.stdout.write(f'Running playback health checks (sample_size={sample_size})...')
            mappings = MctVideoMapping.objects.all()
            results = validate_playback_health(mappings, sample_size=sample_size)

            self.stdout.write(self.style.SUCCESS(
                f"Checked: {results['total_checked']}, "
                f"Passed: {results['passed']}, "
                f"Failed: {results['failed']}\n"
            ))

            if results['failed_ids']:
                self.stdout.write(self.style.WARNING(
                    f"Failed IDs: {', '.join(results['failed_ids'][:10])}"
                    f"{'...' if len(results['failed_ids']) > 10 else ''}\n"
                ))

        # Generate migration report
        self.stdout.write('Generating migration report...')

        # Check if manifest exists
        manifest_exists = os.path.exists(manifest_path)
        if manifest_exists:
            report = generate_migration_report(manifest_path=manifest_path)
        else:
            self.stdout.write(self.style.WARNING(
                f'Manifest not found at {manifest_path}, generating report without manifest validation'
            ))
            report = generate_migration_report()

        # Print summary
        self.stdout.write('\n' + '=' * 50)
        self.stdout.write(self.style.SUCCESS('MIGRATION REPORT SUMMARY'))
        self.stdout.write('=' * 50)
        self.stdout.write(f"Total Expected: {report['total_expected']}")
        self.stdout.write(f"Total Found: {report['total_found']}")
        self.stdout.write(f"Ready: {report['total_ready']}")
        self.stdout.write(f"Preparing: {report['total_preparing']}")
        self.stdout.write(f"Errored: {report['total_errored']}")
        self.stdout.write(f"Playback Verified: {report['total_playback_verified']}")
        self.stdout.write(f"Is Complete: {report['is_complete']}")
        self.stdout.write('=' * 50 + '\n')

        # Print manifest validation if available
        if manifest_exists and 'report_data' in report:
            manifest_val = report['report_data'].get('manifest_validation', {})
            if manifest_val:
                self.stdout.write('Manifest Validation:')
                self.stdout.write(f"  Total entries: {manifest_val.get('total', 0)}")
                self.stdout.write(f"  Valid: {manifest_val.get('valid', 0)}")
                self.stdout.write(f"  Invalid: {manifest_val.get('invalid', 0)}\n")

        # Print language coverage
        if 'report_data' in report:
            lang_val = report['report_data'].get('language_validation', {})
            if lang_val:
                self.stdout.write('Language Coverage:')
                coverage = lang_val.get('coverage', {})
                for lang, count in coverage.items():
                    self.stdout.write(f"  {lang.upper()}: {count} videos")
                self.stdout.write('')

        # Write output file if requested
        if output_path:
            with open(output_path, 'w') as f:
                json.dump(report, f, indent=2, default=str)
            self.stdout.write(self.style.SUCCESS(f'Report written to {output_path}'))

        # Exit with appropriate code
        if report['total_errored'] > 0:
            self.stdout.write(self.style.ERROR(
                f"\n{report['total_errored']} videos have errored status"
            ))
            sys.exit(1)
        elif not report['is_complete']:
            self.stdout.write(self.style.WARNING(
                f"\nMigration incomplete: {report['total_ready']}/{report['total_expected']} ready"
            ))
            sys.exit(1)
        else:
            self.stdout.write(self.style.SUCCESS('\nAll checks passed!'))
            sys.exit(0)
