"""
Subtitle and caption management for Mux video assets.

Supports uploading SRT and VTT subtitle files as Mux text tracks.
Default language is English when no language specified (AC-VPD-009).

@spec: video-pipeline-delivery_spec.md (Phase 2)
@covers: AC-VPD-008, AC-VPD-009, AC-VPD-010
"""
import logging
import os

import requests

from .mux_client import MUX_API_BASE, get_mux_headers

logger = logging.getLogger(__name__)

SUPPORTED_SUBTITLE_FORMATS = ('srt', 'vtt')

LANGUAGE_LABELS = {
    'en': 'English',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'zh': 'Chinese',
    'ms': 'Malay',
}

DEFAULT_LANGUAGE = 'en'  # AC-VPD-009: Default language_code=en


def upload_subtitle_track(asset_id, subtitle_url, language_code=None,
                          name=None, closed_captions=False):
    """
    Upload a subtitle/caption track to a Mux asset.

    Creates a new text track on the Mux asset. Supports SRT and VTT formats.
    If no language_code is provided, defaults to 'en' (AC-VPD-009).

    Args:
        asset_id (str): Mux asset ID
        subtitle_url (str): URL to the SRT or VTT subtitle file
        language_code (str, optional): Language code (e.g. 'en', 'vi', 'zh').
            Defaults to 'en' when not specified.
        name (str, optional): Human-readable track name.
            Auto-generated from language if not provided.
        closed_captions (bool): Whether this is a closed caption track (default: False)

    Returns:
        dict: Created text track data from Mux API, or empty dict on failure

    Raises:
        ValueError: If subtitle format is not supported
    """
    # Default language to English (AC-VPD-009)
    if not language_code:
        language_code = DEFAULT_LANGUAGE
        logger.info(f'No language specified for subtitle on asset {asset_id}, defaulting to {DEFAULT_LANGUAGE}')

    # Auto-generate name from language
    if not name:
        name = LANGUAGE_LABELS.get(language_code, language_code.upper())

    # Validate format from URL extension
    extension = subtitle_url.rsplit('.', 1)[-1].lower() if '.' in subtitle_url else ''
    if extension and extension not in SUPPORTED_SUBTITLE_FORMATS:
        raise ValueError(
            f'Unsupported subtitle format: .{extension}. '
            f'Supported formats: {", ".join(SUPPORTED_SUBTITLE_FORMATS)}'
        )

    headers = get_mux_headers()
    if not headers:
        logger.error('Cannot upload subtitle: Mux credentials not configured')
        return {}

    url = f'{MUX_API_BASE}/video/v1/assets/{asset_id}/tracks'
    payload = {
        'url': subtitle_url,
        'type': 'text',
        'text_type': 'subtitles',
        'language_code': language_code,
        'name': name,
        'closed_captions': closed_captions,
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=15)
        response.raise_for_status()
        track_data = response.json().get('data', {})
        logger.info(
            f'Uploaded subtitle track for asset {asset_id}: '
            f'language={language_code}, name={name}, track_id={track_data.get("id")}'
        )
        return track_data
    except requests.exceptions.RequestException as e:
        logger.error(f'Failed to upload subtitle for asset {asset_id}: {e}')
        return {}


def list_subtitle_tracks(asset_id):
    """
    List all text tracks on a Mux asset.

    Args:
        asset_id (str): Mux asset ID

    Returns:
        list: List of text track dicts with id, type, text_type, language_code, name, status
    """
    headers = get_mux_headers()
    if not headers:
        return []

    url = f'{MUX_API_BASE}/video/v1/assets/{asset_id}/tracks'

    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        tracks = response.json().get('data', [])
        # Filter to text tracks only
        return [t for t in tracks if t.get('type') == 'text']
    except requests.exceptions.RequestException as e:
        logger.error(f'Failed to list tracks for asset {asset_id}: {e}')
        return []


def delete_subtitle_track(asset_id, track_id):
    """
    Delete a text track from a Mux asset.

    Args:
        asset_id (str): Mux asset ID
        track_id (str): Track ID to delete

    Returns:
        bool: True if deleted successfully
    """
    headers = get_mux_headers()
    if not headers:
        return False

    url = f'{MUX_API_BASE}/video/v1/assets/{asset_id}/tracks/{track_id}'

    try:
        response = requests.delete(url, headers=headers, timeout=15)
        response.raise_for_status()
        logger.info(f'Deleted subtitle track {track_id} from asset {asset_id}')
        return True
    except requests.exceptions.RequestException as e:
        logger.error(f'Failed to delete track {track_id} from asset {asset_id}: {e}')
        return False


def get_subtitle_tracks_for_xblock(asset_id):
    """
    Get subtitle tracks formatted for Video XBlock configuration.

    Returns tracks in the format expected by build_xblock_config():
    [{'language': 'en', 'label': 'English', 'url': '...'}, ...]

    Args:
        asset_id (str): Mux asset ID

    Returns:
        list: Subtitle track dicts for XBlock configuration
    """
    tracks = list_subtitle_tracks(asset_id)
    xblock_tracks = []

    for track in tracks:
        if track.get('text_type') == 'subtitles' and track.get('status') == 'ready':
            xblock_tracks.append({
                'language': track.get('language_code', DEFAULT_LANGUAGE),
                'label': track.get('name', LANGUAGE_LABELS.get(
                    track.get('language_code', ''), 'Unknown'
                )),
                'url': '',  # Mux serves subtitles inline via HLS
                'track_id': track.get('id'),
            })

    return xblock_tracks
