"""
Video XBlock Configuration for Mux HLS Playback.

Provides helper functions to configure Open edX Video XBlocks
to use Mux HLS streaming URLs with correct poster images,
caption settings, and download restrictions.

@spec: video-pipeline-delivery_spec.md (Phase 2)
@covers: AC-VPD-005, AC-VPD-006, AC-VPD-013
"""
import logging
import os

from django.conf import settings

logger = logging.getLogger(__name__)

MUX_STREAM_BASE = os.environ.get('MUX_PLAYBACK_BASE_URL', 'https://stream.mux.com')
MUX_IMAGE_BASE = 'https://image.mux.com'


def get_hls_url(playback_id):
    """
    Build HLS streaming URL for a Mux playback ID.

    Args:
        playback_id (str): Mux playback ID

    Returns:
        str: HLS URL e.g. https://stream.mux.com/{PLAYBACK_ID}.m3u8
    """
    if not playback_id:
        return ''
    return f'{MUX_STREAM_BASE}/{playback_id}.m3u8'


def get_poster_url(playback_id, width=1280, height=720, time=None):
    """
    Build poster/thumbnail URL from Mux Image API.

    Args:
        playback_id (str): Mux playback ID
        width (int): Thumbnail width (default 1280)
        height (int): Thumbnail height (default 720)
        time (float, optional): Timestamp in seconds for thumbnail frame

    Returns:
        str: Thumbnail URL e.g. https://image.mux.com/{PLAYBACK_ID}/thumbnail.jpg?width=1280&height=720
    """
    if not playback_id:
        return ''
    url = f'{MUX_IMAGE_BASE}/{playback_id}/thumbnail.jpg?width={width}&height={height}'
    if time is not None:
        url += f'&time={time}'
    return url


def get_animated_gif_url(playback_id, width=640, fps=15, start=0, end=5):
    """
    Build animated GIF preview URL from Mux Image API.

    Args:
        playback_id (str): Mux playback ID
        width (int): GIF width
        fps (int): Frames per second
        start (float): Start time in seconds
        end (float): End time in seconds

    Returns:
        str: Animated GIF URL
    """
    if not playback_id:
        return ''
    return (
        f'{MUX_IMAGE_BASE}/{playback_id}/animated.gif'
        f'?width={width}&fps={fps}&start={start}&end={end}'
    )


def build_xblock_config(playback_id, course_is_restricted=False, subtitle_tracks=None):
    """
    Build Video XBlock configuration dictionary for Mux HLS playback.

    This generates the configuration needed by the Open edX Video XBlock
    to correctly render Mux video content.

    Args:
        playback_id (str): Mux playback ID (NEVER asset ID — AC-VPD-013)
        course_is_restricted (bool): Whether course requires signed playback
        subtitle_tracks (list, optional): List of subtitle track dicts
            [{'language': 'en', 'label': 'English', 'url': '...'}, ...]

    Returns:
        dict: Video XBlock configuration with keys:
            - source: HLS URL
            - poster: Thumbnail URL
            - download_video: False (always)
            - show_captions: True when subtitle_tracks exist
            - transcripts: dict of language -> URL
            - html5_sources: list with HLS URL
            - sub: default subtitle language
            - use_iframe: False (AC-NEG: no iframe when native HLS available)
    """
    hls_url = get_hls_url(playback_id)
    poster_url = get_poster_url(playback_id)

    # Determine caption settings
    has_subtitles = bool(subtitle_tracks)
    show_captions = has_subtitles

    # Build transcripts dict (language_code -> URL)
    transcripts = {}
    default_sub = ''
    if subtitle_tracks:
        for track in subtitle_tracks:
            lang = track.get('language', 'en')
            transcripts[lang] = track.get('url', '')
        # Default subtitle language
        default_sub = subtitle_tracks[0].get('language', 'en')

    config = {
        'source': hls_url,
        'html5_sources': [hls_url],
        'poster': poster_url,
        'download_video': False,  # AC: download_video=false on all Video XBlocks
        'show_captions': show_captions,  # AC: show_captions=true when subtitle tracks exist
        'transcripts': transcripts,
        'sub': default_sub,
        'use_iframe': False,  # AC-NEG: No iframe embedding when XBlock native HLS available
        'playback_id': playback_id,  # Only playback ID exposed, never asset ID (AC-VPD-013)
    }

    # If course requires signed playback, mark it so frontend fetches token
    if course_is_restricted:
        enable_signed = getattr(settings, 'ENABLE_MUX_SIGNED_PLAYBACK', False)
        config['requires_signed_playback'] = enable_signed
        config['signed_url_endpoint'] = '/api/video/protection/signed-url/'

    return config


def build_xblock_olx(playback_id, display_name='', subtitle_tracks=None,
                     start_time=None, end_time=None):
    """
    Generate OLX XML string for a Video XBlock with Mux HLS.

    Args:
        playback_id (str): Mux playback ID
        display_name (str): Video display name
        subtitle_tracks (list, optional): Subtitle track dicts
        start_time (str, optional): Start time e.g. "00:00:05"
        end_time (str, optional): End time e.g. "00:05:30"

    Returns:
        str: OLX XML string for Video XBlock
    """
    hls_url = get_hls_url(playback_id)
    poster_url = get_poster_url(playback_id)
    has_subtitles = bool(subtitle_tracks)

    # Build transcript elements
    transcript_elements = ''
    if subtitle_tracks:
        for track in subtitle_tracks:
            lang = track.get('language', 'en')
            label = track.get('label', lang.upper())
            url = track.get('url', '')
            transcript_elements += f'\n    <transcript language="{lang}" label="{label}" src="{url}" />'

    # Build time attributes
    time_attrs = ''
    if start_time:
        time_attrs += f' start_time="{start_time}"'
    if end_time:
        time_attrs += f' end_time="{end_time}"'

    olx = (
        f'<video display_name="{display_name}" '
        f'download_video="false" '
        f'show_captions="{str(has_subtitles).lower()}" '
        f'sub="{subtitle_tracks[0]["language"] if subtitle_tracks else "en"}"'
        f'{time_attrs}>\n'
        f'    <source src="{hls_url}" />\n'
        f'    <poster src="{poster_url}" />'
        f'{transcript_elements}\n'
        f'</video>'
    )

    return olx
