from django.contrib import admin

from .models import MctVideoMapping, MigrationReport


@admin.register(MctVideoMapping)
class MctVideoMappingAdmin(admin.ModelAdmin):
    list_display = (
        'mct_video_id',
        'mux_asset_id',
        'mux_status',
        'content_language',
        'course_key',
        'playback_verified',
        'last_health_check',
    )
    list_filter = ('mux_status', 'content_language', 'playback_verified', 'migration_batch')
    search_fields = (
        'mct_video_id',
        'mux_asset_id',
        'mux_playback_id',
        'olx_usage_key',
        'course_key',
    )
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-created_at',)


@admin.register(MigrationReport)
class MigrationReportAdmin(admin.ModelAdmin):
    list_display = (
        'report_id',
        'generated_at',
        'total_expected',
        'total_ready',
        'total_errored',
        'is_complete',
    )
    list_filter = ('is_complete', 'generated_at')
    readonly_fields = (
        'report_id',
        'generated_at',
        'total_expected',
        'total_found',
        'total_ready',
        'total_preparing',
        'total_errored',
        'total_playback_verified',
        'failed_asset_ids',
        'report_data',
        'is_complete',
    )
    ordering = ('-generated_at',)
