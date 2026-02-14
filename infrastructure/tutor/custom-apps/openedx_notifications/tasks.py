"""
Celery tasks for notification maintenance.

@spec: email-notifications-pipeline_spec.md
"""

import logging
from celery import shared_task

from .models import Notification

logger = logging.getLogger(__name__)


@shared_task(name='openedx_notifications.purge_expired_notifications')
def purge_expired_notifications(retention_days=90):
    """
    Purge expired notifications older than retention_days.

    This task should be scheduled to run daily via Celery Beat.

    Args:
        retention_days: Days to retain expired notifications (default: 90)

    Returns:
        dict: Purge statistics
    """
    logger.info(f"Starting notification purge (retention: {retention_days} days)")

    try:
        deleted_count, deleted_breakdown = Notification.purge_expired(retention_days)

        logger.info(
            f"Purged {deleted_count} expired notifications "
            f"(breakdown: {deleted_breakdown})"
        )

        return {
            'success': True,
            'deleted_count': deleted_count,
            'deleted_breakdown': deleted_breakdown,
            'retention_days': retention_days,
        }

    except Exception as e:
        logger.exception(f"Failed to purge expired notifications: {e}")
        return {
            'success': False,
            'error': str(e),
        }
