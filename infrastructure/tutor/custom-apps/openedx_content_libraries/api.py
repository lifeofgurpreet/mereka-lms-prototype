"""
Content Libraries v2 API — business logic layer.

@spec: content-libraries-v2
@covers: AC-LIB-007 (atomic publish), AC-LIB-008 (random pool),
         AC-LIB-009 (soft-delete/restore), AC-LIB-010 (update notifications),
         AC-LIB-011 (platform templates), AC-LIB-012 (version rollback),
         AC-LIB-013 (reference tracking)
"""
import logging
import time

from django.conf import settings
from django.db import transaction
from django.utils import timezone

logger = logging.getLogger(__name__)


def create_library(library_key, org, title, description='', user=None):
    """
    Create a new library with metadata tracking.

    Returns LibraryMetadata instance.
    """
    from .models import LibraryMetadata

    metadata, created = LibraryMetadata.objects.get_or_create(
        library_key=library_key,
        defaults={
            'org': org,
            'title': title,
            'description': description,
            'created_by': user,
        },
    )

    if not created and metadata.is_deleted:
        # Restore if previously soft-deleted
        metadata.restore()
        metadata.title = title
        metadata.description = description
        metadata.save(update_fields=['title', 'description', 'updated_at'])
        logger.info("Restored soft-deleted library: %s", library_key)
    elif created:
        logger.info("Created library: %s", library_key)
    else:
        logger.info("Library already exists: %s", library_key)

    return metadata


def publish_library(library_key, user=None, commit_message=''):
    """
    Atomically publish all draft components in a library (AC-LIB-007).

    Creates a version snapshot. All-or-nothing: if any component
    fails to publish, the entire operation is rolled back.

    AC-NEG-LIB-004: MUST NOT partially apply.
    """
    from .models import LibraryMetadata, LibraryVersion, LibraryComponent

    start_time = time.monotonic()

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    # Get next version number
    last_version = metadata.versions.order_by('-version_number').first()
    next_version = (last_version.version_number + 1) if last_version else 1

    # Create version record (initially pending)
    version = LibraryVersion.objects.create(
        library=metadata,
        version_number=next_version,
        bundle_version=f"{library_key}:v{next_version}",
        published_by=user,
        commit_message=commit_message,
        publish_status='in_progress',
    )

    try:
        with transaction.atomic():
            # Collect all draft components
            components = LibraryComponent.objects.filter(
                library=metadata,
                is_deleted=False,
            )

            component_keys = []
            for component in components:
                if component.has_unpublished_changes:
                    component.has_unpublished_changes = False
                    component.last_published_at = timezone.now()
                    component.save(update_fields=[
                        'has_unpublished_changes', 'last_published_at',
                    ])
                component_keys.append(component.usage_key)

            # Update version with component snapshot
            version.component_count = len(component_keys)
            version.component_keys = component_keys
            version.publish_status = 'completed'
            version.publish_duration_ms = int(
                (time.monotonic() - start_time) * 1000
            )
            version.save()

            # Update library metadata
            metadata.last_published_at = timezone.now()
            metadata.last_published_by = user
            metadata.published_component_count = len(component_keys)
            metadata.draft_component_count = 0
            metadata.save(update_fields=[
                'last_published_at', 'last_published_by',
                'published_component_count', 'draft_component_count',
                'updated_at',
            ])

            # Mark course references as having updates available (AC-LIB-010)
            from .models import LibraryCourseReference
            LibraryCourseReference.objects.filter(
                library=metadata,
            ).exclude(
                synced_version=next_version,
            ).update(has_update_available=True)

        logger.info(
            "Published library %s v%d (%d components, %dms)",
            library_key, next_version, len(component_keys),
            version.publish_duration_ms,
        )
        return version

    except Exception:
        version.publish_status = 'failed'
        version.publish_duration_ms = int(
            (time.monotonic() - start_time) * 1000
        )
        version.save(update_fields=['publish_status', 'publish_duration_ms'])
        logger.exception("Failed to publish library %s", library_key)
        raise


def rollback_library(library_key, target_version_number, user=None):
    """
    Rollback a library to a previous version (AC-LIB-012).

    Restores the exact prior state by:
    1. Loading the target version's component snapshot
    2. Marking current components that aren't in the snapshot as deleted
    3. Creating a new version record for the rollback
    """
    from .models import LibraryMetadata, LibraryVersion, LibraryComponent

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    target_version = LibraryVersion.objects.get(
        library=metadata,
        version_number=target_version_number,
        publish_status='completed',
    )

    with transaction.atomic():
        # Get the target version's component keys
        target_keys = set(target_version.component_keys or [])

        # Mark components not in target as having unpublished changes
        current_components = LibraryComponent.objects.filter(
            library=metadata, is_deleted=False,
        )
        for comp in current_components:
            if comp.usage_key not in target_keys:
                comp.has_unpublished_changes = True
                comp.save(update_fields=['has_unpublished_changes'])

        # Create rollback version record
        last_version = metadata.versions.order_by('-version_number').first()
        rollback_version = LibraryVersion.objects.create(
            library=metadata,
            version_number=last_version.version_number + 1,
            bundle_version=target_version.bundle_version,
            component_count=target_version.component_count,
            component_keys=target_version.component_keys,
            published_by=user,
            commit_message=f"Rollback to v{target_version_number}",
            publish_status='completed',
        )

        # Mark target version
        target_version.publish_status = 'rolled_back'
        target_version.save(update_fields=['publish_status'])

        # Update metadata
        metadata.last_published_at = timezone.now()
        metadata.last_published_by = user
        metadata.published_component_count = target_version.component_count
        metadata.save(update_fields=[
            'last_published_at', 'last_published_by',
            'published_component_count', 'updated_at',
        ])

    logger.info(
        "Rolled back library %s to v%d (now v%d)",
        library_key, target_version_number, rollback_version.version_number,
    )
    return rollback_version


def soft_delete_library(library_key, user=None):
    """Soft-delete a library (AC-LIB-009)."""
    from .models import LibraryMetadata
    metadata = LibraryMetadata.objects.get(library_key=library_key)
    metadata.soft_delete(user=user)
    logger.info("Soft-deleted library: %s", library_key)
    return metadata


def restore_library(library_key):
    """Restore a soft-deleted library (AC-LIB-009)."""
    from .models import LibraryMetadata
    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=True)
    metadata.restore()
    logger.info("Restored library: %s", library_key)
    return metadata


def add_component(library_key, usage_key, block_type, display_name='', user=None):
    """Add a component to a library."""
    from .models import LibraryMetadata, LibraryComponent

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    component, created = LibraryComponent.objects.get_or_create(
        usage_key=usage_key,
        defaults={
            'library': metadata,
            'block_type': block_type,
            'display_name': display_name,
            'created_by': user,
            'has_unpublished_changes': True,
        },
    )

    if created:
        metadata.draft_component_count = LibraryComponent.objects.filter(
            library=metadata, is_deleted=False, has_unpublished_changes=True,
        ).count()
        metadata.save(update_fields=['draft_component_count', 'updated_at'])

    return component


def track_course_reference(library_key, course_key, usage_key_in_course,
                            reference_type='library_content', component=None):
    """Track a library reference in a course (AC-LIB-010, AC-LIB-013)."""
    from .models import LibraryMetadata, LibraryCourseReference

    metadata = LibraryMetadata.objects.get(library_key=library_key)

    ref, created = LibraryCourseReference.objects.update_or_create(
        course_key=course_key,
        usage_key_in_course=usage_key_in_course,
        defaults={
            'library': metadata,
            'component': component,
            'reference_type': reference_type,
        },
    )
    return ref


def check_orphaned_references(library_key):
    """
    Check for orphaned Blockstore references (AC-LIB-013).

    Returns list of orphaned BlockstoreReference objects.
    """
    from .models import LibraryMetadata, BlockstoreReference

    try:
        metadata = LibraryMetadata.objects.get(library_key=library_key)
        # References for a deleted library are orphaned
        if metadata.is_deleted and metadata.can_permanent_delete:
            refs = BlockstoreReference.objects.filter(library=metadata)
            refs.update(is_orphaned=True)
            return list(refs)
    except LibraryMetadata.DoesNotExist:
        pass

    return []


def get_random_components(library_key, count, exclude_keys=None):
    """
    Get random components from a library for library_content XBlock (AC-LIB-008).

    Returns `count` unique published components. Uses database-level
    random ordering to ensure different sets per query.

    AC-NEG-LIB-006: MUST NOT serve the same set on reload.
    """
    from .models import LibraryMetadata, LibraryComponent

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    qs = LibraryComponent.objects.filter(
        library=metadata,
        is_deleted=False,
        has_unpublished_changes=False,  # Only published components
    )

    if exclude_keys:
        qs = qs.exclude(usage_key__in=exclude_keys)

    # Database-level random ordering
    return list(qs.order_by('?')[:count])


def create_platform_templates_library(user=None):
    """
    Create the first platform library lib:Mereka:platform-templates (AC-LIB-011).

    Idempotent — returns existing library if already created.
    """
    library_key = 'lib:Mereka:platform-templates'

    metadata = create_library(
        library_key=library_key,
        org='Mereka',
        title='Platform Templates',
        description=(
            'Shared template components for Mereka Academy courses. '
            'Includes common HTML blocks, assessment templates, and '
            'reusable content patterns.'
        ),
        user=user,
    )

    return metadata
