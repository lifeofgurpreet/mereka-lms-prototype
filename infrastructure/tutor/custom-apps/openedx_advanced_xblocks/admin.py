"""
Django admin interface for Advanced XBlocks

Provides management interface for randomization, accessibility settings,
and gradebook integration monitoring.
"""
from django.contrib import admin
from django.utils.html import format_html
from .models import (
    RandomizedQuestionPool,
    AnswerShufflingState,
    DragDropInteraction,
    MathInputSubmission,
    XBlockAccessibilitySettings,
    XBlockGradebookEntry,
)


@admin.register(RandomizedQuestionPool)
class RandomizedQuestionPoolAdmin(admin.ModelAdmin):
    """Admin for randomized question pools (AC-ASS-024)"""

    list_display = [
        'pool_id',
        'user',
        'course_key',
        'questions_shown',
        'created_at',
    ]
    list_filter = ['course_key', 'created_at']
    search_fields = ['pool_id', 'user__username', 'user__email']
    readonly_fields = [
        'randomization_seed',
        'selected_question_indices',
        'created_at',
    ]

    fieldsets = [
        ('Pool Configuration', {
            'fields': ['pool_id', 'course_key', 'usage_key']
        }),
        ('Student', {
            'fields': ['user']
        }),
        ('Randomization', {
            'fields': [
                'total_questions',
                'questions_to_show',
                'randomization_seed',
                'selected_question_indices',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def questions_shown(self, obj):
        """Display question count"""
        return f"{obj.questions_to_show} of {obj.total_questions}"

    questions_shown.short_description = 'Questions'


@admin.register(AnswerShufflingState)
class AnswerShufflingStateAdmin(admin.ModelAdmin):
    """Admin for answer shuffling (AC-ASS-027)"""

    list_display = [
        'usage_key',
        'user',
        'course_key',
        'shuffle_preview',
        'created_at',
    ]
    list_filter = ['course_key', 'created_at']
    search_fields = ['user__username', 'user__email']
    readonly_fields = [
        'randomization_seed',
        'original_order',
        'shuffled_order',
        'created_at',
    ]

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key']
        }),
        ('Student', {
            'fields': ['user']
        }),
        ('Shuffling', {
            'fields': [
                'original_order',
                'shuffled_order',
                'randomization_seed',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def shuffle_preview(self, obj):
        """Display shuffling pattern"""
        if obj.shuffled_order:
            return format_html(
                '<code>{} → {}</code>',
                obj.original_order,
                obj.shuffled_order
            )
        return '-'

    shuffle_preview.short_description = 'Shuffle Pattern'


@admin.register(DragDropInteraction)
class DragDropInteractionAdmin(admin.ModelAdmin):
    """Admin for drag-drop interactions (AC-ASS-022, AC-ASS-028)"""

    list_display = [
        'user',
        'item_placement',
        'is_correct',
        'input_method',
        'interaction_time_display',
        'created_at',
    ]
    list_filter = [
        'is_correct',
        'input_method',
        'course_key',
        'created_at',
    ]
    search_fields = ['user__username', 'user__email', 'item_id', 'zone_id']
    readonly_fields = ['created_at']

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key']
        }),
        ('Student', {
            'fields': ['user']
        }),
        ('Interaction', {
            'fields': [
                'item_id',
                'zone_id',
                'is_correct',
                'input_method',
                'interaction_time_ms',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def item_placement(self, obj):
        """Display drag-drop action"""
        icon = '✓' if obj.is_correct else '✗'
        return format_html(
            '<code>{} {} → {}</code>',
            icon,
            obj.item_id,
            obj.zone_id
        )

    item_placement.short_description = 'Placement'

    def interaction_time_display(self, obj):
        """Display interaction time in seconds"""
        seconds = obj.interaction_time_ms / 1000
        return f"{seconds:.2f}s"

    interaction_time_display.short_description = 'Time'

    actions = ['export_accessibility_report']

    def export_accessibility_report(self, request, queryset):
        """Export accessibility usage report"""
        keyboard_count = queryset.filter(input_method='keyboard').count()
        mouse_count = queryset.filter(input_method='mouse').count()
        sr_count = queryset.filter(input_method='screen_reader').count()
        total = queryset.count()

        self.message_user(
            request,
            f"Accessibility Report: Keyboard: {keyboard_count}/{total} "
            f"({keyboard_count/total*100:.1f}%), "
            f"Mouse: {mouse_count}/{total} ({mouse_count/total*100:.1f}%), "
            f"Screen Reader: {sr_count}/{total} ({sr_count/total*100:.1f}%)"
        )

    export_accessibility_report.short_description = \
        'Export accessibility usage report'


@admin.register(MathInputSubmission)
class MathInputSubmissionAdmin(admin.ModelAdmin):
    """Admin for math input submissions (AC-ASS-023)"""

    list_display = [
        'user',
        'latex_preview',
        'is_correct',
        'render_status',
        'created_at',
    ]
    list_filter = [
        'is_correct',
        'mathjax_render_success',
        'course_key',
        'created_at',
    ]
    search_fields = ['user__username', 'user__email', 'latex_input']
    readonly_fields = ['created_at']

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key']
        }),
        ('Student', {
            'fields': ['user']
        }),
        ('Math Input', {
            'fields': [
                'latex_input',
                'expected_answer',
                'is_correct',
                'tolerance',
            ]
        }),
        ('Rendering', {
            'fields': [
                'mathjax_render_success',
                'render_error',
            ]
        }),
        ('Metadata', {
            'fields': ['created_at']
        }),
    ]

    def latex_preview(self, obj):
        """Display LaTeX preview"""
        preview = obj.latex_input[:50]
        if len(obj.latex_input) > 50:
            preview += '...'
        return format_html('<code>{}</code>', preview)

    latex_preview.short_description = 'LaTeX Input'

    def render_status(self, obj):
        """Display rendering status"""
        if obj.mathjax_render_success:
            return format_html('<span style="color: green;">✓ Rendered</span>')
        return format_html(
            '<span style="color: red;">✗ Error: {}</span>',
            obj.render_error[:50] if obj.render_error else 'Unknown'
        )

    render_status.short_description = 'Render Status'


@admin.register(XBlockAccessibilitySettings)
class XBlockAccessibilitySettingsAdmin(admin.ModelAdmin):
    """Admin for accessibility settings (AC-ASS-028)"""

    list_display = [
        'user',
        'keyboard_shortcuts',
        'screen_reader_support',
        'visual_preferences',
        'updated_at',
    ]
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['updated_at']

    fieldsets = [
        ('User', {
            'fields': ['user']
        }),
        ('Keyboard Navigation', {
            'fields': [
                'enable_keyboard_shortcuts',
                'keyboard_focus_indicator',
            ]
        }),
        ('Screen Reader', {
            'fields': ['announce_all_interactions']
        }),
        ('Visual Preferences', {
            'fields': [
                'reduce_motion',
                'high_contrast_mode',
            ]
        }),
        ('Metadata', {
            'fields': ['updated_at']
        }),
    ]

    def keyboard_shortcuts(self, obj):
        """Display keyboard shortcuts status"""
        return '✓ Enabled' if obj.enable_keyboard_shortcuts else '✗ Disabled'

    keyboard_shortcuts.short_description = 'Keyboard'

    def screen_reader_support(self, obj):
        """Display screen reader status"""
        return '✓ Enabled' if obj.announce_all_interactions else '✗ Disabled'

    screen_reader_support.short_description = 'Screen Reader'

    def visual_preferences(self, obj):
        """Display visual preferences"""
        prefs = []
        if obj.reduce_motion:
            prefs.append('Reduced Motion')
        if obj.high_contrast_mode:
            prefs.append('High Contrast')
        return ', '.join(prefs) if prefs else 'Default'

    visual_preferences.short_description = 'Visual'


@admin.register(XBlockGradebookEntry)
class XBlockGradebookEntryAdmin(admin.ModelAdmin):
    """Admin for gradebook entries (AC-ASS-026)"""

    list_display = [
        'user',
        'xblock_type',
        'grade_display',
        'sync_status',
        'graded_at',
    ]
    list_filter = [
        'xblock_type',
        'gradebook_synced',
        'course_key',
        'graded_at',
    ]
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['grade_percentage', 'graded_at']

    fieldsets = [
        ('Problem', {
            'fields': ['usage_key', 'course_key', 'xblock_type']
        }),
        ('Student', {
            'fields': ['user']
        }),
        ('Grade', {
            'fields': [
                'score_earned',
                'score_possible',
                'grade_percentage',
            ]
        }),
        ('Gradebook Sync', {
            'fields': [
                'gradebook_synced',
                'sync_error',
            ]
        }),
        ('Metadata', {
            'fields': ['graded_at']
        }),
    ]

    def grade_display(self, obj):
        """Display grade with color coding"""
        percentage = obj.grade_percentage
        color = 'green' if percentage >= 70 else 'orange' if percentage >= 50 else 'red'
        return format_html(
            '<span style="color: {};">{:.1f}% ({}/{})</span>',
            color,
            percentage,
            obj.score_earned,
            obj.score_possible
        )

    grade_display.short_description = 'Grade'

    def sync_status(self, obj):
        """Display sync status"""
        if obj.gradebook_synced:
            return format_html('<span style="color: green;">✓ Synced</span>')
        if obj.sync_error:
            return format_html(
                '<span style="color: red;">✗ Error: {}</span>',
                obj.sync_error[:30]
            )
        return format_html('<span style="color: orange;">⧗ Pending</span>')

    sync_status.short_description = 'Sync Status'

    actions = ['retry_gradebook_sync']

    def retry_gradebook_sync(self, request, queryset):
        """Retry gradebook sync for failed entries"""
        failed = queryset.filter(gradebook_synced=False)
        count = failed.count()

        # TODO: Implement gradebook sync logic
        # This would integrate with Open edX gradebook API

        self.message_user(
            request,
            f"Gradebook sync retry is not yet implemented. {count} grade(s) selected but no action taken.",
            level='warning'
        )

    retry_gradebook_sync.short_description = 'Retry gradebook sync'
