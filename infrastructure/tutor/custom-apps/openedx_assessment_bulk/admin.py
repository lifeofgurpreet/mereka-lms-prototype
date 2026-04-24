"""
Django admin interface for Assessment Bulk Operations

Provides management interface for bulk regrade, exports, imports, and auditing.
"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from .models import (
    BulkRegradeJob,
    GradeOverrideAudit,
    ExamSubmissionIPLog,
    BulkGradeExport,
    BulkGradeImport,
    GradeAccessLog,
)


@admin.register(BulkRegradeJob)
class BulkRegradeJobAdmin(admin.ModelAdmin):
    """Admin for bulk regrade jobs (AC-ASS-029)"""

    list_display = [
        'job_id',
        'course_key',
        'status',
        'progress_display',
        'performance_display',
        'created_by',
        'created_at',
    ]
    list_filter = ['status', 'created_at', 'course_key']
    search_fields = ['job_id', 'course_key', 'created_by__username']
    readonly_fields = [
        'job_id',
        'progress_percentage',
        'estimated_time_remaining',
        'duration_seconds',
        'checkpoint_data',
        'created_at',
        'updated_at',
    ]

    fieldsets = [
        ('Job Information', {
            'fields': ['job_id', 'course_key', 'usage_key', 'created_by']
        }),
        ('Status', {
            'fields': ['status', 'error_message', 'error_details']
        }),
        ('Progress (AC-ASS-029)', {
            'fields': [
                'total_students',
                'processed_students',
                'failed_students',
                'progress_percentage',
                'estimated_time_remaining',
            ]
        }),
        ('Performance Metrics (AC-ASS-029: 5000 students in 5 minutes)', {
            'fields': [
                'started_at',
                'completed_at',
                'duration_seconds',
            ]
        }),
        ('Checkpoint/Resume (AC-ASS-029)', {
            'fields': [
                'checkpoint_data',
                'last_processed_user_id',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at', 'updated_at']
        }),
    ]

    def progress_display(self, obj):
        """Display progress bar"""
        percentage = obj.calculate_progress_percentage()
        color = 'green' if percentage == 100 else 'orange' if percentage > 50 else 'blue'

        return format_html(
            '<div style="width: 100px; background: #f0f0f0; border-radius: 3px;">'
            '<div style="width: {0}%; background: {1}; color: white; text-align: center; '
            'border-radius: 3px; padding: 2px;">{2:.1f}%</div></div>',
            percentage,
            color,
            percentage
        )

    progress_display.short_description = 'Progress'

    def performance_display(self, obj):
        """Display performance metrics"""
        if not obj.duration_seconds:
            return '-'

        students_per_minute = (obj.processed_students / obj.duration_seconds) * 60 if obj.duration_seconds > 0 else 0

        # AC-ASS-029: Must complete 5000 students in 5 minutes (1000 students/min)
        target_rate = 1000
        color = 'green' if students_per_minute >= target_rate else 'red'

        return format_html(
            '<span style="color: {};">{:.0f} students/min (target: 1000)</span>',
            color,
            students_per_minute
        )

    performance_display.short_description = 'Performance'

    def progress_percentage(self, obj):
        """Calculate and display progress percentage"""
        return f"{obj.calculate_progress_percentage():.1f}%"

    progress_percentage.short_description = 'Progress %'

    def estimated_time_remaining(self, obj):
        """Display estimated time remaining"""
        remaining = obj.calculate_estimated_time_remaining()
        if remaining is None:
            return '-'

        minutes = int(remaining / 60)
        seconds = int(remaining % 60)
        return f"{minutes}m {seconds}s"

    estimated_time_remaining.short_description = 'ETA'

    actions = ['resume_failed_jobs', 'cancel_jobs']

    def resume_failed_jobs(self, request, queryset):
        """Resume failed jobs from checkpoint (AC-ASS-029)"""
        resumable = queryset.filter(status='failed').exclude(checkpoint_data={})
        count = resumable.count()

        for job in resumable:
            if job.can_resume():
                job.status = 'pending'
                job.save(update_fields=['status', 'updated_at'])

        self.message_user(
            request,
            f"Queued {count} job(s) for resume from checkpoint"
        )

    resume_failed_jobs.short_description = 'Resume from checkpoint (AC-ASS-029)'

    def cancel_jobs(self, request, queryset):
        """Cancel pending/in_progress jobs"""
        cancelable = queryset.filter(status__in=['pending', 'in_progress'])
        count = cancelable.update(
            status='cancelled',
            updated_at=timezone.now()
        )

        self.message_user(request, f"Cancelled {count} job(s)")

    cancel_jobs.short_description = 'Cancel jobs'


@admin.register(GradeOverrideAudit)
class GradeOverrideAuditAdmin(admin.ModelAdmin):
    """Admin for grade override audit trail (AC-ASS-030)"""

    list_display = [
        'student',
        'usage_key',
        'grade_change_display',
        'overridden_by',
        'override_type',
        'created_at',
    ]
    list_filter = ['override_type', 'created_at', 'course_key']
    search_fields = [
        'student__username',
        'student__email',
        'overridden_by__username',
    ]
    readonly_fields = [
        'original_score',
        'new_score',
        'max_score',
        'original_grade_percentage',
        'new_grade_percentage',
        'grade_change',
        'created_at',
    ]

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key']
        }),
        ('Student', {
            'fields': ['student']
        }),
        ('Grade Override (AC-ASS-030: original + new grade)', {
            'fields': [
                'original_score',
                'new_score',
                'max_score',
                'original_grade_percentage',
                'new_grade_percentage',
                'grade_change',
            ]
        }),
        ('Staff Override (AC-ASS-030: staff user, timestamp, reason)', {
            'fields': [
                'overridden_by',
                'override_type',
                'reason',
                'created_at',
            ]
        }),
    ]

    def grade_change_display(self, obj):
        """Display grade change with color coding"""
        change = obj.calculate_change()
        change_pct = obj.calculate_change_percentage()

        if change > 0:
            color = 'green'
            arrow = '↑'
        elif change < 0:
            color = 'red'
            arrow = '↓'
        else:
            color = 'gray'
            arrow = '='

        return format_html(
            '<span style="color: {};">{} {:.1f} ({:+.1f}%)</span>',
            color,
            arrow,
            obj.new_score,
            change_pct
        )

    grade_change_display.short_description = 'Grade Change'

    def grade_change(self, obj):
        """Calculate and display grade change"""
        change = obj.calculate_change()
        change_pct = obj.calculate_change_percentage()
        return f"{change:+.1f} points ({change_pct:+.1f}%)"

    grade_change.short_description = 'Change'


@admin.register(ExamSubmissionIPLog)
class ExamSubmissionIPLogAdmin(admin.ModelAdmin):
    """Admin for IP logging (AC-ASS-035)"""

    list_display = [
        'student',
        'submission_type',
        'ip_display',
        'location_display',
        'security_flags',
        'created_at',
    ]
    list_filter = [
        'submission_type',
        'is_vpn',
        'is_proxy',
        'country_code',
        'created_at',
    ]
    search_fields = [
        'student__username',
        'student__email',
        'ip_address',
        'ip_address_hash',
    ]
    readonly_fields = [
        'ip_address_hash',
        'created_at',
    ]

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key']
        }),
        ('Student', {
            'fields': ['student']
        }),
        ('IP Logging (AC-ASS-035: capture IP)', {
            'fields': [
                'ip_address',
                'ip_address_hash',
                'submission_type',
                'user_agent',
            ]
        }),
        ('Geolocation', {
            'fields': [
                'country_code',
                'region',
            ]
        }),
        ('Security Flags', {
            'fields': [
                'is_vpn',
                'is_proxy',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def ip_display(self, obj):
        """Display IP with hash indicator"""
        return format_html(
            '<code>{}</code> <small>(hash: {}...)</small>',
            obj.ip_address,
            obj.ip_address_hash[:16]
        )

    ip_display.short_description = 'IP Address'

    def location_display(self, obj):
        """Display location"""
        if obj.country_code:
            location = obj.country_code
            if obj.region:
                location += f", {obj.region}"
            return location
        return '-'

    location_display.short_description = 'Location'

    def security_flags(self, obj):
        """Display security flags"""
        flags = []
        if obj.is_vpn:
            flags.append(format_html('<span style="color: orange;">VPN</span>'))
        if obj.is_proxy:
            flags.append(format_html('<span style="color: orange;">Proxy</span>'))

        if flags:
            return format_html(' '.join(flags))
        return format_html('<span style="color: green;">Clean</span>')

    security_flags.short_description = 'Security'


@admin.register(BulkGradeExport)
class BulkGradeExportAdmin(admin.ModelAdmin):
    """Admin for bulk grade exports (AC-ASS-033)"""

    list_display = [
        'export_id',
        'course_key',
        'format',
        'filters_display',
        'status',
        'file_info_display',
        'created_at',
    ]
    list_filter = ['status', 'format', 'created_at']
    search_fields = ['export_id', 'course_key']
    readonly_fields = [
        'export_id',
        'file_size_bytes',
        'total_rows',
        'started_at',
        'completed_at',
        'created_at',
        'updated_at',
    ]

    fieldsets = [
        ('Export Information', {
            'fields': ['export_id', 'course_key', 'created_by']
        }),
        ('Filters (AC-ASS-033: filter by section/assignment)', {
            'fields': [
                'section',
                'assignment_type',
                'usage_keys',
            ]
        }),
        ('Configuration', {
            'fields': [
                'format',
                'include_metadata',
            ]
        }),
        ('Status', {
            'fields': ['status', 'error_message']
        }),
        ('Results', {
            'fields': [
                'file_path',
                'file_size_bytes',
                'total_rows',
            ]
        }),
        ('Timing', {
            'fields': [
                'started_at',
                'completed_at',
                'created_at',
                'updated_at',
            ]
        }),
    ]

    def filters_display(self, obj):
        """Display active filters"""
        filters = []
        if obj.section:
            filters.append(f"Section: {obj.section}")
        if obj.assignment_type:
            filters.append(f"Type: {obj.assignment_type}")
        if obj.usage_keys:
            filters.append(f"{len(obj.usage_keys)} problems")

        return ', '.join(filters) if filters else 'No filters'

    filters_display.short_description = 'Filters'

    def file_info_display(self, obj):
        """Display file information"""
        if not obj.file_path:
            return '-'

        size_mb = obj.file_size_bytes / (1024 * 1024) if obj.file_size_bytes else 0
        return format_html(
            '<code>{}</code><br><small>{:.2f} MB, {} rows</small>',
            obj.file_path.split('/')[-1],
            size_mb,
            obj.total_rows or 0
        )

    file_info_display.short_description = 'File'


@admin.register(BulkGradeImport)
class BulkGradeImportAdmin(admin.ModelAdmin):
    """Admin for bulk grade imports (AC-ASS-034)"""

    list_display = [
        'import_id',
        'course_key',
        'status',
        'validation_status_display',
        'import_results_display',
        'created_at',
    ]
    list_filter = ['status', 'is_valid', 'created_at']
    search_fields = ['import_id', 'course_key']
    readonly_fields = [
        'import_id',
        'file_size_bytes',
        'validation_errors',
        'validation_warnings',
        'is_valid',
        'preview_data',
        'total_rows',
        'duplicates_found',
        'imported_rows',
        'skipped_rows',
        'failed_rows',
        'started_at',
        'completed_at',
        'created_at',
        'updated_at',
    ]

    fieldsets = [
        ('Import Information', {
            'fields': ['import_id', 'course_key', 'created_by']
        }),
        ('Upload', {
            'fields': [
                'uploaded_file_path',
                'file_size_bytes',
                'total_rows',
            ]
        }),
        ('Validation (AC-ASS-034: validate CSV)', {
            'fields': [
                'is_valid',
                'validation_errors',
                'validation_warnings',
            ]
        }),
        ('Preview (AC-ASS-034: show preview)', {
            'fields': ['preview_data']
        }),
        ('Deduplication (AC-ASS-034: no duplicate grades)', {
            'fields': [
                'duplicate_detection_enabled',
                'duplicates_found',
                'duplicate_handling',
            ]
        }),
        ('Status', {
            'fields': ['status', 'error_message']
        }),
        ('Results', {
            'fields': [
                'imported_rows',
                'skipped_rows',
                'failed_rows',
            ]
        }),
        ('Timing', {
            'fields': [
                'started_at',
                'completed_at',
                'created_at',
                'updated_at',
            ]
        }),
    ]

    def validation_status_display(self, obj):
        """Display validation status"""
        if obj.is_valid:
            return format_html('<span style="color: green;">✓ Valid</span>')

        error_count = len(obj.validation_errors)
        warn_count = len(obj.validation_warnings)

        return format_html(
            '<span style="color: red;">✗ Invalid</span><br>'
            '<small>{} error(s), {} warning(s)</small>',
            error_count,
            warn_count
        )

    validation_status_display.short_description = 'Validation'

    def import_results_display(self, obj):
        """Display import results"""
        if obj.status != 'completed':
            return '-'

        return format_html(
            '<span style="color: green;">{} imported</span><br>'
            '<small>{} skipped, {} failed</small>',
            obj.imported_rows,
            obj.skipped_rows,
            obj.failed_rows
        )

    import_results_display.short_description = 'Results'


@admin.register(GradeAccessLog)
class GradeAccessLogAdmin(admin.ModelAdmin):
    """Admin for grade access auditing (AC-ASS-036)"""

    list_display = [
        'accessed_by',
        'access_target',
        'access_type',
        'authorization_display',
        'ip_address',
        'created_at',
    ]
    list_filter = [
        'access_type',
        'is_authorized',
        'authorization_reason',
        'created_at',
    ]
    search_fields = [
        'accessed_by__username',
        'accessed_student__username',
        'ip_address',
    ]
    readonly_fields = ['created_at']

    fieldsets = [
        ('Access Details', {
            'fields': [
                'course_key',
                'accessed_by',
                'accessed_student',
                'access_type',
            ]
        }),
        ('Authorization (AC-ASS-036: prevent unauthorized access)', {
            'fields': [
                'is_authorized',
                'authorization_reason',
            ]
        }),
        ('Request Metadata', {
            'fields': [
                'ip_address',
                'user_agent',
                'request_path',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def access_target(self, obj):
        """Display access target"""
        if obj.accessed_student:
            return obj.accessed_student.username
        return '(bulk access)'

    access_target.short_description = 'Target'

    def authorization_display(self, obj):
        """Display authorization status"""
        if obj.is_authorized:
            return format_html(
                '<span style="color: green;">✓ Authorized</span><br>'
                '<small>{}</small>',
                obj.get_authorization_reason_display()
            )
        return format_html(
            '<span style="color: red;">✗ UNAUTHORIZED</span><br>'
            '<small>SECURITY VIOLATION</small>'
        )

    authorization_display.short_description = 'Authorization'

    actions = ['flag_unauthorized_access']

    def flag_unauthorized_access(self, request, queryset):
        """Flag unauthorized access attempts for review"""
        unauthorized = queryset.filter(is_authorized=False)
        count = unauthorized.count()

        # TODO: Trigger security alert/notification

        self.message_user(
            request,
            f"Flagged {count} unauthorized access attempt(s) for security review",
            level='WARNING' if count > 0 else 'INFO'
        )

    flag_unauthorized_access.short_description = 'Flag unauthorized access (AC-ASS-036)'
