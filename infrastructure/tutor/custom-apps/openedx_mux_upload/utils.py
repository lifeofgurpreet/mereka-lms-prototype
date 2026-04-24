"""
Mux API Integration Utilities

Functions for interacting with Mux Video API.

@spec: video-pipeline-delivery_spec.md (Phase 3)
@covers: AC-VPD-003
"""

import os
import base64
import requests
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Mux API configuration
MUX_API_BASE_URL = 'https://api.mux.com'
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET')


def get_mux_auth_header() -> Dict[str, str]:
    """
    Generate HTTP Basic Auth header for Mux API.

    Returns:
        dict: Authorization header with Basic auth credentials

    Raises:
        ValueError: If MUX_TOKEN_ID or MUX_TOKEN_SECRET not configured
    """
    if not MUX_TOKEN_ID or not MUX_TOKEN_SECRET:
        raise ValueError(
            "MUX_TOKEN_ID and MUX_TOKEN_SECRET must be set in environment variables. "
            "Check Infisical secrets sync to K8s."
        )

    credentials = f"{MUX_TOKEN_ID}:{MUX_TOKEN_SECRET}"
    encoded = base64.b64encode(credentials.encode('utf-8')).decode('utf-8')

    return {
        'Authorization': f'Basic {encoded}',
        'Content-Type': 'application/json',
    }


def create_direct_upload(
    timeout: int = 172800,  # 48 hours default
    cors_origin: str = '*',
    new_asset_settings: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Create a Mux direct upload URL for browser-based video upload.

    API Endpoint: POST /video/v1/uploads

    Args:
        timeout (int): Upload URL expiry in seconds (default: 48 hours)
        cors_origin (str): CORS origin for browser upload (default: '*')
        new_asset_settings (dict, optional): Settings for the created asset
            (e.g., playback_policy, passthrough metadata)

    Returns:
        dict: Mux upload response containing:
            - id: Upload ID
            - url: Pre-signed upload URL for browser
            - timeout: URL expiry timestamp
            - status: Upload status
            - new_asset_settings: Asset creation settings

    Raises:
        requests.HTTPError: If Mux API request fails
        ValueError: If MUX credentials not configured

    Example:
        >>> upload_data = create_direct_upload(
        ...     new_asset_settings={'playback_policy': ['public']}
        ... )
        >>> upload_url = upload_data['url']
        >>> upload_id = upload_data['id']
    """
    headers = get_mux_auth_header()

    payload = {
        'timeout': timeout,
        'cors_origin': cors_origin,
    }

    if new_asset_settings:
        payload['new_asset_settings'] = new_asset_settings

    url = f'{MUX_API_BASE_URL}/video/v1/uploads'

    logger.info(f"Creating Mux direct upload: timeout={timeout}s, cors_origin={cors_origin}")

    response = requests.post(url, json=payload, headers=headers, timeout=10)
    response.raise_for_status()

    upload_data = response.json()['data']

    logger.info(
        f"Mux direct upload created: upload_id={upload_data['id']}, "
        f"url_length={len(upload_data['url'])}"
    )

    return upload_data


def get_upload_status(upload_id: str) -> Dict[str, Any]:
    """
    Get the status of a Mux direct upload.

    API Endpoint: GET /video/v1/uploads/{upload_id}

    Args:
        upload_id (str): Mux upload ID

    Returns:
        dict: Upload status data containing:
            - id: Upload ID
            - status: Upload status (waiting, asset_created, errored, cancelled, timed_out)
            - asset_id: Mux asset ID (if upload completed)
            - error: Error details (if errored)

    Raises:
        requests.HTTPError: If Mux API request fails
    """
    headers = get_mux_auth_header()
    url = f'{MUX_API_BASE_URL}/video/v1/uploads/{upload_id}'

    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()

    return response.json()['data']


def get_asset(asset_id: str) -> Dict[str, Any]:
    """
    Get details of a Mux asset.

    API Endpoint: GET /video/v1/assets/{asset_id}

    Args:
        asset_id (str): Mux asset ID

    Returns:
        dict: Asset data containing:
            - id: Asset ID
            - status: Asset status (preparing, ready, errored)
            - playback_ids: List of playback IDs
            - duration: Video duration in seconds
            - max_stored_resolution: Highest resolution available
            - tracks: Audio/video/text tracks

    Raises:
        requests.HTTPError: If Mux API request fails
    """
    headers = get_mux_auth_header()
    url = f'{MUX_API_BASE_URL}/video/v1/assets/{asset_id}'

    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()

    return response.json()['data']


def cancel_upload(upload_id: str) -> Dict[str, Any]:
    """
    Cancel a pending Mux direct upload.

    API Endpoint: PUT /video/v1/uploads/{upload_id}/cancel

    Args:
        upload_id (str): Mux upload ID

    Returns:
        dict: Cancelled upload data

    Raises:
        requests.HTTPError: If Mux API request fails
    """
    headers = get_mux_auth_header()
    url = f'{MUX_API_BASE_URL}/video/v1/uploads/{upload_id}/cancel'

    logger.info(f"Cancelling Mux upload: upload_id={upload_id}")

    response = requests.put(url, headers=headers, timeout=10)
    response.raise_for_status()

    return response.json()['data']


def verify_mux_webhook_signature(
    request_body: bytes,
    mux_signature: str,
    webhook_secret: str
) -> bool:
    """
    Verify Mux webhook signature.

    Mux signs webhook payloads with HMAC-SHA256.

    Args:
        request_body (bytes): Raw request body from webhook
        mux_signature (str): Signature from Mux-Signature header
        webhook_secret (str): Webhook signing secret from Mux

    Returns:
        bool: True if signature is valid

    Note:
        Webhook signature verification is optional but recommended for production.
        See: https://docs.mux.com/guides/video/verify-webhook-signatures
    """
    import hmac
    import hashlib

    # Mux-Signature format: "t={timestamp},v1={signature}"
    # Extract v1 signature
    try:
        parts = dict(part.split('=') for part in mux_signature.split(','))
        signature = parts.get('v1', '')
    except Exception:
        logger.warning("Failed to parse Mux-Signature header")
        return False

    # Compute expected signature
    expected_signature = hmac.new(
        webhook_secret.encode('utf-8'),
        request_body,
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison
    return hmac.compare_digest(signature, expected_signature)


def create_asset_from_url(
    url: str,
    new_asset_settings: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Create a Mux asset from a video URL (server-to-server ingestion).

    API Endpoint: POST /video/v1/assets

    Args:
        url (str): Video file URL (must be publicly accessible or signed)
        new_asset_settings (dict, optional): Asset creation settings
            (e.g., playback_policy, encoding_tier, passthrough metadata)

    Returns:
        dict: Mux asset response containing:
            - id: Asset ID
            - status: Asset status (preparing, ready, errored)
            - playback_ids: List of playback IDs
            - created_at: Creation timestamp

    Raises:
        requests.HTTPError: If Mux API request fails
        ValueError: If MUX credentials not configured

    Example:
        >>> asset = create_asset_from_url(
        ...     url='https://storage.googleapis.com/video.mp4',
        ...     new_asset_settings={
        ...         'playback_policy': ['public'],
        ...         'encoding_tier': 'baseline'
        ...     }
        ... )
        >>> asset_id = asset['id']

    @covers: AC-VPD-001
    """
    headers = get_mux_auth_header()

    payload = {
        'input': url,
    }

    if new_asset_settings:
        payload.update(new_asset_settings)

    api_url = f'{MUX_API_BASE_URL}/video/v1/assets'

    logger.info(f"Creating Mux asset from URL: url={url}, encoding_tier={new_asset_settings.get('encoding_tier', 'default')}")

    response = requests.post(api_url, json=payload, headers=headers, timeout=10)
    response.raise_for_status()

    asset_data = response.json()['data']

    logger.info(
        f"Mux asset created: asset_id={asset_data['id']}, "
        f"status={asset_data['status']}"
    )

    return asset_data


def validate_video_format(filename: str, supported_formats: Optional[list] = None) -> bool:
    """
    Validate video file format.

    Args:
        filename (str): Video filename
        supported_formats (list, optional): List of supported extensions
            (default: ['mp4', 'mov', 'mkv', 'webm'])

    Returns:
        bool: True if format is supported

    Raises:
        ValueError: If format is not supported

    Example:
        >>> validate_video_format('lesson1.mp4')  # Returns True
        >>> validate_video_format('lesson2.avi')  # Raises ValueError

    @covers: AC-VPD-002
    """
    if supported_formats is None:
        supported_formats = ['mp4', 'mov', 'mkv', 'webm']

    from pathlib import Path
    extension = Path(filename).suffix.lstrip('.').lower()

    if extension not in supported_formats:
        raise ValueError(
            f"Unsupported video format: {extension}. "
            f"Supported formats: {', '.join(supported_formats)}"
        )

    return True


def wait_for_asset_ready(
    asset_id: str,
    max_wait_seconds: int = 600,
    poll_interval: int = 5
) -> Dict[str, Any]:
    """
    Poll Mux asset until it reaches 'ready' status.

    Args:
        asset_id (str): Mux asset ID
        max_wait_seconds (int): Maximum time to wait (default: 600s = 10 minutes)
        poll_interval (int): Seconds between status checks (default: 5s)

    Returns:
        dict: Asset data when status is 'ready'

    Raises:
        TimeoutError: If asset doesn't reach 'ready' within max_wait_seconds
        ValueError: If asset status is 'errored'

    Example:
        >>> asset = wait_for_asset_ready('asset_id_123', max_wait_seconds=300)
        >>> playback_id = asset['playback_ids'][0]['id']

    @covers: AC-VPD-004
    """
    import time

    logger.info(f"Waiting for asset to be ready: asset_id={asset_id}, max_wait={max_wait_seconds}s")

    start_time = time.time()
    elapsed = 0

    while elapsed < max_wait_seconds:
        asset = get_asset(asset_id)
        status_val = asset['status']

        logger.debug(f"Asset status: asset_id={asset_id}, status={status_val}, elapsed={elapsed}s")

        if status_val == 'ready':
            logger.info(f"Asset ready: asset_id={asset_id}, elapsed={elapsed}s")
            return asset

        if status_val == 'errored':
            error_messages = asset.get('errors', {}).get('messages', [])
            error_msg = '; '.join(error_messages) if error_messages else 'Unknown error'
            raise ValueError(f"Asset processing failed: {error_msg}")

        # Poll interval
        time.sleep(poll_interval)
        elapsed = time.time() - start_time

    raise TimeoutError(
        f"Asset did not reach 'ready' status within {max_wait_seconds}s. "
        f"Current status: {asset.get('status', 'unknown')}"
    )
