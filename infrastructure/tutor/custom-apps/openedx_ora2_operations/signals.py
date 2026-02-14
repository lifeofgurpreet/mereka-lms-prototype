"""Django signals for ORA2 operations observability"""
import logging
import time
from functools import wraps
from django.db.models.signals import post_save
from django.dispatch import receiver
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

from .metrics import (
    ora2_submissions_total,
    ora2_submission_duration_seconds,
    ora2_peer_assessments_total,
    ora2_peer_assessment_duration_seconds,
    ora2_staff_assessments_total,
    ora2_staff_grading_queue_size,
    ora2_file_upload_size_bytes,
    ora2_file_uploads_total,
    ora2_grade_propagation_total,
    ora2_grade_propagation_duration_seconds,
    ora2_fallback_to_staff_total,
)

logger = logging.getLogger(__name__)


def track_duration(metric):
    """Decorator to track operation duration"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            try:
                return func(*args, **kwargs)
            finally:
                duration = time.time() - start_time
                # Extract course_id from signal kwargs
                course_id = kwargs.get('course_id', 'unknown')
                metric.labels(course_id=str(course_id)).observe(duration)
        return wrapper
    return decorator


# ORA2 Submission Signals
def connect_ora2_signals():
    """Connect to ORA2 signals for metrics tracking"""
    try:
        from openassessment.assessment.api import peer as peer_api
        from openassessment.assessment.api import staff as staff_api
        from openassessment.workflow import api as workflow_api

        # Connect to submission created signal
        if hasattr(workflow_api, 'submission_created'):
            workflow_api.submission_created.connect(on_submission_created)
            logger.info('Connected to ORA2 submission_created signal')

        # Connect to peer assessment completed signal
        if hasattr(peer_api, 'assessment_complete'):
            peer_api.assessment_complete.connect(on_peer_assessment_completed)
            logger.info('Connected to ORA2 peer assessment_complete signal')

        # Connect to staff assessment completed signal
        if hasattr(staff_api, 'assessment_complete'):
            staff_api.assessment_complete.connect(on_staff_assessment_completed)
            logger.info('Connected to ORA2 staff assessment_complete signal')

    except ImportError as e:
        logger.warning(f'Could not import ORA2 modules for signal connection: {e}')
    except Exception as e:
        logger.error(f'Error connecting to ORA2 signals: {e}')


def on_submission_created(sender, submission, **kwargs):
    """Track ORA2 submission creation"""
    try:
        course_id = str(submission.get('student_item', {}).get('course_id', 'unknown'))

        # Determine submission type based on answer content
        answer = submission.get('answer', {})
        has_text = bool(answer.get('parts', [{}])[0].get('text', ''))
        has_files = bool(answer.get('file_keys', []) or answer.get('files_descriptions', []))

        if has_text and has_files:
            submission_type = 'both'
        elif has_files:
            submission_type = 'file'
        else:
            submission_type = 'text'

        ora2_submissions_total.labels(
            course_id=course_id,
            submission_type=submission_type
        ).inc()

        logger.info(f'ORA2 submission created: course={course_id}, type={submission_type}')

        # Track file uploads if present
        if has_files:
            file_keys = answer.get('file_keys', []) or answer.get('files_descriptions', [])
            for file_info in file_keys:
                if isinstance(file_info, dict):
                    file_size = file_info.get('size', 0)
                    file_name = file_info.get('name', '')
                    file_type = file_name.split('.')[-1].lower() if '.' in file_name else 'unknown'

                    ora2_file_upload_size_bytes.labels(
                        course_id=course_id,
                        file_type=file_type
                    ).observe(file_size)

                    ora2_file_uploads_total.labels(
                        course_id=course_id,
                        file_type=file_type,
                        status='success'
                    ).inc()

    except Exception as e:
        logger.error(f'Error tracking ORA2 submission: {e}', exc_info=True)


def on_peer_assessment_completed(sender, assessment, **kwargs):
    """Track peer assessment completion"""
    try:
        course_id = str(assessment.get('submission_uuid', {}).get('course_id', 'unknown'))

        ora2_peer_assessments_total.labels(course_id=course_id).inc()

        logger.info(f'ORA2 peer assessment completed: course={course_id}')

    except Exception as e:
        logger.error(f'Error tracking peer assessment: {e}', exc_info=True)


def on_staff_assessment_completed(sender, assessment, **kwargs):
    """Track staff assessment completion"""
    try:
        course_id = str(assessment.get('submission_uuid', {}).get('course_id', 'unknown'))
        assessment_source = kwargs.get('assessment_source', 'manual')

        ora2_staff_assessments_total.labels(
            course_id=course_id,
            assessment_source=assessment_source
        ).inc()

        logger.info(f'ORA2 staff assessment completed: course={course_id}, source={assessment_source}')

    except Exception as e:
        logger.error(f'Error tracking staff assessment: {e}', exc_info=True)


def track_grade_propagation(course_id, success=True):
    """Track grade propagation to gradebook"""
    try:
        status = 'success' if success else 'failed'
        ora2_grade_propagation_total.labels(
            course_id=str(course_id),
            status=status
        ).inc()

        logger.info(f'ORA2 grade propagation: course={course_id}, status={status}')

    except Exception as e:
        logger.error(f'Error tracking grade propagation: {e}', exc_info=True)


def track_fallback_to_staff(course_id, reason='timeout'):
    """Track fallback from peer to staff grading"""
    try:
        ora2_fallback_to_staff_total.labels(
            course_id=str(course_id),
            fallback_reason=reason
        ).inc()

        logger.info(f'ORA2 fallback to staff: course={course_id}, reason={reason}')

    except Exception as e:
        logger.error(f'Error tracking fallback: {e}', exc_info=True)


def update_staff_grading_queue_size(course_id, queue_size):
    """Update staff grading queue size gauge"""
    try:
        ora2_staff_grading_queue_size.labels(course_id=str(course_id)).set(queue_size)

        logger.debug(f'ORA2 staff grading queue: course={course_id}, size={queue_size}')

    except Exception as e:
        logger.error(f'Error updating staff grading queue size: {e}', exc_info=True)


def log_ora2_event(event_type, data):
    """Structured JSON logging for ORA2 events"""
    logger.info(
        'ORA2 Event',
        extra={
            'event_type': event_type,
            'data': data,
            'service': 'openedx_ora2_operations',
        }
    )
