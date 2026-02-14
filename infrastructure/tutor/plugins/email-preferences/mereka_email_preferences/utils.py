# @covers AC-020, AC-022, AC-043
# @spec: email-notifications-pipeline_spec.md
"""
Utility functions for email preferences.

AC-020: Default preferences logic
AC-022: HMAC token generation/validation for one-click unsubscribe
AC-043: GDPR compliance (bulk_campaign disabled by default)
"""

import hashlib
import hmac
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional


# Default preferences: all enabled except bulk_campaign email (AC-043 GDPR)
DEFAULT_PREFERENCES = {
    'password_reset': {'email': True, 'push': False, 'in_app': False},
    'account_activation': {'email': True, 'push': False, 'in_app': False},
    'enrollment_confirmation': {'email': True, 'push': True, 'in_app': True},
    'course_announcement': {'email': True, 'push': True, 'in_app': True},
    'assignment_reminder': {'email': True, 'push': True, 'in_app': True},
    'grade_posted': {'email': True, 'push': True, 'in_app': True},
    'discussion_reply': {'email': True, 'push': True, 'in_app': True},
    'discussion_mention': {'email': True, 'push': True, 'in_app': True},
    'certificate_issued': {'email': True, 'push': True, 'in_app': True},
    'course_start_reminder': {'email': True, 'push': True, 'in_app': True},
    'course_completion': {'email': True, 'push': True, 'in_app': True},
    'license_expiry_warning': {'email': True, 'push': True, 'in_app': True},
    'enterprise_welcome': {'email': True, 'push': False, 'in_app': True},
    'bulk_campaign': {'email': False, 'push': False, 'in_app': False},  # GDPR - AC-043
    'forum_digest': {'email': True, 'push': False, 'in_app': False},
}

# System-critical types that cannot be disabled
SYSTEM_CRITICAL_TYPES = ['password_reset', 'account_activation']

# Token expiry: 90 days
TOKEN_EXPIRY_DAYS = 90


def get_hmac_secret() -> str:
    """
    Get HMAC secret from environment variable.

    Returns:
        str: HMAC secret key

    Raises:
        ValueError: If UNSUBSCRIBE_HMAC_SECRET not set
    """
    secret = os.environ.get('UNSUBSCRIBE_HMAC_SECRET')
    if not secret:
        raise ValueError("UNSUBSCRIBE_HMAC_SECRET environment variable not set")
    return secret


def generate_unsubscribe_token(user_id: int, email: str) -> str:
    """
    Generate HMAC-SHA256 token for one-click unsubscribe.

    AC-022: Signed token for unsubscribe without login

    Args:
        user_id: User ID
        email: User email address

    Returns:
        str: Base64-encoded token in format "user_id:email:timestamp:signature"
    """
    secret = get_hmac_secret()
    timestamp = int(datetime.utcnow().timestamp())

    # Create payload
    payload = f"{user_id}:{email}:{timestamp}"

    # Generate HMAC signature
    signature = hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    # Combine payload and signature
    token = f"{payload}:{signature}"

    # Base64 encode for URL safety
    import base64
    return base64.urlsafe_b64encode(token.encode('utf-8')).decode('utf-8')


def validate_unsubscribe_token(token: str) -> Optional[Dict[str, any]]:
    """
    Validate HMAC-SHA256 unsubscribe token.

    AC-022: Validate signed token, check 90-day expiry

    Args:
        token: Base64-encoded token from URL

    Returns:
        dict: {'user_id': int, 'email': str} if valid, None otherwise
    """
    try:
        import base64

        # Decode from base64
        decoded = base64.urlsafe_b64decode(token.encode('utf-8')).decode('utf-8')

        # Split into components
        parts = decoded.split(':')
        if len(parts) != 4:
            return None

        user_id_str, email, timestamp_str, signature = parts
        user_id = int(user_id_str)
        timestamp = int(timestamp_str)

        # Check expiry (90 days)
        token_age = datetime.utcnow() - datetime.fromtimestamp(timestamp)
        if token_age > timedelta(days=TOKEN_EXPIRY_DAYS):
            return None

        # Verify signature
        secret = get_hmac_secret()
        expected_payload = f"{user_id}:{email}:{timestamp}"
        expected_signature = hmac.new(
            secret.encode('utf-8'),
            expected_payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_signature):
            return None

        return {'user_id': user_id, 'email': email}

    except (ValueError, KeyError, TypeError):
        return None


def hash_ip_address(ip_address: str) -> str:
    """
    Hash IP address for privacy (SHA256).

    AC-023: IP address stored as hash

    Args:
        ip_address: IP address string

    Returns:
        str: SHA256 hex digest
    """
    return hashlib.sha256(ip_address.encode('utf-8')).hexdigest()


def get_default_preferences(user_id: int) -> List[Dict]:
    """
    Get default preferences for a user.

    AC-020: All enabled except bulk_campaign email
    AC-043: GDPR compliance

    Args:
        user_id: User ID

    Returns:
        list: List of preference dicts with message_type, channel, enabled
    """
    preferences = []
    for message_type, channels in DEFAULT_PREFERENCES.items():
        for channel, enabled in channels.items():
            preferences.append({
                'user_id': user_id,
                'message_type': message_type,
                'channel': channel,
                'enabled': enabled,
            })
    return preferences
