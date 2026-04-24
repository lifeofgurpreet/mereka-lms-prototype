"""Utilities for Mux signed playback URLs"""
import hashlib
import logging
import time
from typing import Optional

import jwt
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


def generate_signed_playback_url(
    playback_id: str,
    user_id: Optional[int] = None,
    expiry_hours: int = 12,
    audience: Optional[str] = None,
) -> dict:
    """
    Generate a Mux signed playback URL using JWT with RSA signing.

    Mux signed URLs use JWT tokens signed with RSA-2048 private keys.
    The token includes:
    - sub (subject): playback_id
    - kid (key ID): Mux signing key ID
    - exp (expiry): Unix timestamp
    - aud (audience): Domain restriction (optional)
    - custom claims: user_id for audit

    Args:
        playback_id: Mux playback ID (e.g., "abcd1234efgh5678")
        user_id: User ID for audit trail (optional)
        expiry_hours: Token validity in hours (default: 12h)
        audience: Domain restriction (e.g., "academyv2.mereka.io")

    Returns:
        dict with:
            - url: Full signed playback URL
            - token: JWT token
            - expires_at: Expiry timestamp (ISO 8601)

    Raises:
        ValueError: If MUX_SIGNING_KEY_ID or MUX_SIGNING_PRIVATE_KEY not configured
    """
    # Get Mux signing credentials from settings
    signing_key_id = getattr(settings, 'MUX_SIGNING_KEY_ID', None)
    signing_private_key = getattr(settings, 'MUX_SIGNING_PRIVATE_KEY', None)

    if not signing_key_id or not signing_private_key:
        raise ValueError(
            'MUX_SIGNING_KEY_ID and MUX_SIGNING_PRIVATE_KEY must be configured '
            'to generate signed playback URLs. Check LMS settings and ExternalSecrets.'
        )

    # Calculate expiry timestamp
    expiry_timestamp = int(time.time()) + (expiry_hours * 3600)
    expires_at = timezone.now() + timezone.timedelta(hours=expiry_hours)

    # Build JWT payload
    payload = {
        'sub': playback_id,  # Subject: playback ID
        'kid': signing_key_id,  # Key ID registered with Mux
        'exp': expiry_timestamp,  # Expiry timestamp
        'aud': audience or 'v',  # Audience: domain or 'v' (video)
    }

    # Add user_id as custom claim for audit trail
    if user_id:
        payload['user_id'] = user_id

    # Sign the JWT with RSA private key
    try:
        token = jwt.encode(payload, signing_private_key, algorithm='RS256')
    except Exception as e:
        logger.error(f'Failed to sign JWT for playback_id={playback_id}: {e}')
        raise ValueError(f'Failed to generate signed token: {e}')

    # Build signed playback URL
    # Format: https://stream.mux.com/{playback_id}.m3u8?token={jwt}
    base_url = f'https://stream.mux.com/{playback_id}.m3u8'
    signed_url = f'{base_url}?token={token}'

    return {
        'url': signed_url,
        'token': token,
        'expires_at': expires_at.isoformat(),
        'playback_id': playback_id,
    }


def verify_mux_signed_token(token: str) -> dict:
    """
    Verify a Mux signed JWT token (for testing/debugging).

    This is NOT used for playback validation (Mux handles that).
    Used for debugging and testing token generation.

    Args:
        token: JWT token string

    Returns:
        dict with decoded payload

    Raises:
        jwt.InvalidTokenError: If token is invalid or expired
    """
    signing_key_id = getattr(settings, 'MUX_SIGNING_KEY_ID', None)
    signing_private_key = getattr(settings, 'MUX_SIGNING_PRIVATE_KEY', None)

    if not signing_key_id or not signing_private_key:
        raise ValueError('Signing credentials not configured')

    try:
        # Decode without verification (we don't have public key here)
        # In production, Mux verifies with the public key we registered
        payload = jwt.decode(token, options={'verify_signature': False})
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning(f'Token expired: {token[:20]}...')
        raise
    except jwt.InvalidTokenError as e:
        logger.error(f'Invalid token: {e}')
        raise


def hash_ip_address(ip_address: str) -> str:
    """
    Hash IP address for privacy (SHA-256, truncated to 16 chars).

    Args:
        ip_address: Client IP address

    Returns:
        Truncated SHA-256 hash (16 chars)
    """
    if not ip_address:
        return ''

    hash_obj = hashlib.sha256(ip_address.encode('utf-8'))
    return hash_obj.hexdigest()[:16]


def get_client_ip(request) -> str:
    """
    Extract client IP address from request, respecting X-Forwarded-For.

    Args:
        request: Django request object

    Returns:
        Client IP address
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        # Take first IP (client) from X-Forwarded-For chain
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR', '')

    return ip


def extract_org_slug_from_course_key(course_key) -> str:
    """
    Extract organization slug from course key.

    Args:
        course_key: CourseKey instance

    Returns:
        Organization slug (e.g., "MerekaAcademy")
    """
    try:
        return course_key.org
    except AttributeError:
        return ''


def is_rate_limited(user, max_requests: int = 100, window_hours: int = 1) -> bool:
    """
    Check if user has exceeded rate limit for signed URL requests.

    Args:
        user: User instance
        max_requests: Maximum requests allowed in window
        window_hours: Time window in hours

    Returns:
        True if rate limited, False otherwise
    """
    from .models import SignedPlaybackToken

    recent_count = SignedPlaybackToken.count_recent_tokens_for_user(user, window_hours)
    is_limited = recent_count >= max_requests

    if is_limited:
        logger.warning(
            f'Rate limit exceeded for user {user.username}: '
            f'{recent_count} requests in {window_hours}h (max: {max_requests})'
        )

    return is_limited
