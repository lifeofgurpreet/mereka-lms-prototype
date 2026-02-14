"""
Library usage analytics tracking.

@covers: AC-LIB-022 (usage reports showing all course references)
"""
import logging
from collections import defaultdict

from django.db.models import Count, Q
from django.utils import timezone

logger = logging.getLogger(__name__)


def get_library_usage_report(library_key):
    """
    Generate usage report for a library (AC-LIB-022).

    Returns all courses using this library with reference details.
    Must show ALL references (e.g., 15 courses = 15 entries).
    """
    from .models import LibraryMetadata, LibraryCourseReference

    metadata = LibraryMetadata.objects.get(library_key=library_key)

    refs = LibraryCourseReference.objects.filter(
        library=metadata,
    ).select_related('component')

    courses = defaultdict(list)
    for ref in refs:
        courses[ref.course_key].append({
            'usage_key_in_course': ref.usage_key_in_course,
            'reference_type': ref.reference_type,
            'synced_version': ref.synced_version,
            'has_update_available': ref.has_update_available,
            'component_usage_key': ref.component.usage_key if ref.component else None,
        })

    return {
        'library_key': library_key,
        'title': metadata.title,
        'org': metadata.org,
        'total_courses': len(courses),
        'total_references': refs.count(),
        'courses': dict(courses),
        'generated_at': timezone.now().isoformat(),
    }


def get_library_analytics_summary():
    """
    Get analytics summary across all libraries.

    Provides aggregate stats for dashboard/monitoring.
    """
    from .models import LibraryMetadata, LibraryComponent, LibraryCourseReference, LibraryVersion

    total_libraries = LibraryMetadata.objects.filter(is_deleted=False).count()
    total_components = LibraryComponent.objects.filter(is_deleted=False).count()
    total_references = LibraryCourseReference.objects.count()
    total_versions = LibraryVersion.objects.filter(publish_status='completed').count()

    # Libraries with most references
    top_libraries = LibraryMetadata.objects.filter(
        is_deleted=False,
    ).annotate(
        ref_count=Count('course_references'),
    ).order_by('-ref_count')[:10]

    # Components by block type
    by_block_type = LibraryComponent.objects.filter(
        is_deleted=False,
    ).values('block_type').annotate(
        count=Count('id'),
    ).order_by('-count')

    # Libraries needing attention (stale drafts)
    stale_drafts = LibraryMetadata.objects.filter(
        is_deleted=False,
        draft_component_count__gt=0,
    ).count()

    return {
        'total_libraries': total_libraries,
        'total_components': total_components,
        'total_references': total_references,
        'total_versions': total_versions,
        'stale_draft_libraries': stale_drafts,
        'top_libraries': [
            {
                'library_key': lib.library_key,
                'title': lib.title,
                'ref_count': lib.ref_count,
            }
            for lib in top_libraries
        ],
        'components_by_type': list(by_block_type),
        'generated_at': timezone.now().isoformat(),
    }


def track_library_event(library_key, event_type, user=None, metadata=None):
    """
    Track library usage events for analytics.

    Event types: view, search_hit, component_access, publish, import
    """
    logger.info(
        "Library event: library=%s, event=%s, user=%s, meta=%s",
        library_key, event_type,
        user.username if user else 'anonymous',
        metadata or {},
    )
