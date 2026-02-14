"""Django signals for Timed Exams"""
import logging
from django.dispatch import receiver
from django.db.models.signals import post_save

logger = logging.getLogger(__name__)


def connect_exam_signals():
    """Connect to edx-proctoring signals for timed exam events"""
    try:
        from edx_proctoring.signals import exam_attempt_created, exam_attempt_submitted

        # Connect signal handlers
        exam_attempt_created.connect(on_exam_attempt_created)
        exam_attempt_submitted.connect(on_exam_attempt_submitted)

        logger.info('Connected to edx-proctoring timed exam signals')

    except ImportError:
        logger.warning('edx-proctoring not available; timed exam signals not connected')


def on_exam_attempt_created(sender, **kwargs):
    """Handle exam attempt creation"""
    try:
        attempt = kwargs.get('attempt')
        if not attempt:
            return

        logger.info(
            f'Timed exam attempt created: '
            f'user={attempt.user.username} exam={attempt.proctored_exam.exam_name}'
        )

        # Additional logic can be added here for session creation

    except Exception as e:
        logger.error(f'Error handling exam attempt created: {e}', exc_info=True)


def on_exam_attempt_submitted(sender, **kwargs):
    """Handle exam attempt submission"""
    try:
        attempt = kwargs.get('attempt')
        if not attempt:
            return

        logger.info(
            f'Timed exam attempt submitted: '
            f'user={attempt.user.username} exam={attempt.proctored_exam.exam_name}'
        )

        # Additional logic can be added here for session cleanup

    except Exception as e:
        logger.error(f'Error handling exam attempt submitted: {e}', exc_info=True)
