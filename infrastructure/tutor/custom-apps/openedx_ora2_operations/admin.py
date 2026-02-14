"""Django admin for ORA2 operations"""
from django.contrib import admin
from django.utils.html import format_html
from django.db.models import Count, Avg, Sum
from .models import ORA2FallbackTracking, ORA2OperationalMetrics, ORA2FileUpload


@admin.register(ORA2FallbackTracking)
class ORA2FallbackTrackingAdmin(admin.ModelAdmin):
    """Admin interface for ORA2 fallback tracking"""

    list_display = [
        'submission_uuid',
        'course_id',
        'student_id',
        'fallback_reason',
        'status_badge',
        'peers_progress',
        'fallback_triggered_at',
        'staff_graded_at',
    ]

    list_filter = [
        'status',
        'fallback_reason',
        'fallback_triggered_at',
        'course_id',
    ]

    search_fields = [
        'submission_uuid',
        'student_id',
        'item_id',
    ]

    readonly_fields = [
        'submission_uuid',
        'course_id',
        'student_id',
        'item_id',
        'fallback_triggered_at',
        'staff_assigned_at',
        'staff_graded_at',
        'peer_grading_started_at',
        'peer_grading_deadline',
    ]

    date_hierarchy = 'fallback_triggered_at'

    fieldsets = (
        ('Submission Details', {
            'fields': (
                'submission_uuid',
                'course_id',
                'student_id',
                'item_id',
            )
        }),
        ('Fallback Details', {
            'fields': (
                'fallback_reason',
                'status',
                'fallback_triggered_at',
                'staff_assigned_at',
                'staff_graded_at',
            )
        }),
        ('Peer Assessment Tracking', {
            'fields': (
                'peer_grading_started_at',
                'peer_grading_deadline',
                'peers_required',
                'peers_completed',
            )
        }),
    )

    def status_badge(self, obj):
        """Display status as colored badge"""
        colors = {
            'pending': 'orange',
            'assigned': 'blue',
            'completed': 'green',
            'cancelled': 'gray',
        }
        color = colors.get(obj.status, 'gray')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px;">{}</span>',
            color,
            obj.get_status_display()
        )
    status_badge.short_description = 'Status'

    def peers_progress(self, obj):
        """Display peer grading progress"""
        return f'{obj.peers_completed}/{obj.peers_required}'
    peers_progress.short_description = 'Peers'

    actions = ['mark_as_assigned', 'mark_as_completed']

    def mark_as_assigned(self, request, queryset):
        """Mark selected fallbacks as assigned to staff"""
        count = 0
        for fallback in queryset.filter(status='pending'):
            fallback.mark_staff_assigned()
            count += 1
        self.message_user(request, f'{count} fallback(s) marked as assigned to staff.')
    mark_as_assigned.short_description = 'Mark as assigned to staff'

    def mark_as_completed(self, request, queryset):
        """Mark selected fallbacks as completed"""
        count = 0
        for fallback in queryset.filter(status__in=['pending', 'assigned']):
            fallback.mark_staff_completed()
            count += 1
        self.message_user(request, f'{count} fallback(s) marked as completed.')
    mark_as_completed.short_description = 'Mark as completed'


@admin.register(ORA2OperationalMetrics)
class ORA2OperationalMetricsAdmin(admin.ModelAdmin):
    """Admin interface for ORA2 operational metrics"""

    list_display = [
        'course_id',
        'date',
        'total_submissions',
        'total_peer_assessments',
        'total_staff_assessments',
        'staff_grading_queue_size',
        'total_fallbacks',
        'storage_usage_display',
    ]

    list_filter = [
        'date',
        'course_id',
    ]

    search_fields = [
        'course_id',
    ]

    readonly_fields = [
        'course_id',
        'date',
        'created_at',
        'updated_at',
        'storage_usage_display',
    ]

    date_hierarchy = 'date'

    fieldsets = (
        ('Course & Date', {
            'fields': (
                'course_id',
                'date',
            )
        }),
        ('Submission Metrics', {
            'fields': (
                'total_submissions',
                'submissions_with_files',
                'total_file_uploads',
                'total_file_size_bytes',
            )
        }),
        ('Assessment Metrics', {
            'fields': (
                'total_peer_assessments',
                'avg_peer_assessment_time_seconds',
                'total_staff_assessments',
                'avg_staff_assessment_time_seconds',
                'staff_grading_queue_size',
            )
        }),
        ('Grade Propagation', {
            'fields': (
                'total_grades_propagated',
                'failed_grade_propagations',
            )
        }),
        ('Fallback Metrics', {
            'fields': (
                'total_fallbacks',
                'fallback_due_to_timeout',
                'fallback_due_to_insufficient_peers',
            )
        }),
        ('Storage Metrics', {
            'fields': (
                'storage_used_bytes',
                'storage_total_bytes',
                'storage_usage_display',
            )
        }),
        ('Timestamps', {
            'fields': (
                'created_at',
                'updated_at',
            )
        }),
    )

    def storage_usage_display(self, obj):
        """Display storage usage as percentage"""
        percent = obj.storage_usage_percent
        color = 'green' if percent < 70 else 'orange' if percent < 90 else 'red'
        return format_html(
            '<span style="color: {}; font-weight: bold;">{:.2f}%</span>',
            color,
            percent
        )
    storage_usage_display.short_description = 'Storage Usage'


@admin.register(ORA2FileUpload)
class ORA2FileUploadAdmin(admin.ModelAdmin):
    """Admin interface for ORA2 file uploads"""

    list_display = [
        'file_name',
        'file_type',
        'file_size_display',
        'course_id',
        'student_id',
        'status',
        'uploaded_at',
    ]

    list_filter = [
        'status',
        'file_type',
        'uploaded_at',
        'course_id',
    ]

    search_fields = [
        'file_name',
        'file_key',
        'submission_uuid',
        'student_id',
    ]

    readonly_fields = [
        'submission_uuid',
        'course_id',
        'student_id',
        'file_key',
        'file_name',
        'file_type',
        'file_size_bytes',
        'uploaded_at',
        'file_path',
    ]

    date_hierarchy = 'uploaded_at'

    fieldsets = (
        ('Submission Details', {
            'fields': (
                'submission_uuid',
                'course_id',
                'student_id',
            )
        }),
        ('File Details', {
            'fields': (
                'file_key',
                'file_name',
                'file_type',
                'file_size_bytes',
                'file_path',
                'uploaded_at',
            )
        }),
        ('Status', {
            'fields': (
                'status',
            )
        }),
    )

    actions = ['mark_as_archived', 'mark_as_deleted']

    def file_size_display(self, obj):
        """Display file size in human-readable format"""
        size = obj.file_size_bytes
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f'{size:.2f} {unit}'
            size /= 1024
        return f'{size:.2f} TB'
    file_size_display.short_description = 'File Size'

    def mark_as_archived(self, request, queryset):
        """Mark selected uploads as archived"""
        count = queryset.filter(status='active').update(status='archived')
        self.message_user(request, f'{count} upload(s) marked as archived.')
    mark_as_archived.short_description = 'Mark as archived'

    def mark_as_deleted(self, request, queryset):
        """Mark selected uploads as deleted"""
        count = queryset.filter(status__in=['active', 'archived']).update(status='deleted')
        self.message_user(request, f'{count} upload(s) marked as deleted.')
    mark_as_deleted.short_description = 'Mark as deleted'
