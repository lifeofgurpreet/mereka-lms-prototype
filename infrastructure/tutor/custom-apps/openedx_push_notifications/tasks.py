"""
Celery tasks for push notification dispatch via FCM HTTP v1 API.

@spec: email-notifications-pipeline_spec.md
@covers: AC-015, AC-016, AC-018, AC-019
"""

import hashlib
import json
import logging
import time

from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)

# Batch size per FCM API call (spec: up to 500)
FCM_BATCH_SIZE = 500


def _get_fcm_access_token():
    """
    Get an OAuth2 access token for FCM HTTP v1 API using the service account key.

    Returns the access token string, or None if credentials are unavailable.
    """
    fcm_key_json = getattr(settings, 'FCM_SERVICE_ACCOUNT_KEY', '')
    if not fcm_key_json:
        logger.error("FCM_SERVICE_ACCOUNT_KEY not configured")
        return None

    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request

        credentials = service_account.Credentials.from_service_account_info(
            json.loads(fcm_key_json),
            scopes=['https://www.googleapis.com/auth/firebase.messaging'],
        )
        credentials.refresh(Request())
        return credentials.token
    except ImportError:
        logger.error("google-auth library not installed; cannot authenticate to FCM")
        return None
    except Exception:
        logger.exception("Failed to obtain FCM access token")
        return None


def _send_fcm_batch(tokens_and_payload, access_token, project_id):
    """
    Send a batch of push notifications to FCM HTTP v1 API.

    Args:
        tokens_and_payload: list of (device_token, platform, payload_dict)
        access_token: OAuth2 bearer token
        project_id: Firebase project ID

    Returns:
        list of (device_token, success_bool, error_code_or_none)

    @covers AC-018 (batch sending)
    """
    try:
        import requests as http_requests
    except ImportError:
        logger.error("requests library not installed")
        return [(t, False, 'MISSING_LIBRARY') for t, _, _ in tokens_and_payload]

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json',
    }

    results = []
    for device_token, platform, payload in tokens_and_payload:
        message = {
            'message': {
                'token': device_token,
                'notification': {
                    'title': payload.get('title', ''),
                    'body': payload.get('body', ''),
                },
                'data': {
                    'type': payload.get('type', ''),
                    'notification_id': payload.get('notification_id', ''),
                    'course_id': payload.get('course_id', ''),
                    'deep_link_url': payload.get('deep_link_url', ''),
                    'org_slug': payload.get('org_slug', ''),
                    'timestamp': payload.get('timestamp', ''),
                },
            }
        }

        # Platform-specific grouping
        if platform == 'ios':
            message['message']['apns'] = {
                'payload': {
                    'aps': {
                        'thread-id': payload.get('course_id', 'general'),
                    }
                }
            }
        elif platform == 'android':
            message['message']['android'] = {
                'notification': {
                    'channel_id': payload.get('course_id', 'general'),
                }
            }

        try:
            resp = http_requests.post(url, json=message, headers=headers, timeout=10)
            if resp.status_code == 200:
                results.append((device_token, True, None))
            else:
                error_code = ''
                try:
                    error_code = resp.json().get('error', {}).get('status', resp.status_code)
                except Exception:
                    error_code = str(resp.status_code)
                results.append((device_token, False, error_code))
        except Exception as exc:
            results.append((device_token, False, str(exc)))

    return results


@shared_task(
    name='openedx_push_notifications.send_push_notification',
    bind=True,
    max_retries=5,
    default_retry_delay=30,
    retry_backoff=True,
    retry_backoff_max=900,
    acks_late=True,
)
def send_push_notification(self, user_id, notification_data):
    """
    Send a push notification to all active devices for a user.

    Respects org_slug isolation (AC-019) and batch sending (AC-018).
    Deactivates tokens on UNREGISTERED errors (AC-016).
    Uses notification_id for idempotency.

    Args:
        user_id: LMS auth_user.id
        notification_data: dict with type, title, body, course_id,
                          deep_link_url, org_slug, notification_id, timestamp
    """
    from .models import DeviceRegistration

    org_slug = notification_data.get('org_slug', 'default')
    notification_id = notification_data.get('notification_id', '')

    # Idempotency check via Redis (24h TTL)
    cache_key = f"push:sent:{notification_id}:{user_id}"
    try:
        from django.core.cache import cache
        if cache.get(cache_key):
            logger.info("Skipping duplicate push %s for user %s", notification_id, user_id)
            return {'status': 'duplicate', 'notification_id': notification_id}
    except Exception:
        pass  # Cache unavailable: proceed without dedup

    # Get active device tokens for this user in the correct org (AC-019)
    tokens = list(DeviceRegistration.get_active_tokens([user_id], org_slug))
    if not tokens:
        logger.debug("No active devices for user %s in org %s", user_id, org_slug)
        return {'status': 'no_devices', 'user_id': user_id}

    # Get FCM credentials
    access_token = _get_fcm_access_token()
    if not access_token:
        logger.error("Cannot send push: no FCM access token")
        raise self.retry(exc=Exception("FCM access token unavailable"))

    project_id = getattr(settings, 'FCM_PROJECT_ID', '')
    if not project_id:
        logger.error("FCM_PROJECT_ID not configured")
        return {'status': 'error', 'reason': 'FCM_PROJECT_ID missing'}

    # Build batch payload
    batch = [(token, platform, notification_data) for token, platform, _ in tokens]

    # Send in batches of FCM_BATCH_SIZE (AC-018)
    all_results = []
    for i in range(0, len(batch), FCM_BATCH_SIZE):
        chunk = batch[i:i + FCM_BATCH_SIZE]
        results = _send_fcm_batch(chunk, access_token, project_id)
        all_results.extend(results)

    # Process results: deactivate UNREGISTERED tokens (AC-016)
    sent = 0
    failed = 0
    deactivated = 0
    for device_token, success, error_code in all_results:
        token_hash = hashlib.sha256(device_token.encode()).hexdigest()[:16]
        if success:
            sent += 1
            logger.info(
                "Push sent: notification_id=%s user=%s token_hash=%s",
                notification_id, user_id, token_hash,
            )
        else:
            failed += 1
            if error_code in ('UNREGISTERED', 'INVALID_ARGUMENT', 'NOT_FOUND'):
                DeviceRegistration.objects.filter(
                    device_token=device_token,
                ).update(is_active=False)
                deactivated += 1
                logger.warning(
                    "Device deactivated (FCM %s): token_hash=%s user=%s",
                    error_code, token_hash, user_id,
                )
            else:
                logger.error(
                    "Push failed: notification_id=%s user=%s token_hash=%s error=%s",
                    notification_id, user_id, token_hash, error_code,
                )

    # Mark as sent in cache for idempotency (24h TTL)
    try:
        from django.core.cache import cache
        cache.set(cache_key, True, timeout=86400)
    except Exception:
        pass

    return {
        'status': 'sent',
        'notification_id': notification_id,
        'user_id': user_id,
        'sent': sent,
        'failed': failed,
        'deactivated': deactivated,
    }


@shared_task(name='openedx_push_notifications.cleanup_inactive_devices')
def cleanup_inactive_devices(days_inactive=90):
    """
    Remove device registrations inactive for more than N days.

    This task should run daily via Celery Beat.
    """
    from django.utils import timezone
    from .models import DeviceRegistration

    cutoff = timezone.now() - timezone.timedelta(days=days_inactive)
    deleted_count, _ = DeviceRegistration.objects.filter(
        is_active=False,
        last_seen_at__lt=cutoff,
    ).delete()

    logger.info("Cleaned up %d inactive device registrations (>%d days)", deleted_count, days_inactive)
    return {'deleted': deleted_count}
