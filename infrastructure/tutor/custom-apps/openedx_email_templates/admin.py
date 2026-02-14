"""
Django admin configuration for email templates and campaigns.

@spec: email-notifications-pipeline_spec.md
"""

from django.contrib import admin

from .models import Campaign, CampaignRecipient, Template


@admin.register(Template)
class TemplateAdmin(admin.ModelAdmin):
    """Admin for email templates."""

    list_display = ['name', 'category', 'language', 'org_slug', 'is_active', 'updated_at']
    list_filter = ['category', 'language', 'org_slug', 'is_active']
    search_fields = ['name', 'subject', 'category']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Campaign)
class CampaignAdmin(admin.ModelAdmin):
    """Admin for bulk campaigns."""

    list_display = [
        'name', 'status', 'org_slug', 'total_recipients',
        'sent_count', 'failed_count', 'scheduled_at', 'created_at',
    ]
    list_filter = ['status', 'org_slug']
    search_fields = ['name']
    readonly_fields = [
        'id', 'started_at', 'completed_at',
        'total_recipients', 'sent_count', 'failed_count', 'skipped_count',
        'created_at', 'updated_at',
    ]


@admin.register(CampaignRecipient)
class CampaignRecipientAdmin(admin.ModelAdmin):
    """Admin for campaign recipients."""

    list_display = ['campaign', 'user', 'status', 'sent_at']
    list_filter = ['status']
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['id', 'created_at']
    raw_id_fields = ['user', 'campaign']
