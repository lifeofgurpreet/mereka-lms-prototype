"""Celery tasks for ORA2 operations"""
import logging
from datetime import timedelta
from django.utils import timezone
from celery import shared_task

from .metrics import update_storage_metrics
from .signals import track_fallback_to_staff, update_staff_grading_queue_size

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3)
def update_ora2_storage_metrics_task(self):
    """Periodic task to update ORA2 storage metrics"""
    try:
        update_storage_metrics()
        logger.info('ORA2 storage metrics updated successfully')
        return {'status': 'success'}
    except Exception as e:
        logger.error(f'Failed to update ORA2 storage metrics: {e}', exc_info=True)
        raise self.retry(exc=e, countdown=300)  # Retry after 5 minutes


@shared_task(bind=True, max_retries=3)
def check_peer_grading_timeouts_task(self):
    """Check for peer grading timeouts and trigger fallback to staff"""
    try:
        from openassessment.workflow.models import AssessmentWorkflow
        from django.conf import settings
        from .models import ORA2FallbackTracking

        timeout_days = getattr(settings, 'ORA2_PEER_GRADING_TIMEOUT_DAYS', 7)
        timeout_threshold = timezone.now() - timedelta(days=timeout_days)

        # Find workflows stuck in peer assessment
        stuck_workflows = AssessmentWorkflow.objects.filter(
            status='peer',  # In peer assessment step
            created__lt=timeout_threshold  # Older than timeout threshold
        ).exclude(
            submission_uuid__in=ORA2FallbackTracking.objects.values_list('submission_uuid', flat=True)
        )

        fallback_count = 0
        for workflow in stuck_workflows:
            try:
                # Get peer assessment requirements
                peer_workflow = workflow.get_assessment_module('peer-assessment')
                if not peer_workflow:
                    continue

                must_grade = peer_workflow.get('must_grade', 3)
                must_be_graded_by = peer_workflow.get('must_be_graded_by', 3)

                # Check if insufficient peer grading
                completed_assessments = workflow.num_peers_graded()
                if completed_assessments < must_be_graded_by:
                    # Trigger fallback
                    ORA2FallbackTracking.trigger_fallback(
                        submission_uuid=str(workflow.submission_uuid),
                        course_id=workflow.course_id,
                        student_id=workflow.student_id,
                        item_id=workflow.item_id,
                        reason='timeout',
                        peer_grading_started_at=workflow.created,
                        peer_grading_deadline=timeout_threshold,
                        peers_required=must_be_graded_by,
                        peers_completed=completed_assessments,
                    )

                    # Track metric
                    track_fallback_to_staff(
                        course_id=str(workflow.course_id),
                        reason='timeout'
                    )

                    fallback_count += 1
                    logger.info(
                        f'ORA2 peer grading timeout fallback: {workflow.submission_uuid} '
                        f'({completed_assessments}/{must_be_graded_by} peers)'
                    )

            except Exception as e:
                logger.error(
                    f'Error processing workflow {workflow.submission_uuid} for fallback: {e}',
                    exc_info=True
                )

        logger.info(f'ORA2 peer grading timeout check completed: {fallback_count} fallback(s) triggered')
        return {'status': 'success', 'fallbacks_triggered': fallback_count}

    except Exception as e:
        logger.error(f'Failed to check peer grading timeouts: {e}', exc_info=True)
        raise self.retry(exc=e, countdown=600)  # Retry after 10 minutes


@shared_task(bind=True, max_retries=3)
def update_staff_grading_queue_metrics_task(self):
    """Update staff grading queue size metrics per course"""
    try:
        from .models import ORA2FallbackTracking
        from django.db.models import Count

        # Get queue sizes by course
        queue_sizes = ORA2FallbackTracking.objects.filter(
            status__in=['pending', 'assigned']
        ).values('course_id').annotate(queue_size=Count('id'))

        for item in queue_sizes:
            course_id = str(item['course_id'])
            queue_size = item['queue_size']

            update_staff_grading_queue_size(course_id, queue_size)
            logger.debug(f'ORA2 staff grading queue updated: {course_id} = {queue_size}')

        logger.info('ORA2 staff grading queue metrics updated successfully')
        return {'status': 'success', 'courses_updated': len(queue_sizes)}

    except Exception as e:
        logger.error(f'Failed to update staff grading queue metrics: {e}', exc_info=True)
        raise self.retry(exc=e, countdown=300)  # Retry after 5 minutes


@shared_task(bind=True, max_retries=3)
def cleanup_old_operational_data_task(self):
    """Clean up old operational data (older than retention period)"""
    try:
        from .models import ORA2FallbackTracking, ORA2FileUpload, ORA2OperationalMetrics
        from django.conf import settings

        # Retention periods
        fallback_retention_days = getattr(settings, 'ORA2_FALLBACK_RETENTION_DAYS', 90)
        metrics_retention_days = getattr(settings, 'ORA2_METRICS_RETENTION_DAYS', 365)
        file_retention_days = getattr(settings, 'ORA2_FILE_RETENTION_DAYS', 180)

        cutoff_fallback = timezone.now() - timedelta(days=fallback_retention_days)
        cutoff_metrics = timezone.now() - timedelta(days=metrics_retention_days)
        cutoff_files = timezone.now() - timedelta(days=file_retention_days)

        # Clean up completed fallback tracking
        deleted_fallbacks = ORA2FallbackTracking.objects.filter(
            status='completed',
            staff_graded_at__lt=cutoff_fallback
        ).delete()

        # Clean up old metrics
        deleted_metrics = ORA2OperationalMetrics.objects.filter(
            date__lt=cutoff_metrics.date()
        ).delete()

        # Clean up deleted file records
        deleted_files = ORA2FileUpload.objects.filter(
            status='deleted',
            uploaded_at__lt=cutoff_files
        ).delete()

        logger.info(
            f'ORA2 operational data cleanup completed: '
            f'{deleted_fallbacks[0]} fallbacks, '
            f'{deleted_metrics[0]} metrics, '
            f'{deleted_files[0]} files'
        )

        return {
            'status': 'success',
            'deleted_fallbacks': deleted_fallbacks[0],
            'deleted_metrics': deleted_metrics[0],
            'deleted_files': deleted_files[0],
        }

    except Exception as e:
        logger.error(f'Failed to cleanup old operational data: {e}', exc_info=True)
        raise self.retry(exc=e, countdown=600)  # Retry after 10 minutes


@shared_task(bind=True, max_retries=3)
def generate_daily_operational_metrics_task(self):
    """Generate daily operational metrics snapshot"""
    try:
        from .models import ORA2OperationalMetrics, ORA2FallbackTracking, ORA2FileUpload
        from openassessment.workflow.models import AssessmentWorkflow
        from django.db.models import Count, Sum, Avg
        from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

        today = timezone.now().date()

        # Get all courses with ORA2 activity
        courses = CourseOverview.objects.filter(
            id__in=AssessmentWorkflow.objects.values_list('course_id', flat=True).distinct()
        )

        for course in courses:
            course_id = course.id

            # Submission metrics (today)
            submissions_today = AssessmentWorkflow.objects.filter(
                course_id=course_id,
                created__date=today
            ).count()

            submissions_with_files = ORA2FileUpload.objects.filter(
                course_id=course_id,
                uploaded_at__date=today
            ).values('submission_uuid').distinct().count()

            file_stats = ORA2FileUpload.objects.filter(
                course_id=course_id,
                uploaded_at__date=today
            ).aggregate(
                total_files=Count('id'),
                total_size=Sum('file_size_bytes')
            )

            # Fallback metrics (today)
            fallback_stats = ORA2FallbackTracking.objects.filter(
                course_id=course_id,
                fallback_triggered_at__date=today
            ).aggregate(
                total_fallbacks=Count('id'),
                timeout_fallbacks=Count('id', filter=models.Q(fallback_reason='timeout')),
                insufficient_peer_fallbacks=Count('id', filter=models.Q(fallback_reason='insufficient_peers'))
            )

            # Current queue size
            queue_size = ORA2FallbackTracking.objects.filter(
                course_id=course_id,
                status__in=['pending', 'assigned']
            ).count()

            # Create/update metrics record
            metrics, created = ORA2OperationalMetrics.objects.update_or_create(
                course_id=course_id,
                date=today,
                defaults={
                    'total_submissions': submissions_today,
                    'submissions_with_files': submissions_with_files,
                    'total_file_uploads': file_stats.get('total_files', 0),
                    'total_file_size_bytes': file_stats.get('total_size', 0) or 0,
                    'total_fallbacks': fallback_stats.get('total_fallbacks', 0),
                    'fallback_due_to_timeout': fallback_stats.get('timeout_fallbacks', 0),
                    'fallback_due_to_insufficient_peers': fallback_stats.get('insufficient_peer_fallbacks', 0),
                    'staff_grading_queue_size': queue_size,
                }
            )

            logger.debug(f'ORA2 daily metrics {"created" if created else "updated"} for {course_id}')

        logger.info(f'ORA2 daily operational metrics generated for {courses.count()} courses')
        return {'status': 'success', 'courses_processed': courses.count()}

    except Exception as e:
        logger.error(f'Failed to generate daily operational metrics: {e}', exc_info=True)
        raise self.retry(exc=e, countdown=600)  # Retry after 10 minutes
