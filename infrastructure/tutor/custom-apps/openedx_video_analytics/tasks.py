"""
Video Analytics Celery Tasks

Background tasks for aggregating video analytics data.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

import logging
from datetime import datetime, timedelta
from django.utils import timezone
from celery import shared_task

from .models import VideoAnalyticsSummary, VideoPlaybackEvent

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3)
def aggregate_video_analytics_daily(self, date_str=None):
    """
    Aggregate video playback events for a specific date.

    This task runs daily via cron to roll up raw events into summary tables.

    Args:
        date_str (str, optional): Date to aggregate (YYYY-MM-DD).
            Defaults to yesterday.

    Returns:
        dict: Aggregation results {
            'date': str,
            'summaries_created': int,
            'events_processed': int,
        }

    Schedule:
        - Daily at 00:30 UTC (after midnight)
        - Aggregates previous day's data

    Usage:
        # Manually trigger for specific date
        aggregate_video_analytics_daily.delay('2026-02-14')

        # Trigger for yesterday (automatic)
        aggregate_video_analytics_daily.delay()
    """
    try:
        # Parse target date
        if date_str:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        else:
            # Default to yesterday
            target_date = (timezone.now() - timedelta(days=1)).date()

        logger.info(f"Starting video analytics aggregation for date: {target_date}")

        # Count events for this date before aggregation
        events_count = VideoPlaybackEvent.objects.filter(
            timestamp__date=target_date
        ).count()

        if events_count == 0:
            logger.info(f"No video events found for {target_date}, skipping aggregation")
            return {
                'date': str(target_date),
                'summaries_created': 0,
                'events_processed': 0,
            }

        # Aggregate events into summaries
        summaries_created = VideoAnalyticsSummary.aggregate_for_date(
            date=target_date
        )

        logger.info(
            f"Video analytics aggregation completed: date={target_date}, "
            f"summaries_created={summaries_created}, events_processed={events_count}"
        )

        return {
            'date': str(target_date),
            'summaries_created': summaries_created,
            'events_processed': events_count,
        }

    except Exception as exc:
        logger.error(f"Video analytics aggregation failed: {str(exc)}")
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))


@shared_task
def cleanup_old_video_events(days_to_keep=90):
    """
    Delete old video playback events to manage database size.

    Raw events are kept for a limited time (default: 90 days).
    Aggregated summaries are kept indefinitely.

    Args:
        days_to_keep (int): Number of days to retain raw events

    Returns:
        dict: Cleanup results {
            'events_deleted': int,
            'cutoff_date': str,
        }

    Schedule:
        - Weekly on Sunday at 02:00 UTC

    Usage:
        # Delete events older than 90 days
        cleanup_old_video_events.delay(90)

        # Delete events older than 30 days
        cleanup_old_video_events.delay(30)
    """
    try:
        cutoff_date = timezone.now() - timedelta(days=days_to_keep)

        logger.info(
            f"Starting video events cleanup: deleting events before {cutoff_date.date()}"
        )

        # Delete old events
        deleted_count, _ = VideoPlaybackEvent.objects.filter(
            timestamp__lt=cutoff_date
        ).delete()

        logger.info(
            f"Video events cleanup completed: deleted {deleted_count} events "
            f"older than {days_to_keep} days"
        )

        return {
            'events_deleted': deleted_count,
            'cutoff_date': str(cutoff_date.date()),
        }

    except Exception as exc:
        logger.error(f"Video events cleanup failed: {str(exc)}")
        raise


@shared_task
def backfill_video_analytics(start_date_str, end_date_str):
    """
    Backfill video analytics summaries for a date range.

    Useful for:
    - Initial data migration
    - Fixing missing summaries
    - Re-aggregating after schema changes

    Args:
        start_date_str (str): Start date (YYYY-MM-DD)
        end_date_str (str): End date (YYYY-MM-DD)

    Returns:
        dict: Backfill results {
            'start_date': str,
            'end_date': str,
            'days_processed': int,
            'total_summaries': int,
        }

    Usage:
        # Backfill January 2026
        backfill_video_analytics.delay('2026-01-01', '2026-01-31')
    """
    try:
        start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
        end_date = datetime.strptime(end_date_str, '%Y-%m-%d').date()

        logger.info(
            f"Starting video analytics backfill: {start_date} to {end_date}"
        )

        current_date = start_date
        total_summaries = 0
        days_processed = 0

        while current_date <= end_date:
            summaries_created = VideoAnalyticsSummary.aggregate_for_date(
                date=current_date
            )

            total_summaries += summaries_created
            days_processed += 1

            logger.info(
                f"Backfill progress: {current_date}, summaries_created={summaries_created}"
            )

            current_date += timedelta(days=1)

        logger.info(
            f"Video analytics backfill completed: days={days_processed}, "
            f"total_summaries={total_summaries}"
        )

        return {
            'start_date': start_date_str,
            'end_date': end_date_str,
            'days_processed': days_processed,
            'total_summaries': total_summaries,
        }

    except Exception as exc:
        logger.error(f"Video analytics backfill failed: {str(exc)}")
        raise
