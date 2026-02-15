import json

from django.core.management.base import BaseCommand

from openedx_video_pipeline.models import MctVideoMapping


class Command(BaseCommand):
    help = 'Import Mux manifest file into MctVideoMapping records'

    def add_arguments(self, parser):
        parser.add_argument(
            '--manifest',
            type=str,
            required=True,
            help='Path to JSON manifest file',
        )
        parser.add_argument(
            '--batch',
            type=str,
            default='mct-2025-12-29',
            help='Migration batch identifier (default: mct-2025-12-29)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Dry run mode (do not save to database)',
        )

    def handle(self, *args, **options):
        manifest_path = options['manifest']
        batch = options['batch']
        dry_run = options['dry_run']

        self.stdout.write(self.style.SUCCESS(f'=== Importing Mux Manifest: {manifest_path} ===\n'))

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN MODE - No changes will be saved\n'))

        # Read manifest file
        try:
            with open(manifest_path, 'r') as f:
                data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            self.stdout.write(self.style.ERROR(f'Failed to read manifest: {e}'))
            return

        if not isinstance(data, list):
            self.stdout.write(self.style.ERROR(f'Manifest is not a list: {type(data)}'))
            return

        created_count = 0
        updated_count = 0
        skipped_count = 0

        for entry in data:
            asset_id = entry.get('asset_id')
            playback_id = entry.get('playback_id')

            if not asset_id:
                self.stdout.write(self.style.WARNING(f'Skipping entry without asset_id: {entry}'))
                skipped_count += 1
                continue

            # Extract optional fields
            mct_video_id = entry.get('mct_video_id', asset_id)
            filename = entry.get('filename', entry.get('original_filename'))
            course_key = entry.get('course_key', 'unknown')
            language = entry.get('language', entry.get('content_language'))

            # Prepare defaults for get_or_create
            defaults = {
                'mux_playback_id': playback_id,
                'course_key': course_key,
                'migration_batch': batch,
            }

            if filename:
                defaults['original_filename'] = filename
            if language:
                defaults['content_language'] = language

            if dry_run:
                # Check if exists
                exists = MctVideoMapping.objects.filter(mux_asset_id=asset_id).exists()
                if exists:
                    self.stdout.write(f'[DRY RUN] Would update: {mct_video_id} ({asset_id})')
                    updated_count += 1
                else:
                    self.stdout.write(f'[DRY RUN] Would create: {mct_video_id} ({asset_id})')
                    created_count += 1
            else:
                # Create or update
                mapping, created = MctVideoMapping.objects.get_or_create(
                    mux_asset_id=asset_id,
                    defaults={
                        'mct_video_id': mct_video_id,
                        **defaults,
                    }
                )

                if created:
                    created_count += 1
                    self.stdout.write(self.style.SUCCESS(f'Created: {mct_video_id} ({asset_id})'))
                else:
                    # Update existing record
                    for key, value in defaults.items():
                        setattr(mapping, key, value)
                    mapping.save()
                    updated_count += 1
                    self.stdout.write(f'Updated: {mct_video_id} ({asset_id})')

        # Print summary
        self.stdout.write('\n' + '=' * 50)
        self.stdout.write(self.style.SUCCESS('IMPORT SUMMARY'))
        self.stdout.write('=' * 50)
        self.stdout.write(f'Total entries: {len(data)}')
        self.stdout.write(f'Created: {created_count}')
        self.stdout.write(f'Updated: {updated_count}')
        self.stdout.write(f'Skipped: {skipped_count}')
        self.stdout.write('=' * 50)

        if dry_run:
            self.stdout.write(self.style.WARNING('\nDRY RUN - No changes were saved'))
        else:
            self.stdout.write(self.style.SUCCESS('\nImport completed successfully'))
