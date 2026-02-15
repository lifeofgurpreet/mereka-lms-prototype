"""
Mux API client for video migration validation.

Credentials are sourced from environment variables (MUX_TOKEN_ID, MUX_TOKEN_SECRET)
which are synced from Infisical to Kubernetes ExternalSecrets.

@covers: AC-NEG-VID-001 (no hardcoded credentials)
"""
import base64
import logging
import os
import time

import requests

logger = logging.getLogger(__name__)

# Credentials from environment (AC-NEG-VID-001)
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID', '')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET', '')
MUX_API_BASE = 'https://api.mux.com'
MUX_PLAYBACK_BASE = 'https://stream.mux.com'


def get_mux_headers():
    """
    Generate HTTP headers with Mux API basic authentication.

    Returns:
        dict: Headers with Authorization and Content-Type
    """
    if not MUX_TOKEN_ID or not MUX_TOKEN_SECRET:
        logger.error("Mux credentials not found in environment variables")
        return {}

    credentials = f"{MUX_TOKEN_ID}:{MUX_TOKEN_SECRET}"
    encoded = base64.b64encode(credentials.encode()).decode()

    return {
        'Authorization': f'Basic {encoded}',
        'Content-Type': 'application/json',
    }


def get_asset_details(asset_id):
    """
    Retrieve detailed information about a Mux asset.

    Args:
        asset_id (str): Mux asset ID

    Returns:
        dict: Asset details including id, status, playback_ids, duration, max_stored_resolution, tracks
    """
    url = f"{MUX_API_BASE}/video/v1/assets/{asset_id}"
    headers = get_mux_headers()

    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        data = response.json()
        return data.get('data', {})
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to get asset details for {asset_id}: {e}")
        return {}


def list_assets(page=1, limit=100):
    """
    List Mux assets with pagination.

    Args:
        page (int): Page number (1-indexed)
        limit (int): Number of assets per page (max 100)

    Returns:
        list: List of asset dictionaries
    """
    url = f"{MUX_API_BASE}/video/v1/assets"
    headers = get_mux_headers()
    params = {'page': page, 'limit': limit}

    try:
        response = requests.get(url, headers=headers, params=params, timeout=15)
        response.raise_for_status()
        data = response.json()
        return data.get('data', [])
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to list assets (page {page}): {e}")
        return []


def check_playback_url(playback_id):
    """
    Check if a Mux playback URL is accessible.

    Args:
        playback_id (str): Mux playback ID

    Returns:
        tuple: (http_status, is_ok) where is_ok is True if status is 200
    """
    url = f"{MUX_PLAYBACK_BASE}/{playback_id}.m3u8"

    try:
        response = requests.head(url, timeout=15, allow_redirects=True)
        is_ok = response.status_code == 200
        return (response.status_code, is_ok)
    except requests.exceptions.RequestException as e:
        logger.warning(f"Playback check failed for {playback_id}: {e}")
        return (0, False)


def get_asset_metadata(asset_id):
    """
    Extract metadata from a Mux asset.

    Args:
        asset_id (str): Mux asset ID

    Returns:
        dict: Metadata including duration, max_stored_resolution, has_audio, has_video, created_at
    """
    details = get_asset_details(asset_id)
    if not details:
        return {}

    tracks = details.get('tracks', [])
    has_audio = any(track.get('type') == 'audio' for track in tracks)
    has_video = any(track.get('type') == 'video' for track in tracks)

    return {
        'duration': details.get('duration'),
        'max_stored_resolution': details.get('max_stored_resolution'),
        'has_audio': has_audio,
        'has_video': has_video,
        'created_at': details.get('created_at'),
        'status': details.get('status'),
    }


def retry_asset_ingestion(asset_id):
    """
    Retry asset ingestion by creating a new asset from the same source.

    AC-NEG-VID-002: This function never deletes existing assets, only creates new ones
    from the same input URL. Deletion is NOT supported to prevent data loss.

    Args:
        asset_id (str): Original Mux asset ID

    Returns:
        dict: New asset data or empty dict on failure
    """
    # AC-NEG-VID-002: never delete existing assets, only create new ones
    logger.info(f"Retrying ingestion for asset {asset_id} (creating new asset, never deleting)")

    # First, get the original asset to retrieve input URL
    original = get_asset_details(asset_id)
    if not original:
        logger.error(f"Cannot retry ingestion: asset {asset_id} not found")
        return {}

    input_info = original.get('input_info', [])
    if not input_info:
        logger.error(f"Cannot retry ingestion: no input_info for asset {asset_id}")
        return {}

    # Extract the input URL from the original asset
    input_url = input_info[0].get('settings', {}).get('url')
    if not input_url:
        logger.error(f"Cannot retry ingestion: no input URL for asset {asset_id}")
        return {}

    # Create a new asset from the same input URL
    url = f"{MUX_API_BASE}/video/v1/assets"
    headers = get_mux_headers()
    payload = {
        'input': input_url,
        'playback_policy': ['public'],
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=15)
        response.raise_for_status()
        data = response.json()
        new_asset = data.get('data', {})
        logger.info(f"Created new asset {new_asset.get('id')} from {asset_id}")
        return new_asset
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to retry ingestion for {asset_id}: {e}")
        return {}


def bulk_check_assets(asset_ids, rate_limit_delay=0.5):
    """
    Check multiple assets with rate limiting.

    Args:
        asset_ids (list): List of Mux asset IDs
        rate_limit_delay (float): Seconds to sleep between API calls

    Returns:
        list: List of asset metadata dictionaries
    """
    results = []
    for asset_id in asset_ids:
        metadata = get_asset_metadata(asset_id)
        if metadata:
            metadata['asset_id'] = asset_id
            results.append(metadata)

        # Rate limiting per Mux guidelines
        time.sleep(rate_limit_delay)

    return results
