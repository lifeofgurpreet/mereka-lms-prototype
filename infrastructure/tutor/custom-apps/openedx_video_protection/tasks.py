"""Celery tasks for Video Content Protection"""
import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(bind=True)
def cleanup_expired_tokens_task(self, days_to_keep=7):
    """
    Cleanup expired signed playback tokens.

    Runs daily to remove expired tokens older than specified days.
    Keeps tokens for audit trail after expiry.

    Args:
        days_to_keep: Keep expired tokens for this many days (default: 7)

    Returns:
        dict with cleanup stats
    """
    from .models import SignedPlaybackToken

    try:
        deleted_count = SignedPlaybackToken.cleanup_expired_tokens(days_to_keep)

        logger.info(f'Cleaned up {deleted_count} expired tokens (older than {days_to_keep} days)')

        return {
            'task': 'cleanup_expired_tokens',
            'deleted_count': deleted_count,
            'days_to_keep': days_to_keep,
        }
    except Exception as e:
        logger.exception(f'Failed to cleanup expired tokens: {e}')
        raise


@shared_task(bind=True)
def cleanup_old_access_logs_task(self, days_to_keep=90):
    """
    Cleanup old video access logs.

    Runs weekly to remove access logs older than specified days.

    Args:
        days_to_keep: Keep logs for this many days (default: 90)

    Returns:
        dict with cleanup stats
    """
    from django.utils import timezone
    from datetime import timedelta

    from .models import VideoAccessLog

    try:
        cutoff = timezone.now() - timedelta(days=days_to_keep)
        deleted_count, _ = VideoAccessLog.objects.filter(timestamp__lt=cutoff).delete()

        logger.info(f'Cleaned up {deleted_count} access logs (older than {days_to_keep} days)')

        return {
            'task': 'cleanup_old_access_logs',
            'deleted_count': deleted_count,
            'days_to_keep': days_to_keep,
        }
    except Exception as e:
        logger.exception(f'Failed to cleanup access logs: {e}')
        raise


@shared_task(bind=True, max_retries=3)
def generate_access_report_task(self, start_date=None, end_date=None):
    """
    Generate video access report for specified date range.

    Args:
        start_date: Start date (YYYY-MM-DD) or None for last 30 days
        end_date: End date (YYYY-MM-DD) or None for today

    Returns:
        dict with access stats
    """
    from datetime import datetime, timedelta

    from django.utils import timezone

    from .models import VideoAccessLog

    try:
        # Parse dates
        if start_date:
            start = datetime.strptime(start_date, '%Y-%m-%d').date()
        else:
            start = (timezone.now() - timedelta(days=30)).date()

        if end_date:
            end = datetime.strptime(end_date, '%Y-%m-%d').date()
        else:
            end = timezone.now().date()

        # Query access logs
        logs = VideoAccessLog.objects.filter(
            timestamp__date__gte=start, timestamp__date__lte=end
        )

        total_attempts = logs.count()
        granted = logs.filter(status=VideoAccessLog.ACCESS_GRANTED).count()
        denied = logs.filter(status=VideoAccessLog.ACCESS_DENIED).count()

        # Breakdown by denial reason
        denial_reasons = (
            logs.filter(status=VideoAccessLog.ACCESS_DENIED)
            .values('denial_reason')
            .annotate(count=Count('id'))
            .order_by('-count')
        )

        report = {
            'task': 'generate_access_report',
            'start_date': str(start),
            'end_date': str(end),
            'total_attempts': total_attempts,
            'granted': granted,
            'denied': denied,
            'grant_rate': (granted / total_attempts * 100) if total_attempts > 0 else 0,
            'denial_reasons': list(denial_reasons),
        }

        logger.info(
            f'Generated access report for {start} to {end}: '
            f'{total_attempts} attempts, {granted} granted, {denied} denied'
        )

        return report
    except Exception as e:
        logger.exception(f'Failed to generate access report: {e}')
        raise


# Import Count for aggregation
try:
    from django.db.models import Count
except ImportError:
    pass
