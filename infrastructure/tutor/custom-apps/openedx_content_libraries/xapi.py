"""
xAPI event tracking for library content views.

@covers: AC-LIB-027 (library_content_viewed xAPI events),
         AC-NEG-LIB-013 (no PII beyond user ID)
"""
import logging
import uuid

from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

# xAPI verb for library content viewed
VERB_LIBRARY_CONTENT_VIEWED = 'https://w3id.org/xapi/acrossx/verbs/viewed'
VERB_LIBRARY_SEARCHED = 'https://w3id.org/xapi/acrossx/verbs/searched'
VERB_LIBRARY_PUBLISHED = 'https://w3id.org/xapi/acrossx/verbs/published'

# Activity types
ACTIVITY_LIBRARY = 'https://w3id.org/xapi/acrossx/activities/library'
ACTIVITY_LIBRARY_COMPONENT = 'https://w3id.org/xapi/acrossx/activities/library-component'


def emit_library_content_viewed(user_id, library_key, component_usage_key=None,
                                  course_key=None, tenant_uuid=None):
    """
    Emit library_content_viewed xAPI event (AC-LIB-027).

    AC-NEG-LIB-013: No PII beyond user ID — no email, name, or IP in payload.
    """
    if not getattr(settings, 'LIBRARY_XAPI_ENABLED', False):
        return None

    event = {
        'event_id': str(uuid.uuid4()),
        'verb_id': VERB_LIBRARY_CONTENT_VIEWED,
        'verb_display': 'viewed',
        'actor_id': str(user_id),  # AC-NEG-LIB-013: user ID only, no PII
        'object_type': ACTIVITY_LIBRARY_COMPONENT if component_usage_key else ACTIVITY_LIBRARY,
        'object_id': component_usage_key or library_key,
        'context': {
            'library_key': library_key,
            'tenant_uuid': str(tenant_uuid) if tenant_uuid else None,
        },
        'timestamp': timezone.now().isoformat(),
    }

    if course_key:
        event['context']['course_key'] = course_key

    _send_xapi_event(event)

    logger.info(
        "xAPI: library_content_viewed user=%s library=%s component=%s",
        user_id, library_key, component_usage_key,
    )
    return event


def emit_library_searched(user_id, query, results_count, processing_time_ms,
                           tenant_uuid=None):
    """Emit library search xAPI event."""
    if not getattr(settings, 'LIBRARY_XAPI_ENABLED', False):
        return None

    event = {
        'event_id': str(uuid.uuid4()),
        'verb_id': VERB_LIBRARY_SEARCHED,
        'verb_display': 'searched',
        'actor_id': str(user_id),
        'object_type': ACTIVITY_LIBRARY,
        'object_id': f'search:{query[:100]}',
        'result': {
            'results_count': results_count,
            'processing_time_ms': processing_time_ms,
        },
        'context': {
            'tenant_uuid': str(tenant_uuid) if tenant_uuid else None,
        },
        'timestamp': timezone.now().isoformat(),
    }

    _send_xapi_event(event)
    return event


def emit_library_published(user_id, library_key, version_number,
                            component_count, duration_ms, tenant_uuid=None):
    """Emit library publish xAPI event."""
    if not getattr(settings, 'LIBRARY_XAPI_ENABLED', False):
        return None

    event = {
        'event_id': str(uuid.uuid4()),
        'verb_id': VERB_LIBRARY_PUBLISHED,
        'verb_display': 'published',
        'actor_id': str(user_id),
        'object_type': ACTIVITY_LIBRARY,
        'object_id': library_key,
        'result': {
            'version_number': version_number,
            'component_count': component_count,
            'duration_ms': duration_ms,
        },
        'context': {
            'tenant_uuid': str(tenant_uuid) if tenant_uuid else None,
        },
        'timestamp': timezone.now().isoformat(),
    }

    _send_xapi_event(event)
    return event


def _send_xapi_event(event):
    """
    Send xAPI event to ClickHouse via the platform event bus.

    Uses the Open edX event tracking pipeline if available,
    otherwise logs the event for batch processing.
    """
    try:
        from eventtracking import tracker
        tracker.emit(
            'library_content_viewed',
            event,
        )
    except ImportError:
        logger.debug("eventtracking not available, event logged only: %s", event.get('event_id'))
