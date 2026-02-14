"""
Celery tasks for digest generation and analytics data management.

@spec: email-notifications-pipeline_spec.md
@covers: AC-037, AC-038, AC-039, AC-040, AC-041, AC-042
"""

import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


@shared_task(
    name='openedx_email_digests.generate_daily_digest',
    bind=True,
    max_retries=3,
    default_retry_delay=300,
    acks_late=True,
)
def generate_daily_digest(self):
    """
    Generate and send daily digest emails.

    Runs daily. Finds all users with daily digest preference,
    aggregates their notifications from the past 24 hours,
    groups by course, deduplicates, and sends a single digest email.

    Should be triggered by Celery Beat at a time that allows
    timezone-aware delivery (e.g., run every hour, check user timezone).

    @covers AC-037, AC-038, AC-039
    """
    from .models import DigestPreference, DigestRun

    now = timezone.now()
    period_end = now
    period_start = now - timedelta(hours=24)
    run_id = f"daily-{now.strftime('%Y-%m-%dT%H')}"

    # Idempotency: skip if this run already exists
    if DigestRun.objects.filter(run_id=run_id).exists():
        logger.info("Daily digest run %s already exists, skipping", run_id)
        return {'status': 'duplicate', 'run_id': run_id}

    run = DigestRun.objects.create(
        run_id=run_id,
        frequency='daily',
        period_start=period_start,
        period_end=period_end,
    )
    run.mark_running()

    try:
        preferences = DigestPreference.get_users_for_digest('daily')
        run.total_users = preferences.count()
        run.save(update_fields=['total_users'])

        sent = 0
        skipped = 0
        failed = 0

        for pref in preferences:
            # Check if it's the right time for this user's timezone
            if not _is_digest_time_for_user(pref, 'daily'):
                continue

            try:
                result = _build_and_send_digest(
                    pref.user, pref.org_slug, period_start, period_end,
                    pref.message_types, 'daily'
                )
                if result == 'sent':
                    sent += 1
                elif result == 'empty':
                    skipped += 1
                else:
                    failed += 1
            except Exception:
                logger.exception(
                    "Failed to send daily digest to user %s", pref.user.username
                )
                failed += 1

        run.emails_sent = sent
        run.emails_skipped = skipped
        run.emails_failed = failed
        run.mark_completed()

        logger.info(
            "Daily digest run %s: sent=%d skipped=%d failed=%d",
            run_id, sent, skipped, failed,
        )
        return {
            'status': 'completed',
            'run_id': run_id,
            'sent': sent,
            'skipped': skipped,
            'failed': failed,
        }

    except Exception as exc:
        run.mark_failed(str(exc))
        logger.exception("Daily digest run %s failed", run_id)
        raise self.retry(exc=exc)


@shared_task(
    name='openedx_email_digests.generate_weekly_digest',
    bind=True,
    max_retries=3,
    default_retry_delay=300,
    acks_late=True,
)
def generate_weekly_digest(self):
    """
    Generate and send weekly digest emails.

    Runs weekly (Monday). Finds all users with weekly digest preference,
    aggregates their notifications from the past 7 days.

    @covers AC-037, AC-039
    """
    from .models import DigestPreference, DigestRun

    now = timezone.now()
    period_end = now
    period_start = now - timedelta(days=7)
    run_id = f"weekly-{now.strftime('%Y-W%V')}"

    if DigestRun.objects.filter(run_id=run_id).exists():
        logger.info("Weekly digest run %s already exists, skipping", run_id)
        return {'status': 'duplicate', 'run_id': run_id}

    run = DigestRun.objects.create(
        run_id=run_id,
        frequency='weekly',
        period_start=period_start,
        period_end=period_end,
    )
    run.mark_running()

    try:
        preferences = DigestPreference.get_users_for_digest('weekly')
        run.total_users = preferences.count()
        run.save(update_fields=['total_users'])

        sent = 0
        skipped = 0
        failed = 0

        for pref in preferences:
            if not _is_digest_time_for_user(pref, 'weekly'):
                continue

            try:
                result = _build_and_send_digest(
                    pref.user, pref.org_slug, period_start, period_end,
                    pref.message_types, 'weekly'
                )
                if result == 'sent':
                    sent += 1
                elif result == 'empty':
                    skipped += 1
                else:
                    failed += 1
            except Exception:
                logger.exception(
                    "Failed to send weekly digest to user %s", pref.user.username
                )
                failed += 1

        run.emails_sent = sent
        run.emails_skipped = skipped
        run.emails_failed = failed
        run.mark_completed()

        logger.info(
            "Weekly digest run %s: sent=%d skipped=%d failed=%d",
            run_id, sent, skipped, failed,
        )
        return {
            'status': 'completed',
            'run_id': run_id,
            'sent': sent,
            'skipped': skipped,
            'failed': failed,
        }

    except Exception as exc:
        run.mark_failed(str(exc))
        logger.exception("Weekly digest run %s failed", run_id)
        raise self.retry(exc=exc)


@shared_task(name='openedx_email_digests.purge_old_events')
def purge_old_events(retention_months=12):
    """
    Purge email engagement data older than retention period.

    Spec: 12-month retention policy. Should run daily via Celery Beat.
    """
    from .models import EmailEvent

    deleted = EmailEvent.purge_old_events(retention_months=retention_months)
    logger.info("Purged %d email events older than %d months", deleted, retention_months)
    return {'deleted': deleted, 'retention_months': retention_months}


@shared_task(name='openedx_email_digests.gdpr_delete_user_data')
def gdpr_delete_user_data(user_id):
    """
    Delete all engagement data for a user (GDPR deletion).

    Must complete within 30 days of request (spec requirement).
    """
    from .models import DigestPreference, EmailEvent

    events_deleted, _ = EmailEvent.objects.filter(user_id=user_id).delete()
    prefs_deleted, _ = DigestPreference.objects.filter(user_id=user_id).delete()

    logger.info(
        "GDPR deletion for user %s: %d events, %d preferences deleted",
        user_id, events_deleted, prefs_deleted,
    )
    return {
        'user_id': user_id,
        'events_deleted': events_deleted,
        'preferences_deleted': prefs_deleted,
    }


def _is_digest_time_for_user(pref, frequency):
    """
    Check if it's the right time to send a digest for this user.

    Daily digests: 09:00 in user's timezone.
    Weekly digests: Monday 09:00 in user's timezone.

    If timezone is not set, defaults to Asia/Kuala_Lumpur (spec requirement).

    @covers AC-037
    """
    try:
        import pytz
        user_tz = pytz.timezone(pref.user_timezone or 'Asia/Kuala_Lumpur')
    except Exception:
        import pytz
        user_tz = pytz.timezone('Asia/Kuala_Lumpur')

    user_now = timezone.now().astimezone(user_tz)

    # Check if we're within the 09:00 window (08:30-09:30)
    if user_now.hour != 9:
        # Allow a 1-hour window centered on 09:00
        if not (user_now.hour == 8 and user_now.minute >= 30):
            return False

    # For weekly, check if it's Monday
    if frequency == 'weekly' and user_now.weekday() != 0:
        return False

    return True


def _build_and_send_digest(user, org_slug, period_start, period_end,
                           message_types, frequency):
    """
    Build and send a digest email for a user.

    Aggregates notifications from the period, groups by course,
    deduplicates repeated notifications (e.g., 5 replies → "5 new replies").

    Returns 'sent', 'empty', or 'failed'.

    @covers AC-037, AC-039
    """
    # Get notifications for this period
    try:
        from openedx_notifications.models import Notification
        queryset = Notification.objects.filter(
            user=user,
            org_slug=org_slug,
            created_at__gte=period_start,
            created_at__lt=period_end,
        )

        if message_types:
            queryset = queryset.filter(message_type__in=message_types)

        notifications = list(queryset.order_by('created_at'))
    except (ImportError, Exception):
        logger.warning("Cannot fetch notifications for digest (openedx_notifications unavailable)")
        return 'empty'

    if not notifications:
        return 'empty'

    # Group by course (AC-039)
    grouped = {}
    for notif in notifications:
        course_key = notif.course_id or 'general'
        if course_key not in grouped:
            grouped[course_key] = []
        grouped[course_key].append(notif)

    # Deduplicate within groups (AC-039)
    # e.g., 5 discussion_reply for same thread → "5 new replies"
    digest_items = []
    for course_id, notifs in grouped.items():
        # Group by message_type within course
        type_groups = {}
        for n in notifs:
            key = n.message_type
            if key not in type_groups:
                type_groups[key] = []
            type_groups[key].append(n)

        for msg_type, items in type_groups.items():
            if len(items) > 1:
                digest_items.append({
                    'course_id': course_id,
                    'message_type': msg_type,
                    'title': items[0].title,
                    'count': len(items),
                    'summary': f"({len(items)} new)",
                    'deep_link_url': items[-1].deep_link_url or '',
                })
            else:
                digest_items.append({
                    'course_id': course_id,
                    'message_type': msg_type,
                    'title': items[0].title,
                    'count': 1,
                    'summary': items[0].body[:200],
                    'deep_link_url': items[0].deep_link_url or '',
                })

    # Render and send digest email
    try:
        from django.core.mail import send_mail
        from django.template.loader import render_to_string

        context = {
            'user_name': user.get_full_name() or user.username,
            'frequency': frequency,
            'digest_items': digest_items,
            'total_notifications': len(notifications),
            'org_slug': org_slug,
            'org_display_name': getattr(settings, 'DEFAULT_ORG_DISPLAY_NAME', 'Mereka Academy'),
            'org_logo_url': getattr(settings, 'DEFAULT_ORG_LOGO_URL', ''),
            'org_primary_color': getattr(settings, 'DEFAULT_ORG_PRIMARY_COLOR', '#1a73e8'),
        }

        # Try to render from template, fall back to plain text
        try:
            html_body = render_to_string('email/digest.html', context)
        except Exception:
            html_body = _build_plain_digest_html(context)

        text_body = _build_digest_text(context)

        subject = f"Your {frequency} digest — {len(notifications)} notification(s)"

        send_mail(
            subject=subject,
            message=text_body,
            html_message=html_body,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )

        return 'sent'

    except Exception:
        logger.exception("Failed to send digest email to %s", user.username)
        return 'failed'


def _build_plain_digest_html(context):
    """Build a simple HTML digest when template is unavailable."""
    items_html = ''
    for item in context['digest_items']:
        count_badge = f' <span style="color:#666;">({item["count"]} new)</span>' if item['count'] > 1 else ''
        items_html += f'<li style="margin:8px 0;"><strong>{item["title"]}</strong>{count_badge}</li>\n'

    return f"""
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
      <h1 style="color:{context.get('org_primary_color','#1a73e8')};">
        Your {context['frequency']} digest
      </h1>
      <p>Hi {context['user_name']},</p>
      <p>You have {context['total_notifications']} notification(s) since your last digest:</p>
      <ul>{items_html}</ul>
      <hr style="border:none;border-top:1px solid #eee;margin:30px 0;">
      <p style="font-size:12px;color:#666;">{context.get('org_display_name','')}</p>
    </div>
    """


def _build_digest_text(context):
    """Build plain text digest."""
    lines = [
        f"Your {context['frequency']} digest",
        f"Hi {context['user_name']},",
        f"You have {context['total_notifications']} notification(s):",
        "",
    ]
    for item in context['digest_items']:
        count = f" ({item['count']} new)" if item['count'] > 1 else ''
        lines.append(f"- {item['title']}{count}")

    lines.extend(["", "---", context.get('org_display_name', '')])
    return '\n'.join(lines)
