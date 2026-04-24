"""Prometheus metrics for ORA2 operations"""
import logging
import os
from prometheus_client import Counter, Histogram, Gauge

logger = logging.getLogger(__name__)

# ORA2 Submission Metrics
ora2_submissions_total = Counter(
    'ora2_submissions_total',
    'Total number of ORA2 submissions',
    ['course_id', 'submission_type']  # submission_type: file, text, both
)

ora2_submission_duration_seconds = Histogram(
    'ora2_submission_duration_seconds',
    'Time taken to process ORA2 submission',
    ['course_id'],
    buckets=(0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0)
)

# Peer Assessment Metrics
ora2_peer_assessments_total = Counter(
    'ora2_peer_assessments_total',
    'Total number of peer assessments completed',
    ['course_id']
)

ora2_peer_assessment_duration_seconds = Histogram(
    'ora2_peer_assessment_duration_seconds',
    'Time taken to complete peer assessment',
    ['course_id'],
    buckets=(10.0, 30.0, 60.0, 120.0, 300.0, 600.0, 1800.0)
)

# Staff Grading Metrics
ora2_staff_assessments_total = Counter(
    'ora2_staff_assessments_total',
    'Total number of staff assessments completed',
    ['course_id', 'assessment_source']  # assessment_source: manual, fallback
)

ora2_staff_grading_queue_size = Gauge(
    'ora2_staff_grading_queue_size',
    'Number of submissions waiting for staff grading',
    ['course_id']
)

# File Upload Metrics
ora2_file_upload_size_bytes = Histogram(
    'ora2_file_upload_size_bytes',
    'Size of uploaded files in bytes',
    ['course_id', 'file_type'],
    buckets=(1024, 10240, 102400, 1048576, 5242880, 10485760, 52428800)  # 1KB to 50MB
)

ora2_file_uploads_total = Counter(
    'ora2_file_uploads_total',
    'Total number of files uploaded to ORA2',
    ['course_id', 'file_type', 'status']  # status: success, rejected_size, rejected_type
)

# Storage Metrics
ora2_file_storage_used_bytes = Gauge(
    'ora2_file_storage_used_bytes',
    'Total bytes used by ORA2 file storage',
)

ora2_file_storage_total_bytes = Gauge(
    'ora2_file_storage_total_bytes',
    'Total bytes available for ORA2 file storage',
)

# Grade Propagation Metrics
ora2_grade_propagation_total = Counter(
    'ora2_grade_propagation_total',
    'Total number of grades propagated to gradebook',
    ['course_id', 'status']  # status: success, failed
)

ora2_grade_propagation_duration_seconds = Histogram(
    'ora2_grade_propagation_duration_seconds',
    'Time taken to propagate grade to gradebook',
    ['course_id'],
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0)
)

# Fallback Metrics
ora2_fallback_to_staff_total = Counter(
    'ora2_fallback_to_staff_total',
    'Total number of peer assessments that fell back to staff grading',
    ['course_id', 'fallback_reason']  # fallback_reason: timeout, insufficient_peers
)


def update_storage_metrics():
    """Update ORA2 storage metrics by checking filesystem usage"""
    try:
        from django.conf import settings
        ora2_root = getattr(settings, 'ORA2_FILEUPLOAD_ROOT', '/openedx/data/ora2')

        if not os.path.exists(ora2_root):
            logger.warning(f'ORA2 storage path does not exist: {ora2_root}')
            return

        # Get disk usage
        stat = os.statvfs(ora2_root)
        total_bytes = stat.f_blocks * stat.f_frsize
        used_bytes = (stat.f_blocks - stat.f_bavail) * stat.f_frsize

        ora2_file_storage_total_bytes.set(total_bytes)
        ora2_file_storage_used_bytes.set(used_bytes)

        logger.debug(f'ORA2 storage: {used_bytes / total_bytes * 100:.2f}% used')
    except Exception as e:
        logger.error(f'Failed to update ORA2 storage metrics: {e}')
