"""
Models for email templates and bulk campaign engine.

@spec: email-notifications-pipeline_spec.md
@covers: AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032
"""

import uuid

from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


# ── ACE Message Types ────────────────────────────────────────────────────

MESSAGE_TYPE_CHOICES = [
    ('welcome', 'Welcome'),
    ('enrollment', 'Enrollment Confirmation'),
    ('grade', 'Grade Notification'),
    ('certificate', 'Certificate Earned'),
    ('deadline', 'Deadline Reminder'),
    ('forum', 'Forum Activity'),
    ('password_reset', 'Password Reset'),
    ('account_activation', 'Account Activation'),
    ('course_announcement', 'Course Announcement'),
    ('survey', 'Survey Invitation'),
    ('marketing_promo', 'Marketing Promotion'),
    ('re_engagement', 'Re-engagement'),
    ('feedback', 'Feedback Request'),
    ('maintenance_notice', 'Maintenance Notice'),
    ('campaign', 'Bulk Campaign'),
]

LANGUAGE_CHOICES = [
    ('en', 'English'),
    ('ms', 'Bahasa Melayu'),
    ('zh-hans', 'Chinese (Simplified)'),
]

CAMPAIGN_STATUS_CHOICES = [
    ('draft', 'Draft'),
    ('scheduled', 'Scheduled'),
    ('sending', 'Sending'),
    ('paused', 'Paused'),
    ('completed', 'Completed'),
    ('failed', 'Failed'),
    ('cancelled', 'Cancelled'),
]

RECIPIENT_STATUS_CHOICES = [
    ('pending', 'Pending'),
    ('sent', 'Sent'),
    ('skipped', 'Skipped'),
    ('failed', 'Failed'),
]


class Template(models.Model):
    """
    Email template for ACE message types.

    Supports multi-language and per-tenant branding injection.

    @covers AC-025, AC-026
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    name = models.CharField(
        max_length=255,
        help_text="Human-readable template name"
    )

    category = models.CharField(
        max_length=50,
        choices=MESSAGE_TYPE_CHOICES,
        db_index=True,
        help_text="ACE message type category"
    )

    subject = models.CharField(
        max_length=255,
        help_text="Email subject line (supports {{ branding }} variables)"
    )

    body_html = models.TextField(
        help_text="HTML body template (Django template syntax)"
    )

    body_text = models.TextField(
        help_text="Plain text body template (fallback)"
    )

    language = models.CharField(
        max_length=10,
        choices=LANGUAGE_CHOICES,
        default='en',
        db_index=True,
        help_text="Template language code"
    )

    # Per-tenant branding override fields (AC-026)
    tenant_branding = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "Per-tenant branding overrides: org_display_name, org_logo_url, "
            "org_primary_color, org_accent_color, org_support_email, "
            "org_terms_url, org_privacy_url"
        )
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        default='default',
        help_text="Organization slug for multi-tenancy"
    )

    is_active = models.BooleanField(
        default=True,
        help_text="Whether this template is active"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_email_templates_template'
        unique_together = [('category', 'language', 'org_slug')]
        ordering = ['category', 'language']
        verbose_name = 'Email Template'
        verbose_name_plural = 'Email Templates'

    def __str__(self):
        return f"{self.name} ({self.category}/{self.language})"

    @classmethod
    def get_template(cls, category, language='en', org_slug='default'):
        """
        Get the active template for a given category, language, and org.

        Falls back to default org if org-specific template not found.
        Falls back to English if requested language not found.

        @covers AC-025
        """
        # Try org-specific + language
        tpl = cls.objects.filter(
            category=category, language=language,
            org_slug=org_slug, is_active=True
        ).first()
        if tpl:
            return tpl

        # Fallback: org-specific + English
        if language != 'en':
            tpl = cls.objects.filter(
                category=category, language='en',
                org_slug=org_slug, is_active=True
            ).first()
            if tpl:
                return tpl

        # Fallback: default org + requested language
        tpl = cls.objects.filter(
            category=category, language=language,
            org_slug='default', is_active=True
        ).first()
        if tpl:
            return tpl

        # Final fallback: default org + English
        return cls.objects.filter(
            category=category, language='en',
            org_slug='default', is_active=True
        ).first()

    def render(self, context):
        """
        Render template with context and branding variables.

        @covers AC-026
        """
        from django.template import Template as DjangoTemplate, Context

        # Merge tenant branding into context
        branding = self.get_branding(context.get('org_slug', 'default'))
        full_context = {**branding, **context}

        subject = DjangoTemplate(self.subject).render(Context(full_context))
        body_html = DjangoTemplate(self.body_html).render(Context(full_context))
        body_text = DjangoTemplate(self.body_text).render(Context(full_context))

        return {
            'subject': subject,
            'body_html': body_html,
            'body_text': body_text,
        }

    def get_branding(self, org_slug='default'):
        """
        Get branding variables for a tenant.

        Merges TenantConfig branding with template-level overrides.

        @covers AC-026
        """
        branding = {
            'org_display_name': 'Mereka Academy',
            'org_logo_url': '',
            'org_primary_color': '#ab3b78',
            'org_accent_color': '#237072',
            'org_support_email': 'support@mereka.io',
            'org_terms_url': '',
            'org_privacy_url': '',
        }

        # Try TenantConfig lookup
        try:
            from openedx_email_preferences.models import TenantConfig
            tenant = TenantConfig.objects.filter(org_slug=org_slug).first()
            if tenant:
                for key in branding:
                    val = getattr(tenant, key, None)
                    if val:
                        branding[key] = val
        except (ImportError, Exception):
            pass  # TenantConfig not available

        # Override with template-level branding
        if self.tenant_branding:
            for key, val in self.tenant_branding.items():
                if key in branding and val:
                    branding[key] = val

        return branding


class Campaign(models.Model):
    """
    Bulk email campaign.

    Supports scheduling, pause/resume, and per-tenant rate limiting.

    @covers AC-027, AC-028, AC-029, AC-030
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    name = models.CharField(
        max_length=255,
        help_text="Campaign name (for admin reference)"
    )

    template = models.ForeignKey(
        Template,
        on_delete=models.PROTECT,
        related_name='campaigns',
        help_text="Email template to use"
    )

    segment = models.JSONField(
        default=dict,
        blank=True,
        help_text=(
            "Recipient segment filter: {course_id, org_slug, role, "
            "enrollment_status, last_active_days}"
        )
    )

    status = models.CharField(
        max_length=20,
        choices=CAMPAIGN_STATUS_CHOICES,
        default='draft',
        db_index=True,
        help_text="Campaign lifecycle status"
    )

    org_slug = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Organization slug for multi-tenancy"
    )

    scheduled_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When to start sending (null = send immediately on trigger)"
    )

    started_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When sending actually began"
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When sending completed"
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='campaigns_created',
        help_text="User who created the campaign"
    )

    total_recipients = models.PositiveIntegerField(default=0)
    sent_count = models.PositiveIntegerField(default=0)
    failed_count = models.PositiveIntegerField(default=0)
    skipped_count = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'openedx_email_templates_campaign'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'scheduled_at']),
            models.Index(fields=['org_slug', 'status']),
        ]
        verbose_name = 'Campaign'
        verbose_name_plural = 'Campaigns'

    def __str__(self):
        return f"{self.name} ({self.status})"

    def schedule(self, scheduled_at):
        """
        Schedule campaign for future sending.

        @covers AC-028
        """
        self.scheduled_at = scheduled_at
        self.status = 'scheduled'
        self.save(update_fields=['scheduled_at', 'status', 'updated_at'])

    def pause(self):
        """
        Pause a sending campaign.

        @covers AC-029
        """
        if self.status == 'sending':
            self.status = 'paused'
            self.save(update_fields=['status', 'updated_at'])

    def resume(self):
        """
        Resume a paused campaign.

        @covers AC-029
        """
        if self.status == 'paused':
            self.status = 'sending'
            self.save(update_fields=['status', 'updated_at'])

    def cancel(self):
        """
        Cancel a campaign (draft, scheduled, or paused).

        @covers AC-030
        """
        if self.status in ('draft', 'scheduled', 'paused'):
            self.status = 'cancelled'
            self.save(update_fields=['status', 'updated_at'])

    def mark_sending(self):
        """Begin sending the campaign."""
        self.status = 'sending'
        self.started_at = timezone.now()
        self.save(update_fields=['status', 'started_at', 'updated_at'])

    def mark_completed(self):
        """Mark campaign as completed."""
        self.status = 'completed'
        self.completed_at = timezone.now()
        self.save(update_fields=['status', 'completed_at', 'updated_at'])

    def mark_failed(self):
        """Mark campaign as failed."""
        self.status = 'failed'
        self.save(update_fields=['status', 'updated_at'])


class CampaignRecipient(models.Model):
    """
    Tracks per-recipient delivery status within a campaign.

    @covers AC-031, AC-032
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='recipients',
        help_text="Parent campaign"
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='campaign_emails',
        help_text="Recipient user"
    )

    status = models.CharField(
        max_length=20,
        choices=RECIPIENT_STATUS_CHOICES,
        default='pending',
        db_index=True,
        help_text="Delivery status for this recipient"
    )

    error_message = models.TextField(
        blank=True,
        default='',
        help_text="Error details if delivery failed"
    )

    sent_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When email was dispatched"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'openedx_email_templates_campaignrecipient'
        unique_together = [('campaign', 'user')]
        indexes = [
            models.Index(fields=['campaign', 'status']),
        ]
        verbose_name = 'Campaign Recipient'
        verbose_name_plural = 'Campaign Recipients'

    def __str__(self):
        return f"{self.campaign.name} -> {self.user.username} ({self.status})"

    def mark_sent(self):
        """Mark as sent."""
        self.status = 'sent'
        self.sent_at = timezone.now()
        self.save(update_fields=['status', 'sent_at'])

    def mark_failed(self, error):
        """Mark as failed with error."""
        self.status = 'failed'
        self.error_message = str(error)[:1000]
        self.save(update_fields=['status', 'error_message'])

    def mark_skipped(self, reason):
        """Mark as skipped (e.g., unsubscribed, preference opt-out)."""
        self.status = 'skipped'
        self.error_message = str(reason)[:1000]
        self.save(update_fields=['status', 'error_message'])
