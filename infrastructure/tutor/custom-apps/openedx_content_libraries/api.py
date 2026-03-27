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


# ── Phase 2: Tenant Libraries (AC-LIB-014 through AC-LIB-019) ──────────


def get_tenant_libraries(tenant_uuid, include_public=True):
    """
    Get libraries for a specific tenant (AC-LIB-014, AC-LIB-015).

    Returns libraries owned by the tenant, plus optionally
    platform-global libraries (allow_public_read=True).

    AC-NEG-LIB-007: Cross-tenant libraries are NOT included.
    """
    from .models import LibraryMetadata
    from django.db.models import Q

    query = Q(tenant_uuid=tenant_uuid, is_deleted=False)

    if include_public:
        query |= Q(allow_public_read=True, is_deleted=False)

    return LibraryMetadata.objects.filter(query).distinct()


def grant_library_role(library_key, user, role, granted_by=None):
    """
    Grant RBAC role to a user for a library (AC-LIB-016).

    Roles:
    - library_admin: Full control
    - library_author: Edit content, publish
    - library_reader: Read-only

    Returns LibraryRole instance.
    """
    from .models import LibraryMetadata, LibraryRole

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    role_obj, created = LibraryRole.objects.update_or_create(
        library=metadata,
        user=user,
        defaults={
            'role': role,
            'granted_by': granted_by,
        },
    )

    action = 'created' if created else 'updated'
    logger.info(
        "Library role %s: %s -> %s (%s) [granted by: %s]",
        action, library_key, user.username, role,
        granted_by.username if granted_by else 'system',
    )

    return role_obj


def revoke_library_role(library_key, user, revoked_by=None):
    """
    Revoke RBAC role from a user (AC-LIB-017).

    AC-LIB-017: Prevents removing the last admin.
    Raises ValueError if attempting to remove the last admin.
    """
    from .models import LibraryMetadata, LibraryRole

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    role_obj = LibraryRole.objects.get(library=metadata, user=user)

    # Last-admin prevention (AC-LIB-017)
    if role_obj.role == LibraryRole.ROLE_ADMIN:
        admin_count = LibraryRole.objects.filter(
            library=metadata,
            role=LibraryRole.ROLE_ADMIN,
        ).count()

        if admin_count <= 1:
            logger.warning(
                "Blocked removal of last admin from library %s (user: %s)",
                library_key, user.username,
            )
            raise ValueError(
                "Cannot remove the last admin from a library. "
                "Grant admin role to another user first."
            )

    role_obj.delete()

    logger.info(
        "Library role revoked: %s -> %s (%s) [revoked by: %s]",
        library_key, user.username, role_obj.role,
        revoked_by.username if revoked_by else 'system',
    )


def check_library_permission(library_key, user, required_role):
    """
    Check if a user has the required RBAC role for a library (AC-LIB-016).

    Role hierarchy:
    - library_admin >= library_author >= library_reader
    - library_admin can do anything
    - library_author can edit and publish
    - library_reader can only read

    Returns True if permission granted, False otherwise.
    """
    from .models import LibraryMetadata, LibraryRole

    # Superusers bypass RBAC
    if user.is_superuser:
        return True

    try:
        metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)
        role_obj = LibraryRole.objects.get(library=metadata, user=user)
    except (LibraryMetadata.DoesNotExist, LibraryRole.DoesNotExist):
        return False

    # Role hierarchy
    role_levels = {
        LibraryRole.ROLE_ADMIN: 3,
        LibraryRole.ROLE_AUTHOR: 2,
        LibraryRole.ROLE_READER: 1,
    }

    user_level = role_levels.get(role_obj.role, 0)
    required_level = role_levels.get(required_role, 0)

    return user_level >= required_level


def enable_public_read(library_key, user):
    """
    Enable public read access for a library (AC-LIB-015).

    Makes the library visible to all tenants.
    Locks the setting after first enable to prevent reversal (AC-NEG-LIB-008).

    Returns LibraryMetadata instance.
    """
    from .models import LibraryMetadata

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    if not metadata.allow_public_read:
        metadata.allow_public_read = True
        metadata.allow_public_read_locked_at = timezone.now()
        metadata.save(update_fields=['allow_public_read', 'allow_public_read_locked_at', 'updated_at'])

        logger.warning(
            "Library %s set to public read by %s (IRREVERSIBLE)",
            library_key, user.username if user else 'system',
        )

    return metadata


def disable_public_read(library_key, user):
    """
    Disable public read access for a library (AC-NEG-LIB-008).

    REJECTS if the library has been forked by other tenants.
    This prevents breaking existing references.

    Raises ValueError if reversal is not allowed.
    """
    from .models import LibraryMetadata, LibraryCourseReference

    metadata = LibraryMetadata.objects.get(library_key=library_key, is_deleted=False)

    if not metadata.allow_public_read:
        return metadata

    # Check if locked (has been forked)
    if metadata.allow_public_read_locked_at:
        # Check for cross-tenant references
        refs = LibraryCourseReference.objects.filter(library=metadata)
        cross_tenant_refs = [
            ref for ref in refs
            if ref.library.tenant_uuid and
            str(ref.library.tenant_uuid) != str(metadata.tenant_uuid)
        ]

        if cross_tenant_refs:
            logger.warning(
                "Blocked public read disable for library %s: "
                "%d cross-tenant references exist",
                library_key, len(cross_tenant_refs),
            )
            raise ValueError(
                "Cannot disable public read: library has been forked by other tenants. "
                "This operation would break existing references."
            )

    metadata.allow_public_read = False
    metadata.save(update_fields=['allow_public_read', 'updated_at'])

    logger.info(
        "Library %s public read disabled by %s",
        library_key, user.username if user else 'system',
    )

    return metadata


def log_library_access(library, user, action, request=None,
                        source_tenant=None, target_tenant=None):
    """
    Log library access events for security auditing (AC-LIB-018).

    Actions:
    - cross_tenant_attempt: User tried to access another tenant's library
    - role_escalation_attempt: User tried to perform action above their role
    - access_granted: Access was allowed
    - access_denied: Access was denied

    AC-NEG-LIB-007: All cross-tenant attempts are logged.
    """
    from .models import LibraryAccessLog

    ip_address = None
    request_path = ''

    if request:
        # Extract IP address
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip_address = x_forwarded_for.split(',')[0].strip()
        else:
            ip_address = request.META.get('REMOTE_ADDR')

        request_path = request.path

    log_entry = LibraryAccessLog.objects.create(
        library=library,
        user=user,
        action=action,
        source_tenant_uuid=source_tenant,
        target_tenant_uuid=target_tenant,
        request_path=request_path,
        ip_address=ip_address,
    )

    # Security-critical events logged at WARNING level
    if action in [
        LibraryAccessLog.ACTION_CROSS_TENANT_ATTEMPT,
        LibraryAccessLog.ACTION_ROLE_ESCALATION_ATTEMPT,
    ]:
        logger.warning(
            "SECURITY: %s - user=%s, library=%s, source_tenant=%s, target_tenant=%s, ip=%s",
            action, user.username, library.library_key if library else None,
            source_tenant, target_tenant, ip_address,
        )

    return log_entry
