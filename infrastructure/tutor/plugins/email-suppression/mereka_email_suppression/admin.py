"""
Django admin configuration for email suppression.
"""

from django.contrib import admin

from .models import EmailSuppression


@admin.register(EmailSuppression)
class EmailSuppressionAdmin(admin.ModelAdmin):
    list_display = ('email', 'reason', 'bounce_count', 'bounced_at', 'created_at')
    list_filter = ('reason', 'created_at')
    search_fields = ('email',)
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-created_at',)

    fieldsets = (
        (None, {
            'fields': ('email', 'reason')
        }),
        ('Bounce Tracking', {
            'fields': ('bounce_count', 'bounced_at')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
