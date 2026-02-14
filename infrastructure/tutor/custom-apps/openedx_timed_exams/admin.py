"""Django admin for Timed Exams"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from django.db.models import Count, Q
from .models import ExamTimeExtension, ExamSession, ExamGradeRelease


@admin.register(ExamTimeExtension)
class ExamTimeExtensionAdmin(admin.ModelAdmin):
    """Admin interface for exam time extensions"""

    list_display = [
        'user',
        'course_id',
        'usage_key',
        'extension_display',
        'status_badge',
        'validity_display',
        'approved_by',
    ]

    list_filter = [
        'is_active',
        'approved_at',
        'valid_from',
        'course_id',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'reason',
        'documentation',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
        'approved_at',
    ]

    date_hierarchy = 'valid_from'

    fieldsets = (
        ('Student & Scope', {
            'fields': (
                'user',
                'course_id',
                'usage_key',
            )
        }),
        ('Extension Configuration', {
            'fields': (
                'multiplier',
                'additional_minutes',
            ),
            'description': 'Time multiplier is applied first, then additional minutes are added.'
        }),
        ('Accommodation Details', {
            'fields': (
                'reason',
                'documentation',
            )
        }),
        ('Approval', {
            'fields': (
                'approved_by',
                'approved_at',
            )
        }),
        ('Validity Period', {
            'fields': (
                'valid_from',
                'valid_until',
                'is_active',
            ),
            'description': 'Leave valid_until blank for no expiration.'
        }),
        ('Timestamps', {
            'fields': (
                'created_at',
                'updated_at',
            )
        }),
    )

    def extension_display(self, obj):
        """Display extension amount"""
        display = f"{obj.multiplier}x"
        if obj.additional_minutes > 0:
            display += f" +{obj.additional_minutes}min"

        # Show example calculation
        example = obj.calculate_extended_time(60)
        return format_html(
            '{}<br/><small style="color: gray;">Example: 60min → {}min</small>',
            display,
            example
        )
    extension_display.short_description = 'Extension'

    def status_badge(self, obj):
        """Display validity status as colored badge"""
        if obj.is_valid_now():
            color = 'green'
            text = 'ACTIVE'
        elif not obj.is_active:
            color = 'gray'
            text = 'INACTIVE'
        elif obj.valid_from > timezone.now():
            color = 'orange'
            text = 'FUTURE'
        else:
            color = 'red'
            text = 'EXPIRED'

        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px; font-weight: bold;">{}</span>',
            color,
            text
        )
    status_badge.short_description = 'Status'

    def validity_display(self, obj):
        """Display validity period"""
        from_str = obj.valid_from.strftime('%Y-%m-%d')
        until_str = obj.valid_until.strftime('%Y-%m-%d') if obj.valid_until else 'No expiry'
        return f"{from_str} → {until_str}"
    validity_display.short_description = 'Validity Period'

    actions = ['approve_extensions', 'deactivate_extensions', 'activate_extensions']

    def approve_extensions(self, request, queryset):
        """Approve selected time extensions"""
        count = 0
        for extension in queryset.filter(approved_at__isnull=True):
            extension.approved_by = request.user
            extension.approved_at = timezone.now()
            extension.save(update_fields=['approved_by', 'approved_at'])
            count += 1
        self.message_user(request, f'{count} time extension(s) approved.')
    approve_extensions.short_description = 'Approve selected time extensions'

    def deactivate_extensions(self, request, queryset):
        """Deactivate selected time extensions"""
        count = queryset.update(is_active=False)
        self.message_user(request, f'{count} time extension(s) deactivated.')
    deactivate_extensions.short_description = 'Deactivate selected extensions'

    def activate_extensions(self, request, queryset):
        """Activate selected time extensions"""
        count = queryset.update(is_active=True)
        self.message_user(request, f'{count} time extension(s) activated.')
    activate_extensions.short_description = 'Activate selected extensions'


@admin.register(ExamSession)
class ExamSessionAdmin(admin.ModelAdmin):
    """Admin interface for exam sessions"""

    list_display = [
        'user',
        'usage_key',
        'status_badge',
        'duration_display',
        'remaining_time_display',
        'started_at',
        'device_info',
    ]

    list_filter = [
        'status',
        'auto_submitted',
        'started_at',
        'course_id',
    ]

    search_fields = [
        'user__username',
        'user__email',
        'session_key',
    ]

    readonly_fields = [
        'session_key',
        'device_fingerprint',
        'ip_address_hash',
        'started_at',
        'expires_at',
        'last_activity_at',
        'auto_submitted_at',
        'remaining_time_display',
    ]

    date_hierarchy = 'started_at'

    fieldsets = (
        ('Student & Exam', {
            'fields': (
                'user',
                'course_id',
                'usage_key',
            )
        }),
        ('Session Details', {
            'fields': (
                'session_key',
                'device_fingerprint',
                'ip_address_hash',
            )
        }),
        ('Timing', {
            'fields': (
                'base_duration_minutes',
                'extended_duration_minutes',
                'time_extension',
                'started_at',
                'expires_at',
                'last_activity_at',
                'remaining_time_display',
            )
        }),
        ('Status', {
            'fields': (
                'status',
                'auto_submitted',
                'auto_submitted_at',
            )
        }),
    )

    def status_badge(self, obj):
        """Display status as colored badge"""
        colors = {
            'active': 'green',
            'submitted': 'blue',
            'expired': 'orange',
            'terminated': 'red',
        }
        color = colors.get(obj.status, 'gray')

        icon = '⏱️' if obj.status == 'active' else '✓' if obj.status == 'submitted' else '⏰' if obj.status == 'expired' else '⚠️'

        return format_html(
            '{} <span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px;">{}</span>',
            icon,
            color,
            obj.get_status_display()
        )
    status_badge.short_description = 'Status'

    def duration_display(self, obj):
        """Display base and extended duration"""
        if obj.base_duration_minutes == obj.extended_duration_minutes:
            return f"{obj.base_duration_minutes} min"
        else:
            return format_html(
                '<span style="text-decoration: line-through; color: gray;">{}</span> → <strong>{}</strong> min',
                obj.base_duration_minutes,
                obj.extended_duration_minutes
            )
    duration_display.short_description = 'Duration'

    def remaining_time_display(self, obj):
        """Display remaining time"""
        if obj.status != 'active':
            return '—'

        remaining = obj.remaining_time_seconds
        if remaining <= 0:
            return format_html('<span style="color: red; font-weight: bold;">EXPIRED</span>')

        minutes = remaining // 60
        seconds = remaining % 60

        color = 'green' if minutes > 10 else 'orange' if minutes > 5 else 'red'

        return format_html(
            '<span style="color: {}; font-weight: bold;">{}:{:02d}</span>',
            color,
            minutes,
            seconds
        )
    remaining_time_display.short_description = 'Remaining'

    def device_info(self, obj):
        """Display device fingerprint (truncated)"""
        return f"{obj.device_fingerprint[:12]}..."
    device_info.short_description = 'Device'

    actions = ['terminate_sessions']

    def terminate_sessions(self, request, queryset):
        """Terminate selected active sessions"""
        count = 0
        for session in queryset.filter(status='active'):
            session.terminate(reason='admin_action')
            count += 1
        self.message_user(request, f'{count} session(s) terminated.')
    terminate_sessions.short_description = 'Terminate selected sessions'


@admin.register(ExamGradeRelease)
class ExamGradeReleaseAdmin(admin.ModelAdmin):
    """Admin interface for exam grade releases"""

    list_display = [
        'usage_key',
        'course_id',
        'release_mode',
        'release_status_badge',
        'window_close_at',
        'released_by',
    ]

    list_filter = [
        'release_mode',
        'released_manually',
        'window_close_at',
        'course_id',
    ]

    search_fields = [
        'usage_key',
    ]

    readonly_fields = [
        'released_at',
        'created_at',
        'updated_at',
    ]

    date_hierarchy = 'window_close_at'

    fieldsets = (
        ('Exam', {
            'fields': (
                'course_id',
                'usage_key',
            )
        }),
        ('Release Configuration', {
            'fields': (
                'release_mode',
                'window_close_at',
                'release_at',
            ),
            'description': 'Configure when grades should be visible to students.'
        }),
        ('Manual Release', {
            'fields': (
                'released_manually',
                'released_by',
                'released_at',
            )
        }),
        ('Timestamps', {
            'fields': (
                'created_at',
                'updated_at',
            )
        }),
    )

    def release_status_badge(self, obj):
        """Display release status"""
        should_release = obj.should_release_now()

        if should_release:
            color = 'green'
            text = 'RELEASED'
        else:
            color = 'orange'
            text = 'PENDING'

        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px; font-weight: bold;">{}</span>',
            color,
            text
        )
    release_status_badge.short_description = 'Release Status'

    actions = ['manually_release_grades']

    def manually_release_grades(self, request, queryset):
        """Manually release grades for selected exams"""
        count = 0
        for grade_release in queryset.filter(released_manually=False):
            grade_release.manual_release(request.user)
            count += 1
        self.message_user(request, f'{count} exam grade(s) released.')
    manually_release_grades.short_description = 'Manually release selected grades'
