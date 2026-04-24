"""
xAPI event emission for video playback events.

Emits played, paused, seeked, and completed verbs to the
eventtracking pipeline for ClickHouse/Aspects ingestion.

@spec: video-pipeline-delivery_spec.md (Phase 2)
@covers: AC-VPD-014
"""
import logging
import time

from django.conf import settings

logger = logging.getLogger(__name__)

# xAPI verb IRIs for video events
VERB_VIDEO_PLAYED = 'https://w3id.org/xapi/video/verbs/played'
VERB_VIDEO_PAUSED = 'https://w3id.org/xapi/video/verbs/paused'
VERB_VIDEO_SEEKED = 'https://w3id.org/xapi/video/verbs/seeked'
VERB_VIDEO_COMPLETED = 'http://adlnet.gov/expapi/verbs/completed'

VERB_MAP = {
    'played': VERB_VIDEO_PLAYED,
    'paused': VERB_VIDEO_PAUSED,
    'seeked': VERB_VIDEO_SEEKED,
    'completed': VERB_VIDEO_COMPLETED,
}


def emit_video_xapi_event(user_id, video_id, course_key, event_type,
                          position=0.0, duration=None, session_id=None):
    """
    Emit an xAPI video event to the eventtracking pipeline.

    Events flow to ClickHouse via the Aspects analytics pipeline.
    No PII (email, IP) is included — only user_id (AC-NEG: no PII in video analytics).

    Args:
        user_id (int): User ID (no PII — AC-NEG)
        video_id (str): Mux playback ID (never asset ID)
        course_key (str): Course key string
        event_type (str): One of 'played', 'paused', 'seeked', 'completed'
        position (float): Playback position in seconds
        duration (float, optional): Video total duration
        session_id (str, optional): Session identifier

    Returns:
        bool: True if event was emitted successfully
    """
    if not getattr(settings, 'ENABLE_VIDEO_XAPI_EVENTS', False):
        return False

    verb = VERB_MAP.get(event_type)
    if not verb:
        logger.warning(f'Unknown video event type: {event_type}')
        return False

    # Build xAPI statement — no PII (email, IP, name) included
    statement = {
        'verb': {
            'id': verb,
            'display': {'en-US': event_type},
        },
        'actor': {
            'account': {
                'name': str(user_id),  # user ID only, no PII
            },
        },
        'object': {
            'id': f'video:{video_id}',
            'definition': {
                'type': 'https://w3id.org/xapi/video/activity-type/video',
                'name': {'en-US': video_id},
            },
        },
        'context': {
            'extensions': {
                'course_key': course_key,
            },
        },
        'result': {
            'extensions': {
                'https://w3id.org/xapi/video/extensions/time': position,
            },
        },
        'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }

    if duration:
        statement['result']['extensions']['https://w3id.org/xapi/video/extensions/length'] = duration

    if session_id:
        statement['context']['extensions']['session_id'] = session_id

    # Completion-specific result
    if event_type == 'completed':
        statement['result']['completion'] = True
        if duration and duration > 0:
            statement['result']['extensions']['https://w3id.org/xapi/video/extensions/progress'] = (
                min(position / duration, 1.0)
            )

    # Emit via eventtracking
    try:
        import eventtracking
        tracker = eventtracking.tracker.get_tracker()
        tracker.emit(
            f'video.{event_type}',
            statement,
        )
        logger.debug(f'xAPI video event emitted: {event_type}, video={video_id}, user={user_id}')
        return True
    except ImportError:
        logger.warning('eventtracking not available — xAPI event not emitted')
        return False
    except Exception as e:
        logger.error(f'Failed to emit xAPI video event: {e}')
        return False
