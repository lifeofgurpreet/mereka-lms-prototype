"""
Validation functions for MCT video migration.

Covers acceptance criteria AC-VID-001 through AC-VID-006.
"""
import json
import logging
import random
from datetime import datetime

from django.conf import settings
from django.utils import timezone

from .mux_client import check_playback_url, get_asset_metadata
from .models import MctVideoMapping, MigrationReport

logger = logging.getLogger(__name__)


def validate_manifest(manifest_path):
    """
    Validate MCT migration manifest file.

    AC-VID-001: Ensures manifest has exactly 503 entries, each with asset_id and playback_id.

    Args:
        manifest_path (str): Path to JSON manifest file

    Returns:
        dict: Validation results with keys:
            - total: Total entries in manifest
            - valid: Entries with both asset_id and playback_id
            - invalid: Entries missing required fields
            - missing_asset_ids: List of entries missing asset_id
            - missing_playback_ids: List of entries missing playback_id
    """
    try:
        with open(manifest_path, 'r') as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logger.error(f"Failed to read manifest {manifest_path}: {e}")
        return {
            'total': 0,
            'valid': 0,
            'invalid': 0,
            'missing_asset_ids': [],
            'missing_playback_ids': [],
        }

    if not isinstance(data, list):
        logger.error(f"Manifest is not a list: {type(data)}")
        return {
            'total': 0,
            'valid': 0,
            'invalid': 0,
            'missing_asset_ids': [],
            'missing_playback_ids': [],
        }

    total = len(data)
    valid = 0
    missing_asset_ids = []
    missing_playback_ids = []

    for i, entry in enumerate(data):
        has_asset = 'asset_id' in entry and entry['asset_id']
        has_playback = 'playback_id' in entry and entry['playback_id']

        if has_asset and has_playback:
            valid += 1
        else:
            if not has_asset:
                missing_asset_ids.append(i)
            if not has_playback:
                missing_playback_ids.append(i)

    invalid = total - valid

    # AC-VID-001: Warn if not exactly 503 entries
    expected_count = getattr(settings, 'MCT_EXPECTED_VIDEO_COUNT', 503)
    if total != expected_count:
        logger.warning(
            f"Manifest has {total} entries, expected {expected_count} from MCT migration"
        )

    return {
        'total': total,
        'valid': valid,
        'invalid': invalid,
        'missing_asset_ids': missing_asset_ids,
        'missing_playback_ids': missing_playback_ids,
    }


def validate_olx_mappings(mappings_queryset):
    """
    Validate OLX usage key mappings.

    Args:
        mappings_queryset: QuerySet of MctVideoMapping instances

    Returns:
        dict: Validation results with keys:
            - total: Total mappings
            - mapped: Mappings with valid olx_usage_key
            - unmapped: Mappings without olx_usage_key
            - unmapped_ids: List of mct_video_ids without OLX mapping
    """
    total = mappings_queryset.count()
    mapped = mappings_queryset.exclude(olx_usage_key__isnull=True).exclude(
        olx_usage_key=''
    ).count()
    unmapped = total - mapped

    unmapped_ids = list(
        mappings_queryset.filter(olx_usage_key__isnull=True)
        .values_list('mct_video_id', flat=True)
    )
    unmapped_ids.extend(
        list(
            mappings_queryset.filter(olx_usage_key='')
            .values_list('mct_video_id', flat=True)
        )
    )

    return {
        'total': total,
        'mapped': mapped,
        'unmapped': unmapped,
        'unmapped_ids': unmapped_ids,
    }


def validate_playback_health(mappings_queryset, sample_size=None):
    """
    Validate playback health for video mappings.

    AC-VID-002: Checks playback URLs and updates playback_verified status.

    Args:
        mappings_queryset: QuerySet of MctVideoMapping instances
        sample_size (int, optional): If set, randomly sample this many videos

    Returns:
        dict: Validation results with keys:
            - total_checked: Number of videos checked
            - passed: Videos with successful playback
            - failed: Videos with failed playback
            - failed_ids: List of mct_video_ids that failed
    """
    mappings = list(mappings_queryset)

    # Sample if requested
    if sample_size and sample_size < len(mappings):
        mappings = random.sample(mappings, sample_size)

    total_checked = len(mappings)
    passed = 0
    failed = 0
    failed_ids = []

    timeout = getattr(settings, 'VIDEO_PLAYBACK_CHECK_TIMEOUT', 10)
    logger.info(f"Checking playback health for {total_checked} videos (timeout={timeout}s)")

    for mapping in mappings:
        if not mapping.mux_playback_id:
            logger.warning(f"Skipping {mapping.mct_video_id}: no playback_id")
            failed += 1
            failed_ids.append(mapping.mct_video_id)
            continue

        http_status, is_ok = check_playback_url(mapping.mux_playback_id)

        # Update mapping
        mapping.last_health_check = timezone.now()
        mapping.health_check_http_status = http_status
        mapping.playback_verified = is_ok
        mapping.save(update_fields=['last_health_check', 'health_check_http_status', 'playback_verified'])

        if is_ok:
            passed += 1
        else:
            failed += 1
            failed_ids.append(mapping.mct_video_id)

    return {
        'total_checked': total_checked,
        'passed': passed,
        'failed': failed,
        'failed_ids': failed_ids,
    }


def validate_content_languages(mappings_queryset):
    """
    Validate content language coverage.

    AC-VID-005: Ensures EN, VI, ID content all have representative videos.

    Args:
        mappings_queryset: QuerySet of MctVideoMapping instances

    Returns:
        dict: Validation results with keys:
            - languages_found: List of languages found
            - coverage: Dict mapping language -> count
    """
    expected_languages = ['en', 'vi', 'id']
    coverage = {}

    for lang in expected_languages:
        count = mappings_queryset.filter(content_language=lang).count()
        coverage[lang] = count

    languages_found = [lang for lang, count in coverage.items() if count > 0]

    return {
        'languages_found': languages_found,
        'coverage': coverage,
    }


def generate_migration_report(manifest_path=None):
    """
    Generate comprehensive migration validation report.

    AC-VID-006: Creates MigrationReport record with full validation data.

    Args:
        manifest_path (str, optional): Path to manifest file

    Returns:
        dict: Complete migration report
    """
    logger.info("Generating migration report")

    # Get all mappings
    mappings = MctVideoMapping.objects.all()

    # Status breakdown
    total_found = mappings.count()
    total_ready = mappings.filter(mux_status='ready').count()
    total_preparing = mappings.filter(mux_status='preparing').count()
    total_errored = mappings.filter(mux_status='errored').count()
    total_playback_verified = mappings.filter(playback_verified=True).count()

    # Failed asset IDs (errored status)
    failed_asset_ids = list(
        mappings.filter(mux_status='errored').values_list('mux_asset_id', flat=True)
    )

    # Validate manifest if provided
    manifest_validation = {}
    if manifest_path:
        manifest_validation = validate_manifest(manifest_path)

    # Validate OLX mappings
    olx_validation = validate_olx_mappings(mappings)

    # Validate language coverage
    language_validation = validate_content_languages(mappings)

    # Expected count
    expected_count = getattr(settings, 'MCT_EXPECTED_VIDEO_COUNT', 503)

    # Build report data
    report_data = {
        'manifest_validation': manifest_validation,
        'olx_validation': olx_validation,
        'language_validation': language_validation,
        'status_breakdown': {
            'ready': total_ready,
            'preparing': total_preparing,
            'errored': total_errored,
        },
        'playback_health': {
            'verified': total_playback_verified,
            'total': total_found,
        },
        'generated_at': timezone.now().isoformat(),
    }

    # Check if migration is complete
    is_complete = total_ready == expected_count

    # Create MigrationReport record
    report = MigrationReport.objects.create(
        total_expected=expected_count,
        total_found=total_found,
        total_ready=total_ready,
        total_preparing=total_preparing,
        total_errored=total_errored,
        total_playback_verified=total_playback_verified,
        failed_asset_ids=failed_asset_ids,
        report_data=report_data,
        is_complete=is_complete,
    )

    logger.info(f"Migration report created: {report.report_id}")

    return {
        'report_id': str(report.report_id),
        'total_expected': expected_count,
        'total_found': total_found,
        'total_ready': total_ready,
        'total_preparing': total_preparing,
        'total_errored': total_errored,
        'total_playback_verified': total_playback_verified,
        'failed_asset_ids': failed_asset_ids,
        'is_complete': is_complete,
        'report_data': report_data,
    }
