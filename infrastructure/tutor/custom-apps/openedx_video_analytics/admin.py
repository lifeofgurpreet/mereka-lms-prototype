"""
Video Analytics Django Admin

Admin interface for video playback events and analytics summaries.

@spec: video-pipeline-delivery_spec.md (Phase 4)
@bead: mereka-lms-17jr
"""

from django.contrib import admin
from .models import VideoPlaybackEvent, VideoAnalyticsSummary


@admin.register(VideoPlaybackEvent)
class VideoPlaybackEventAdmin(admin.ModelAdmin):
    """
    Django admin for VideoPlaybackEvent model.

    Features:
    - List view with filters by event_type, course, timestamp
    - Search by video_id, user, session_id
    - Read-only view (events should not be edited)
    """

    list_display = [
        'id',
        'user',
        'event_type',
        'video_id',
        'position',
        'timestamp',
        'org_slug',
    ]

    list_filter = [
        'event_type',
        'timestamp',
        'org_slug',
    ]

    search_fields = [
        'video_id',
        'user__username',
        'user__email',
        'session_id',
    ]

    readonly_fields = [
        'user',
        'course_key',
        'video_id',
        'event_type',
        'position',
        'duration',
        'timestamp',
        'org_slug',
        'session_id',
        'user_agent',
        'ip_address_hash',
    ]

    date_hierarchy = 'timestamp'

    def has_add_permission(self, request):
        """
        Disable manual creation of events via admin.
        Events must be created through the API.
        """
        return False

    def has_change_permission(self, request, obj=None):
        """
        Disable editing of events (immutable log).
        """
        return False

    def has_delete_permission(self, request, obj=None):
        """
        Allow deletion for cleanup purposes (admin only).
        """
        return request.user.is_superuser


@admin.register(VideoAnalyticsSummary)
class VideoAnalyticsSummaryAdmin(admin.ModelAdmin):
    """
    Django admin for VideoAnalyticsSummary model.

    Features:
    - List view with key metrics
    - Filters by date, course, org
    - Search by video_id
    - Regenerate summaries action
    """

    list_display = [
        'video_id',
        'date',
        'org_slug',
        'play_count',
        'unique_viewers',
        'completion_count',
        'display_completion_rate',
        'avg_watch_time',
    ]

    list_filter = [
        'date',
        'org_slug',
    ]

    search_fields = [
        'video_id',
        'course_key',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    date_hierarchy = 'date'

    actions = ['regenerate_summaries']

    def display_completion_rate(self, obj):
        """
        Display completion rate as percentage.
        """
        return f"{obj.completion_rate * 100:.1f}%"

    display_completion_rate.short_description = 'Completion Rate'

    def regenerate_summaries(self, request, queryset):
        """
        Admin action to regenerate selected summaries.
        """
        from .tasks import aggregate_video_analytics_daily

        dates_processed = set()

        for summary in queryset:
            date_str = summary.date.strftime('%Y-%m-%d')
            if date_str not in dates_processed:
                aggregate_video_analytics_daily.delay(date_str)
                dates_processed.add(date_str)

        self.message_user(
            request,
            f"Regenerating summaries for {len(dates_processed)} date(s). "
            f"Check Celery logs for progress."
        )

    regenerate_summaries.short_description = 'Regenerate selected summaries'
