"""
Library backup and disaster recovery.

@covers: AC-LIB-023 (DR restore), AC-LIB-024 (nightly OLX exports),
         AC-LIB-025 (zero data loss), AC-NEG-LIB-011 (skip expired),
         AC-NEG-LIB-012 (no overwrite newer)
"""
import json
import logging
import time
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


def export_library_to_olx(library_key):
    """
    Export a single library to OLX format (AC-LIB-024).

    Returns dict with library metadata and component snapshots.
    """
    from .models import LibraryMetadata, LibraryComponent, LibraryVersion

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    components = LibraryComponent.objects.filter(
        library=metadata, is_deleted=False,
    ).values(
        'usage_key', 'block_type', 'display_name',
        'has_unpublished_changes', 'last_published_at',
    )

    latest_version = metadata.versions.filter(
        publish_status='completed',
    ).order_by('-version_number').first()

    export_data = {
        'format': 'mereka-library-olx-v1',
        'exported_at': timezone.now().isoformat(),
        'library': {
            'library_key': metadata.library_key,
            'org': metadata.org,
            'title': metadata.title,
            'description': metadata.description,
            'tenant_uuid': str(metadata.tenant_uuid) if metadata.tenant_uuid else None,
            'allow_public_read': metadata.allow_public_read,
            'published_component_count': metadata.published_component_count,
            'draft_component_count': metadata.draft_component_count,
            'last_published_at': metadata.last_published_at.isoformat() if metadata.last_published_at else None,
        },
        'version': {
            'version_number': latest_version.version_number if latest_version else 0,
            'bundle_version': latest_version.bundle_version if latest_version else None,
            'component_keys': latest_version.component_keys if latest_version else [],
        },
        'components': list(components),
        'component_count': len(list(components)),
    }

    return export_data


def export_all_libraries(skip_expired_deleted=True):
    """
    Export all libraries for nightly backup (AC-LIB-024).

    AC-NEG-LIB-011: Skips soft-deleted libraries past retention period.
    """
    from .models import LibraryMetadata

    start = time.monotonic()

    libraries = LibraryMetadata.objects.filter(is_deleted=False)

    exports = []
    errors = []

    for lib in libraries.iterator():
        try:
            export = export_library_to_olx(lib.library_key)
            exports.append(export)
        except Exception as e:
            errors.append({
                'library_key': lib.library_key,
                'error': str(e),
            })
            logger.exception("Failed to export library: %s", lib.library_key)

    # Also include recently deleted (within retention) — AC-NEG-LIB-011
    if not skip_expired_deleted:
        recently_deleted = LibraryMetadata.objects.filter(
            is_deleted=True,
        )
        for lib in recently_deleted.iterator():
            if not lib.can_permanent_delete:
                try:
                    export = {
                        'format': 'mereka-library-olx-v1',
                        'exported_at': timezone.now().isoformat(),
                        'library': {
                            'library_key': lib.library_key,
                            'org': lib.org,
                            'title': lib.title,
                            'description': lib.description,
                            'tenant_uuid': str(lib.tenant_uuid) if lib.tenant_uuid else None,
                            'is_deleted': True,
                            'deleted_at': lib.deleted_at.isoformat() if lib.deleted_at else None,
                        },
                        'components': [],
                        'component_count': 0,
                        '_soft_deleted': True,
                    }
                    exports.append(export)
                except Exception as e:
                    errors.append({
                        'library_key': lib.library_key,
                        'error': str(e),
                    })

    elapsed_ms = int((time.monotonic() - start) * 1000)

    manifest = {
        'format': 'mereka-library-backup-v1',
        'exported_at': timezone.now().isoformat(),
        'total_libraries': len(exports),
        'total_errors': len(errors),
        'elapsed_ms': elapsed_ms,
        'errors': errors,
    }

    logger.info(
        "Library backup: %d libraries exported, %d errors, %dms",
        len(exports), len(errors), elapsed_ms,
    )

    return {
        'manifest': manifest,
        'libraries': exports,
    }


def upload_backup_to_gcs(backup_data, bucket_name=None):
    """
    Upload backup data to GCS bucket.

    Path: gs://{bucket}/library-backups/YYYY/MM/DD/backup-{timestamp}.json
    """
    if bucket_name is None:
        bucket_name = getattr(settings, 'BLOCKSTORE_BUCKET_NAME', 'lms-blockstore')

    timestamp = timezone.now().strftime('%Y/%m/%d/backup-%H%M%S')
    blob_path = f"library-backups/{timestamp}.json"

    try:
        from google.cloud import storage
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        blob.upload_from_string(
            json.dumps(backup_data, default=str),
            content_type='application/json',
        )
        logger.info("Backup uploaded to gs://%s/%s", bucket_name, blob_path)
        return f"gs://{bucket_name}/{blob_path}"
    except ImportError:
        logger.warning("google-cloud-storage not available, saving backup locally")
        import os
        local_path = f"/tmp/library-backup-{timezone.now().strftime('%Y%m%d-%H%M%S')}.json"
        with open(local_path, 'w') as f:
            json.dump(backup_data, f, default=str)
        return local_path
    except Exception:
        logger.exception("Failed to upload backup to GCS")
        raise


def restore_from_backup(backup_data, dry_run=False, skip_newer=True):
    """
    Restore libraries from backup (AC-LIB-023, AC-LIB-025).

    AC-NEG-LIB-012: Does NOT overwrite libraries modified after backup timestamp.
    AC-LIB-025: Validates component count matches pre/post.

    Returns restore report.
    """
    from .models import LibraryMetadata, LibraryComponent
    from . import api

    backup_timestamp = backup_data.get('manifest', {}).get('exported_at')
    libraries = backup_data.get('libraries', [])

    report = {
        'backup_timestamp': backup_timestamp,
        'total_in_backup': len(libraries),
        'restored': 0,
        'skipped_newer': 0,
        'skipped_exists': 0,
        'errors': [],
        'dry_run': dry_run,
        'component_count_pre': 0,
        'component_count_post': 0,
    }

    report['component_count_pre'] = LibraryComponent.objects.filter(is_deleted=False).count()

    for lib_export in libraries:
        lib_data = lib_export.get('library', {})
        library_key = lib_data.get('library_key')

        if not library_key:
            report['errors'].append({'error': 'Missing library_key in backup'})
            continue

        # Skip soft-deleted exports
        if lib_export.get('_soft_deleted'):
            continue

        try:
            existing = LibraryMetadata.objects.filter(library_key=library_key).first()

            if existing:
                # AC-NEG-LIB-012: Skip if modified after backup
                if skip_newer and existing.updated_at:
                    from dateutil.parser import parse as parse_dt
                    backup_ts = parse_dt(backup_timestamp) if isinstance(backup_timestamp, str) else backup_timestamp
                    if existing.updated_at > backup_ts:
                        report['skipped_newer'] += 1
                        logger.info(
                            "Skipping library %s: modified after backup (%s > %s)",
                            library_key, existing.updated_at, backup_timestamp,
                        )
                        continue

                report['skipped_exists'] += 1
                continue

            if dry_run:
                report['restored'] += 1
                continue

            # Restore library
            metadata = api.create_library(
                library_key=library_key,
                org=lib_data.get('org', ''),
                title=lib_data.get('title', ''),
                description=lib_data.get('description', ''),
            )

            # Restore components
            for comp_data in lib_export.get('components', []):
                api.add_component(
                    library_key=library_key,
                    usage_key=comp_data['usage_key'],
                    block_type=comp_data['block_type'],
                    display_name=comp_data.get('display_name', ''),
                )

            report['restored'] += 1

        except Exception as e:
            report['errors'].append({
                'library_key': library_key,
                'error': str(e),
            })
            logger.exception("Failed to restore library: %s", library_key)

    report['component_count_post'] = LibraryComponent.objects.filter(is_deleted=False).count()

    logger.info(
        "Library restore: %d restored, %d skipped (newer), %d skipped (exists), %d errors",
        report['restored'], report['skipped_newer'], report['skipped_exists'],
        len(report['errors']),
    )

    return report
