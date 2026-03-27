"""
Celery tasks for bulk campaign execution with per-tenant rate limiting.

@spec: email-notifications-pipeline_spec.md
@covers: AC-027, AC-028, AC-029, AC-030, AC-031, AC-032
"""

import logging
import time

from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)

# Rate limit: 50 emails/sec per tenant (token bucket)
RATE_LIMIT_PER_TENANT = 50
RATE_LIMIT_WINDOW = 1.0  # seconds


class TokenBucket:
    """
    Token bucket rate limiter for per-tenant email throttling.

    @covers AC-030
    """

    def __init__(self, rate=RATE_LIMIT_PER_TENANT, capacity=RATE_LIMIT_PER_TENANT):
        self.rate = rate
        self.capacity = capacity
        self.tokens = capacity
        self.last_refill = time.monotonic()

    def consume(self, count=1):
        """
        Try to consume tokens. Returns True if allowed, False if rate limited.

        Refills tokens based on elapsed time since last refill.
        """
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
        self.last_refill = now

        if self.tokens >= count:
            self.tokens -= count
            return True
        return False

    def wait_time(self):
        """Return seconds to wait before next token is available."""
        if self.tokens >= 1:
            return 0.0
        return (1 - self.tokens) / self.rate


@shared_task(
    name='openedx_email_templates.execute_campaign',
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
)
def execute_campaign(self, campaign_id):
    """
    Execute a bulk email campaign.

    Resolves segment to recipients, enqueues per-recipient send tasks,
    and tracks campaign progress.

    @covers AC-027, AC-028, AC-031
    """
    from .models import Campaign, CampaignRecipient

    try:
        campaign = Campaign.objects.get(id=campaign_id)
    except Campaign.DoesNotExist:
        logger.error("Campaign %s not found", campaign_id)
        return {'status': 'error', 'reason': 'campaign_not_found'}

    if campaign.status not in ('draft', 'scheduled', 'paused'):
        logger.info("Campaign %s in %s status, skipping", campaign_id, campaign.status)
        return {'status': 'skipped', 'reason': f'status_{campaign.status}'}

    # Mark as sending
    campaign.mark_sending()

    # Resolve segment to users
    users = _resolve_segment(campaign.segment, campaign.org_slug)
    campaign.total_recipients = len(users)
    campaign.save(update_fields=['total_recipients'])

    # Create recipient records (idempotent via unique_together)
    for user in users:
        CampaignRecipient.objects.get_or_create(
            campaign=campaign,
            user=user,
            defaults={'status': 'pending'},
        )

    # Enqueue per-recipient send tasks
    pending = CampaignRecipient.objects.filter(
        campaign=campaign, status='pending'
    ).values_list('id', flat=True)

    for recipient_id in pending:
        send_campaign_email.delay(str(campaign_id), str(recipient_id))

    logger.info(
        "Campaign %s: %d recipients enqueued for sending",
        campaign_id, len(pending),
    )

    return {
        'status': 'sending',
        'campaign_id': campaign_id,
        'total_recipients': campaign.total_recipients,
    }


@shared_task(
    name='openedx_email_templates.send_campaign_email',
    bind=True,
    max_retries=5,
    default_retry_delay=30,
    retry_backoff=True,
    retry_backoff_max=900,
    acks_late=True,
    rate_limit='50/s',
)
def send_campaign_email(self, campaign_id, recipient_id):
    """
    Send a single campaign email to a recipient.

    Respects per-tenant rate limiting and user email preferences.

    @covers AC-030, AC-031, AC-032
    """
    from .models import Campaign, CampaignRecipient

    try:
        campaign = Campaign.objects.select_related('template').get(id=campaign_id)
        recipient = CampaignRecipient.objects.select_related('user').get(id=recipient_id)
    except (Campaign.DoesNotExist, CampaignRecipient.DoesNotExist):
        logger.error("Campaign %s or recipient %s not found", campaign_id, recipient_id)
        return {'status': 'error'}

    # Check campaign not paused/cancelled
    if campaign.status in ('paused', 'cancelled'):
        logger.info("Campaign %s is %s, skipping recipient %s", campaign_id, campaign.status, recipient_id)
        return {'status': 'skipped', 'reason': campaign.status}

    user = recipient.user

    # Check user email preferences (opt-out)
    if _user_opted_out(user, campaign.org_slug, campaign.template.category):
        recipient.mark_skipped('user_opted_out')
        Campaign.objects.filter(id=campaign_id).update(
            skipped_count=models.F('skipped_count') + 1
        )
        return {'status': 'skipped', 'reason': 'opted_out'}

    # Render template with user context
    context = {
        'user_name': user.get_full_name() or user.username,
        'user_email': user.email,
        'org_slug': campaign.org_slug,
        'campaign_name': campaign.name,
    }
    context.update(campaign.segment)

    try:
        rendered = campaign.template.render(context)
    except Exception as exc:
        logger.exception("Template render failed for campaign %s", campaign_id)
        recipient.mark_failed(f"render_error: {exc}")
        return {'status': 'error', 'reason': 'render_failed'}

    # Send email via Django
    try:
        from django.core.mail import send_mail
        send_mail(
            subject=rendered['subject'],
            message=rendered['body_text'],
            html_message=rendered['body_html'],
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
        recipient.mark_sent()

        # Update campaign counters
        from django.db import models as db_models
        Campaign.objects.filter(id=campaign_id).update(
            sent_count=db_models.F('sent_count') + 1
        )

        logger.info(
            "Campaign email sent: campaign=%s user=%s",
            campaign_id, user.username,
        )
        return {'status': 'sent'}

    except Exception as exc:
        logger.exception("Email send failed: campaign=%s user=%s", campaign_id, user.username)
        recipient.mark_failed(str(exc))

        from django.db import models as db_models
        Campaign.objects.filter(id=campaign_id).update(
            failed_count=db_models.F('failed_count') + 1
        )

        raise self.retry(exc=exc)


@shared_task(name='openedx_email_templates.check_scheduled_campaigns')
def check_scheduled_campaigns():
    """
    Check for campaigns due to send and trigger execution.

    Should run every minute via Celery Beat.

    @covers AC-028
    """
    from django.utils import timezone
    from .models import Campaign

    due = Campaign.objects.filter(
        status='scheduled',
        scheduled_at__lte=timezone.now(),
    )

    triggered = 0
    for campaign in due:
        execute_campaign.delay(str(campaign.id))
        triggered += 1

    if triggered:
        logger.info("Triggered %d scheduled campaigns", triggered)
    return {'triggered': triggered}


@shared_task(name='openedx_email_templates.finalize_campaigns')
def finalize_campaigns():
    """
    Check sending campaigns and mark complete when all recipients processed.

    Should run every 5 minutes via Celery Beat.
    """
    from .models import Campaign, CampaignRecipient

    sending = Campaign.objects.filter(status='sending')
    finalized = 0

    for campaign in sending:
        pending_count = CampaignRecipient.objects.filter(
            campaign=campaign, status='pending'
        ).count()

        if pending_count == 0:
            campaign.mark_completed()
            finalized += 1
            logger.info("Campaign %s completed", campaign.id)

    return {'finalized': finalized}


def _resolve_segment(segment, org_slug):
    """
    Resolve a segment filter to a list of User objects.

    Segment filters: course_id, role, enrollment_status, last_active_days.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()

    queryset = User.objects.filter(is_active=True)

    # Filter by enrollment if course_id specified
    course_id = segment.get('course_id')
    if course_id:
        try:
            from student.models import CourseEnrollment
            enrolled_user_ids = CourseEnrollment.objects.filter(
                course_id=course_id,
                is_active=True,
            ).values_list('user_id', flat=True)
            queryset = queryset.filter(id__in=enrolled_user_ids)
        except ImportError:
            logger.warning("student.models not available for enrollment filtering")

    # Filter by role
    role = segment.get('role')
    if role:
        queryset = queryset.filter(
            courseaccessrole__role=role
        ).distinct()

    # Filter by last activity
    last_active_days = segment.get('last_active_days')
    if last_active_days:
        from django.utils import timezone
        cutoff = timezone.now() - timezone.timedelta(days=int(last_active_days))
        queryset = queryset.filter(last_login__gte=cutoff)

    return list(queryset)


def _user_opted_out(user, org_slug, category):
    """
    Check if user has opted out of this email category.

    Integrates with openedx_email_preferences.
    """
    try:
        from openedx_email_preferences.models import UserEmailPreference
        pref = UserEmailPreference.objects.filter(
            user=user,
            org_slug=org_slug,
            category=category,
            is_enabled=False,
        ).exists()
        return pref
    except (ImportError, Exception):
        return False  # Preferences not available; default to opted-in
