"""Django admin for XQueue Graders"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from .models import GraderSubmission, GraderQueueMetrics


@admin.register(GraderSubmission)
class GraderSubmissionAdmin(admin.ModelAdmin):
    """Admin interface for grader submissions"""

    list_display = [
        'submission_id',
        'status_badge',
        'score_display',
        'execution_time_display',
        'submitted_at',
        'worker_hostname',
        'violations_display',
    ]

    list_filter = [
        'status',
        'correct',
        'submitted_at',
        'worker_hostname',
    ]

    search_fields = [
        'submission_id',
        'student_response',
        'feedback',
        'worker_hostname',
    ]

    readonly_fields = [
        'submission_id',
        'submission_hash',
        'xqueue_header',
        'xqueue_body',
        'student_response',
        'grader_payload',
        'submitted_at',
        'started_processing_at',
        'completed_at',
        'processing_time_ms',
        'execution_time_ms',
        'worker_hostname',
        'worker_version',
        'stdout',
        'stderr',
        'exit_code',
        'sandbox_violations',
    ]

    date_hierarchy = 'submitted_at'

    fieldsets = (
        ('Submission Details', {
            'fields': (
                'submission_id',
                'submission_hash',
                'status',
                'submitted_at',
            )
        }),
        ('Student Code', {
            'fields': (
                'student_response',
                'grader_payload',
            ),
            'classes': ('collapse',)
        }),
        ('Grading Results', {
            'fields': (
                'correct',
                'score',
                'feedback',
            )
        }),
        ('Execution Details', {
            'fields': (
                'stdout',
                'stderr',
                'exit_code',
                'execution_time_ms',
            ),
            'classes': ('collapse',)
        }),
        ('Timing', {
            'fields': (
                'started_processing_at',
                'completed_at',
                'processing_time_ms',
            )
        }),
        ('Worker Information', {
            'fields': (
                'worker_hostname',
                'worker_version',
            )
        }),
        ('Security', {
            'fields': (
                'sandbox_violations',
            )
        }),
        ('XQueue Data', {
            'fields': (
                'xqueue_header',
                'xqueue_body',
            ),
            'classes': ('collapse',)
        }),
    )

    def status_badge(self, obj):
        """Display status as colored badge"""
        colors = {
            'pending': 'orange',
            'processing': 'blue',
            'success': 'green',
            'failure': 'red',
            'timeout': 'darkred',
            'sandbox_error': 'purple',
        }
        color = colors.get(obj.status, 'gray')

        icons = {
            'pending': '⏳',
            'processing': '⚙️',
            'success': '✓',
            'failure': '✗',
            'timeout': '⏰',
            'sandbox_error': '🔒',
        }
        icon = icons.get(obj.status, '?')

        return format_html(
            '{} <span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px; font-weight: bold;">{}</span>',
            icon,
            color,
            obj.get_status_display()
        )
    status_badge.short_description = 'Status'

    def score_display(self, obj):
        """Display score with color coding"""
        if obj.score is None:
            return '—'

        score = float(obj.score)
        if score >= 80:
            color = 'green'
        elif score >= 50:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {}; font-weight: bold;">{:.2f}%</span>',
            color,
            score
        )
    score_display.short_description = 'Score'

    def execution_time_display(self, obj):
        """Display execution time"""
        if obj.execution_time_ms is None:
            return '—'

        time_ms = obj.execution_time_ms

        if time_ms < 100:
            color = 'green'
        elif time_ms < 1000:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {};">{} ms</span>',
            color,
            time_ms
        )
    execution_time_display.short_description = 'Execution Time'

    def violations_display(self, obj):
        """Display sandbox violations"""
        if not obj.sandbox_violations:
            return format_html('<span style="color: green;">✓ None</span>')

        violations_str = ', '.join(obj.sandbox_violations)
        return format_html(
            '<span style="color: red; font-weight: bold;">⚠️ {}</span>',
            violations_str
        )
    violations_display.short_description = 'Violations'

    actions = ['regrade_submissions']

    def regrade_submissions(self, request, queryset):
        """Regrade selected submissions"""
        count = 0
        for submission in queryset:
            # Reset status to pending for regrading
            submission.status = 'pending'
            submission.save(update_fields=['status'])
            count += 1

        self.message_user(request, f'{count} submission(s) queued for regrading.')
    regrade_submissions.short_description = 'Regrade selected submissions'


@admin.register(GraderQueueMetrics)
class GraderQueueMetricsAdmin(admin.ModelAdmin):
    """Admin interface for queue metrics"""

    list_display = [
        'timestamp',
        'queue_depth_display',
        'success_rate_display',
        'avg_processing_time_display',
        'active_workers',
    ]

    list_filter = [
        'timestamp',
    ]

    readonly_fields = [
        'timestamp',
        'pending_count',
        'processing_count',
        'success_count_1h',
        'failure_count_1h',
        'timeout_count_1h',
        'sandbox_error_count_1h',
        'avg_processing_time_ms',
        'p95_processing_time_ms',
        'p99_processing_time_ms',
        'active_workers',
    ]

    date_hierarchy = 'timestamp'

    fieldsets = (
        ('Timestamp', {
            'fields': ('timestamp',)
        }),
        ('Queue Depth', {
            'fields': (
                'pending_count',
                'processing_count',
            )
        }),
        ('Outcome Counts (Last Hour)', {
            'fields': (
                'success_count_1h',
                'failure_count_1h',
                'timeout_count_1h',
                'sandbox_error_count_1h',
            )
        }),
        ('Performance', {
            'fields': (
                'avg_processing_time_ms',
                'p95_processing_time_ms',
                'p99_processing_time_ms',
            )
        }),
        ('Workers', {
            'fields': ('active_workers',)
        }),
    )

    def queue_depth_display(self, obj):
        """Display queue depth"""
        total = obj.pending_count + obj.processing_count

        if total == 0:
            color = 'green'
        elif total < 50:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span> (Pending: {}, Processing: {})',
            color,
            total,
            obj.pending_count,
            obj.processing_count
        )
    queue_depth_display.short_description = 'Queue Depth'

    def success_rate_display(self, obj):
        """Display success rate from last hour"""
        total_1h = (
            obj.success_count_1h +
            obj.failure_count_1h +
            obj.timeout_count_1h +
            obj.sandbox_error_count_1h
        )

        if total_1h == 0:
            return '—'

        success_rate = (obj.success_count_1h / total_1h) * 100

        if success_rate >= 90:
            color = 'green'
        elif success_rate >= 70:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {}; font-weight: bold;">{:.1f}%</span> ({}/{})',
            color,
            success_rate,
            obj.success_count_1h,
            total_1h
        )
    success_rate_display.short_description = 'Success Rate (1h)'

    def avg_processing_time_display(self, obj):
        """Display average processing time"""
        if obj.avg_processing_time_ms is None:
            return '—'

        avg_time = obj.avg_processing_time_ms

        if avg_time < 1000:
            color = 'green'
        elif avg_time < 5000:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {};">{} ms</span> (p95: {} ms, p99: {} ms)',
            color,
            avg_time,
            obj.p95_processing_time_ms or '—',
            obj.p99_processing_time_ms or '—'
        )
    avg_processing_time_display.short_description = 'Avg Processing Time'
