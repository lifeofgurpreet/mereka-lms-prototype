"""
Utilities for email preferences, including HMAC-signed unsubscribe URLs.

@spec: email-notifications-pipeline_spec.md
@bead: mereka-lms-bnw1
@covers: AC-022, AC-024
"""

import hmac
import hashlib
import base64
from django.conf import settings
from django.contrib.auth import get_user_model
from django.urls import reverse

User = get_user_model()


def get_unsubscribe_secret():
    """
    Get the server secret for HMAC signing.

    In production, this should be a stable secret from settings.
    """
    return getattr(settings, 'EMAIL_UNSUBSCRIBE_SECRET_KEY', settings.SECRET_KEY)


def generate_unsubscribe_token(user_id, category):
    """
    Generate HMAC-SHA256 token for one-click unsubscribe.

    Token format: base64(user_id|category|hmac)

    The token does NOT expire (permanent opt-out per GDPR).

    @covers AC-022
    """
    secret = get_unsubscribe_secret()
    message = f"{user_id}|{category}"

    # Generate HMAC-SHA256
    signature = hmac.new(
        secret.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    # Combine message and signature
    token_data = f"{message}|{signature}"

    # Base64 encode for URL safety
    token = base64.urlsafe_b64encode(token_data.encode('utf-8')).decode('utf-8')

    return token


def verify_unsubscribe_token(token):
    """
    Verify HMAC-signed unsubscribe token.

    Returns: (user_id, category) if valid, (None, None) if invalid

    @covers AC-022
    """
    try:
        # Base64 decode
        token_data = base64.urlsafe_b64decode(token.encode('utf-8')).decode('utf-8')

        # Split into parts
        parts = token_data.split('|')
        if len(parts) != 3:
            return None, None

        user_id_str, category, provided_signature = parts

        # Reconstruct message
        message = f"{user_id_str}|{category}"

        # Generate expected signature
        secret = get_unsubscribe_secret()
        expected_signature = hmac.new(
            secret.encode('utf-8'),
            message.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        # Constant-time comparison
        if not hmac.compare_digest(provided_signature, expected_signature):
            return None, None

        # Parse user_id
        try:
            user_id = int(user_id_str)
        except ValueError:
            return None, None

        return user_id, category

    except Exception:
        return None, None


def generate_unsubscribe_url(user, category, base_url=None):
    """
    Generate full one-click unsubscribe URL.

    @covers AC-022, AC-024
    """
    token = generate_unsubscribe_token(user.id, category)

    # Build URL
    path = reverse('openedx_email_preferences:one-click-unsubscribe', kwargs={'token': token})

    if base_url:
        return f"{base_url.rstrip('/')}{path}"

    # Use settings.LMS_ROOT_URL if available
    lms_root = getattr(settings, 'LMS_ROOT_URL', 'https://academyv2.mereka.io')
    return f"{lms_root}{path}"


def get_list_unsubscribe_headers(user, category):
    """
    Generate RFC 8058 List-Unsubscribe headers for email.

    Returns: dict with 'List-Unsubscribe' and 'List-Unsubscribe-Post' headers

    @covers AC-024
    """
    unsubscribe_url = generate_unsubscribe_url(user, category)

    return {
        'List-Unsubscribe': f'<{unsubscribe_url}>',
        'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    }


def check_user_can_receive_email(user, category):
    """
    Check if user has opted in to receive emails for a category.

    Used by ACE dispatch to filter emails based on preferences.

    @covers AC-021
    """
    from .models import UserEmailPreference

    # System-critical emails always send (password_reset, account_activation)
    SYSTEM_CRITICAL = ['transactional', 'account_activation', 'password_reset']
    if category in SYSTEM_CRITICAL:
        return True

    # Get user preferences
    preferences = UserEmailPreference.get_user_preferences(user)

    # Default to True for backward compatibility
    return preferences.get(category, True)
