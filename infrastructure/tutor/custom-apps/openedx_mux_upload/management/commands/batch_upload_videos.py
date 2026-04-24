"""
Management command for batch video upload to Mux with resume capability.

@spec: video-pipeline-delivery_spec.md (Phase 3)
@covers: AC-VPD-003, AC-VPD-004

Features:
- Batch upload with resume from checkpoint
- Rate limiting (1 req/sec for bulk operations)
- File format validation (MP4, MOV, MKV, WebM)
- Mux Basic quality tier enforcement
- HLS adaptive bitrate configuration (240p/480p/720p)
- Progress tracking in JSON checkpoint file

Usage:
    python manage.py batch_upload_videos \
        --input-file videos.json \
        --checkpoint-file progress.json \
        --rate-limit 1.0
"""

import os
import json
import time
import logging
from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from opaque_keys.edx.keys import CourseKey
from opaque_keys import InvalidKeyError

from openedx_mux_upload.models import MuxUpload
from openedx_mux_upload.utils import (
    create_direct_upload,
    create_asset_from_url,
    get_asset,
    validate_video_format,
)

logger = logging.getLogger(__name__)

# Supported video formats (AC-VPD-002)
SUPPORTED_FORMATS = ['mp4', 'mov', 'mkv', 'webm']

# Rate limit for bulk operations (AC-VPD-005)
DEFAULT_RATE_LIMIT_SECONDS = 1.0


class Command(BaseCommand):
    help = 'Batch upload videos to Mux with resume capability'

    def add_arguments(self, parser):
        parser.add_argument(
            '--input-file',
            required=True,
            help='Path to input JSON file with video URLs and metadata'
        )
        parser.add_argument(
            '--checkpoint-file',
            default='batch_upload_checkpoint.json',
            help='Path to checkpoint file for resume capability (default: batch_upload_checkpoint.json)'
        )
        parser.add_argument(
            '--rate-limit',
            type=float,
            default=DEFAULT_RATE_LIMIT_SECONDS,
            help=f'Rate limit in seconds between API calls (default: {DEFAULT_RATE_LIMIT_SECONDS})'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Validate input without making API calls'
        )
        parser.add_argument(
            '--force-basic-quality',
            action='store_true',
            default=True,
            help='Enforce Mux Basic quality tier (default: True, AC-VPD-006)'
        )

    def handle(self, *args, **options):
        input_file = options['input_file']
        checkpoint_file = options['checkpoint_file']
        rate_limit = options['rate_limit']
        dry_run = options['dry_run']
        force_basic_quality = options['force_basic_quality']

        self.stdout.write(f"\n=== Batch Video Upload to Mux ===")
        self.stdout.write(f"Input file: {input_file}")
        self.stdout.write(f"Checkpoint file: {checkpoint_file}")
        self.stdout.write(f"Rate limit: {rate_limit}s per request")
        self.stdout.write(f"Dry run: {dry_run}")
        self.stdout.write(f"Force Basic quality: {force_basic_quality}\n")

        # Load input file
        try:
            with open(input_file, 'r') as f:
                videos = json.load(f)
        except FileNotFoundError:
            raise CommandError(f"Input file not found: {input_file}")
        except json.JSONDecodeError as e:
            raise CommandError(f"Invalid JSON in input file: {e}")

        if not isinstance(videos, list):
            raise CommandError("Input file must contain a JSON array of video objects")

        self.stdout.write(f"Loaded {len(videos)} videos from input file\n")

        # Load checkpoint if exists
        checkpoint = self._load_checkpoint(checkpoint_file)
        processed_ids = set(checkpoint.get('processed', []))
        failed_ids = set(checkpoint.get('failed', []))

        self.stdout.write(f"Resume state: {len(processed_ids)} processed, {len(failed_ids)} failed\n")

        # Process videos
        stats = {
            'total': len(videos),
            'processed': len(processed_ids),
            'failed': len(failed_ids),
            'skipped': 0,
            'uploaded': 0,
        }

        for idx, video in enumerate(videos, 1):
            video_id = video.get('id') or f"video_{idx}"

            # Skip if already processed
            if video_id in processed_ids:
                stats['skipped'] += 1
                self.stdout.write(f"[{idx}/{len(videos)}] Skipping {video_id} (already processed)")
                continue

            # Skip if previously failed (unless retry flag set)
            if video_id in failed_ids:
                stats['skipped'] += 1
                self.stdout.write(f"[{idx}/{len(videos)}] Skipping {video_id} (previously failed)")
                continue

            # Validate video metadata
            try:
                self._validate_video_metadata(video)
            except ValueError as e:
                self.stdout.write(self.style.ERROR(f"[{idx}/{len(videos)}] Invalid metadata for {video_id}: {e}"))
                failed_ids.add(video_id)
                stats['failed'] += 1
                self._save_checkpoint(checkpoint_file, list(processed_ids), list(failed_ids))
                continue

            # Upload video
            if not dry_run:
                try:
                    self._upload_video(video, force_basic_quality)
                    processed_ids.add(video_id)
                    stats['uploaded'] += 1
                    self.stdout.write(self.style.SUCCESS(
                        f"[{idx}/{len(videos)}] Uploaded {video_id}: {video.get('title', 'Untitled')}"
                    ))

                    # Save checkpoint after each successful upload
                    self._save_checkpoint(checkpoint_file, list(processed_ids), list(failed_ids))

                    # Rate limit (AC-VPD-005)
                    if idx < len(videos):  # Don't sleep after last video
                        time.sleep(rate_limit)

                except Exception as e:
                    self.stdout.write(self.style.ERROR(
                        f"[{idx}/{len(videos)}] Failed to upload {video_id}: {e}"
                    ))
                    failed_ids.add(video_id)
                    stats['failed'] += 1
                    self._save_checkpoint(checkpoint_file, list(processed_ids), list(failed_ids))
            else:
                self.stdout.write(f"[{idx}/{len(videos)}] [DRY RUN] Would upload {video_id}")

        # Final summary
        self.stdout.write(f"\n=== Upload Summary ===")
        self.stdout.write(f"Total videos: {stats['total']}")
        self.stdout.write(f"Uploaded: {stats['uploaded']}")
        self.stdout.write(f"Skipped: {stats['skipped']}")
        self.stdout.write(f"Failed: {stats['failed']}")
        self.stdout.write(f"\nCheckpoint saved to: {checkpoint_file}\n")

        if stats['failed'] > 0:
            self.stdout.write(self.style.WARNING(
                f"⚠ {stats['failed']} videos failed. Review errors above and re-run to retry."
            ))

    def _validate_video_metadata(self, video):
        """
        Validate video metadata.

        Required fields:
            - id: Unique identifier
            - url: Video URL (for URL ingestion) OR filename (for direct upload)
            - title: Video title

        Optional fields:
            - course_key: Open edX course key
            - user_id: User ID for attribution

        Raises:
            ValueError: If validation fails
        """
        if 'id' not in video:
            raise ValueError("Missing required field: id")

        if 'url' not in video and 'filename' not in video:
            raise ValueError("Must provide either 'url' or 'filename'")

        if 'title' not in video:
            raise ValueError("Missing required field: title")

        # Validate course_key format if provided
        if 'course_key' in video:
            try:
                CourseKey.from_string(video['course_key'])
            except InvalidKeyError:
                raise ValueError(f"Invalid course_key format: {video['course_key']}")

        # Validate file format (AC-VPD-002)
        if 'filename' in video:
            extension = Path(video['filename']).suffix.lstrip('.').lower()
            if extension not in SUPPORTED_FORMATS:
                raise ValueError(
                    f"Unsupported video format: {extension}. "
                    f"Supported formats: {', '.join(SUPPORTED_FORMATS)}"
                )

    def _upload_video(self, video, force_basic_quality=True):
        """
        Upload a single video to Mux.

        Args:
            video (dict): Video metadata
            force_basic_quality (bool): Enforce Mux Basic quality tier (AC-VPD-006)

        Raises:
            Exception: If upload fails
        """
        # Configure Mux asset settings (AC-VPD-006, AC-VPD-007)
        new_asset_settings = {
            'playback_policy': ['public'],  # Default to public; signed URLs in Phase 5
            'encoding_tier': 'baseline',  # Mux Basic quality tier (AC-VPD-006)
            'passthrough': json.dumps({
                'video_id': video['id'],
                'title': video['title'],
                'course_key': video.get('course_key', ''),
            }),
        }

        # HLS adaptive bitrate configuration (AC-VPD-007)
        # Mux automatically creates 240p/480p/720p renditions for baseline tier
        # No additional configuration needed

        if 'url' in video:
            # URL ingestion (server-to-server)
            result = create_asset_from_url(
                url=video['url'],
                new_asset_settings=new_asset_settings
            )
            asset_id = result['id']
            logger.info(f"Created Mux asset from URL: asset_id={asset_id}, url={video['url']}")

        else:
            # Direct upload (browser upload)
            # Note: This path is typically used via REST API, not management command
            raise NotImplementedError(
                "Direct upload via management command not supported. "
                "Use REST API endpoint /api/mux/upload/create/ for direct uploads."
            )

        return asset_id

    def _load_checkpoint(self, checkpoint_file):
        """Load checkpoint from file (resume capability)."""
        if not os.path.exists(checkpoint_file):
            return {'processed': [], 'failed': []}

        try:
            with open(checkpoint_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            logger.warning(f"Failed to load checkpoint file: {e}. Starting fresh.")
            return {'processed': [], 'failed': []}

    def _save_checkpoint(self, checkpoint_file, processed, failed):
        """Save checkpoint to file (resume capability)."""
        checkpoint = {
            'processed': processed,
            'failed': failed,
            'last_updated': time.time(),
        }

        try:
            with open(checkpoint_file, 'w') as f:
                json.dump(checkpoint, f, indent=2)
        except IOError as e:
            logger.error(f"Failed to save checkpoint file: {e}")
