"""
DRF serializers for email templates and campaigns.

@spec: email-notifications-pipeline_spec.md
"""

from rest_framework import serializers

from .models import Campaign, CampaignRecipient, Template


class TemplateSerializer(serializers.ModelSerializer):
    """Serializer for email templates."""

    class Meta:
        model = Template
        fields = [
            'id', 'name', 'category', 'subject', 'body_html', 'body_text',
            'language', 'tenant_branding', 'org_slug', 'is_active',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class CampaignListSerializer(serializers.ModelSerializer):
    """Compact serializer for campaign list view."""

    class Meta:
        model = Campaign
        fields = [
            'id', 'name', 'status', 'org_slug', 'scheduled_at',
            'total_recipients', 'sent_count', 'failed_count', 'skipped_count',
            'created_at',
        ]


class CampaignCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating new campaigns."""

    class Meta:
        model = Campaign
        fields = [
            'name', 'template', 'segment', 'org_slug', 'scheduled_at',
        ]


class CampaignDetailSerializer(serializers.ModelSerializer):
    """Full serializer for campaign detail view."""

    template_name = serializers.CharField(source='template.name', read_only=True)

    class Meta:
        model = Campaign
        fields = [
            'id', 'name', 'template', 'template_name', 'segment', 'status',
            'org_slug', 'scheduled_at', 'started_at', 'completed_at',
            'total_recipients', 'sent_count', 'failed_count', 'skipped_count',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'status', 'started_at', 'completed_at',
            'total_recipients', 'sent_count', 'failed_count', 'skipped_count',
            'created_by', 'created_at', 'updated_at',
        ]


class CampaignRecipientSerializer(serializers.ModelSerializer):
    """Serializer for campaign recipient status."""

    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = CampaignRecipient
        fields = [
            'id', 'user', 'username', 'status', 'error_message', 'sent_at',
            'created_at',
        ]
