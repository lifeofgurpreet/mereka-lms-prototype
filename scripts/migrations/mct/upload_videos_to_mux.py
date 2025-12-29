#!/usr/bin/env python3
"""
Upload MCT videos to Mux

This script uploads videos from MCT to Mux using the Mux API.
Videos are uploaded directly from their Azure CDN URLs (no download needed).

Requirements:
    pip install mux-python requests

Environment Variables:
    MUX_TOKEN_ID     - Mux API access token ID (required)
    MUX_TOKEN_SECRET - Mux API secret key (required)
    MUX_ENV_ID       - Mux environment ID (optional, defaults to production)

Usage:
    # Set credentials
    export MUX_TOKEN_ID="your-token-id"
    export MUX_TOKEN_SECRET="your-token-secret"

    # Run upload
    python scripts/migrations/mct/upload_videos_to_mux.py

    # Dry run (test without uploading)
    python scripts/migrations/mct/upload_videos_to_mux.py --dry-run

    # Upload specific category only
    python scripts/migrations/mct/upload_videos_to_mux.py --category "AI Fluency"
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path
from datetime import datetime

# Check for mux_python
try:
    import mux_python
    from mux_python.rest import ApiException
except ImportError:
    print("Error: mux_python not installed. Run: pip install mux-python")
    sys.exit(1)


def get_mux_client():
    """Initialize Mux API client."""
    token_id = os.environ.get('MUX_TOKEN_ID')
    token_secret = os.environ.get('MUX_TOKEN_SECRET')

    if not token_id or not token_secret:
        print("Error: MUX_TOKEN_ID and MUX_TOKEN_SECRET environment variables required")
        print("\nTo get Mux credentials:")
        print("1. Log in to https://dashboard.mux.com")
        print("2. Go to Settings > API Access Tokens")
        print("3. Create a new token with 'Mux Video' permissions")
        print("4. Copy the Token ID and Token Secret")
        sys.exit(1)

    configuration = mux_python.Configuration()
    configuration.username = token_id
    configuration.password = token_secret

    return mux_python.ApiClient(configuration)


def load_videos(videos_file):
    """Load video data from extraction output."""
    with open(videos_file, 'r') as f:
        data = json.load(f)
    return data['videos'], data['statistics']


def upload_video_from_url(api_client, video, passthrough_data=None):
    """
    Upload a video to Mux from URL.

    Mux will fetch the video directly from the URL (no need to download first).
    """
    assets_api = mux_python.AssetsApi(api_client)

    # Build input settings
    input_settings = [
        mux_python.InputSettings(url=video['downloadUrl'])
    ]

    # Add caption tracks if available
    if video.get('textTracks'):
        for track in video['textTracks']:
            if track.get('src'):
                # Get language code, default to 'en' if empty or None
                lang_code = track.get('srclang') or 'en'
                if not lang_code or lang_code.strip() == '':
                    lang_code = 'en'
                input_settings.append(
                    mux_python.InputSettings(
                        url=track['src'],
                        type='text',
                        text_type='subtitles',
                        language_code=lang_code,
                        name=track.get('label', 'English') or 'Subtitles',
                        closed_captions=False
                    )
                )

    # Create asset request
    create_asset_request = mux_python.CreateAssetRequest(
        input=input_settings,
        playback_policy=[mux_python.PlaybackPolicy.PUBLIC],
        passthrough=passthrough_data or json.dumps({
            'mct_lesson_id': video['mctLessonId'],
            'mct_course_id': video['mctCourseId'],
            'mct_category_id': video['mctCategoryId'],
            'title': video['title']
        })
        # Note: mp4_support removed - not available on Basic tier
    )

    # Create the asset
    try:
        asset_response = assets_api.create_asset(create_asset_request)
        return asset_response.data
    except ApiException as e:
        print(f"  Error uploading {video['title']}: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description='Upload MCT videos to Mux')
    parser.add_argument('--dry-run', action='store_true', help='Test without uploading')
    parser.add_argument('--category', help='Upload only videos from specific category')
    parser.add_argument('--limit', type=int, help='Limit number of videos to upload')
    parser.add_argument('--resume-from', type=int, help='Resume from specific lesson ID')
    parser.add_argument('--output', default='mux_upload_results.json', help='Output file for results')
    args = parser.parse_args()

    # Paths
    base_dir = Path(__file__).parent.parent.parent.parent
    videos_file = base_dir / 'exports' / 'mct' / 'videos_for_mux.json'
    output_file = base_dir / 'exports' / 'mct' / args.output

    if not videos_file.exists():
        print(f"Error: Videos file not found: {videos_file}")
        print("Run extract_videos.mjs first to generate this file")
        sys.exit(1)

    # Load videos
    videos, stats = load_videos(videos_file)
    print(f"Loaded {len(videos)} videos from {videos_file}")

    # Filter by category if specified
    if args.category:
        videos = [v for v in videos if args.category.lower() in v['mctCategoryName'].lower()]
        print(f"Filtered to {len(videos)} videos in category '{args.category}'")

    # Resume from specific ID if specified
    if args.resume_from:
        videos = [v for v in videos if v['mctLessonId'] >= args.resume_from]
        print(f"Resuming from lesson ID {args.resume_from}: {len(videos)} videos remaining")

    # Apply limit if specified
    if args.limit:
        videos = videos[:args.limit]
        print(f"Limited to {len(videos)} videos")

    if args.dry_run:
        print("\n=== DRY RUN MODE ===")
        print(f"Would upload {len(videos)} videos to Mux")
        for i, video in enumerate(videos[:10]):
            print(f"  {i+1}. {video['title']} (Lesson {video['mctLessonId']})")
        if len(videos) > 10:
            print(f"  ... and {len(videos) - 10} more")
        return

    # Initialize Mux client
    api_client = get_mux_client()
    print("Mux client initialized")

    # Upload videos
    results = {
        'started_at': datetime.now().isoformat(),
        'total_videos': len(videos),
        'successful': [],
        'failed': []
    }

    print(f"\nStarting upload of {len(videos)} videos...")
    print("=" * 60)

    for i, video in enumerate(videos):
        print(f"[{i+1}/{len(videos)}] Uploading: {video['title'][:50]}...")

        asset = upload_video_from_url(api_client, video)

        if asset:
            result = {
                'mct_lesson_id': video['mctLessonId'],
                'mct_course_id': video['mctCourseId'],
                'title': video['title'],
                'mux_asset_id': asset.id,
                'mux_playback_id': asset.playback_ids[0].id if asset.playback_ids else None,
                'status': asset.status
            }
            results['successful'].append(result)
            print(f"  ✓ Asset: {asset.id}")
        else:
            results['failed'].append({
                'mct_lesson_id': video['mctLessonId'],
                'title': video['title'],
                'error': 'Upload failed'
            })

        # Rate limiting - being very conservative to avoid 429 errors
        time.sleep(1.0)

        # Save progress periodically
        if (i + 1) % 10 == 0:
            results['completed_at'] = datetime.now().isoformat()
            with open(output_file, 'w') as f:
                json.dump(results, f, indent=2)

    # Final save
    results['completed_at'] = datetime.now().isoformat()
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)

    print("=" * 60)
    print(f"Upload complete!")
    print(f"  Successful: {len(results['successful'])}")
    print(f"  Failed: {len(results['failed'])}")
    print(f"  Results saved to: {output_file}")


if __name__ == '__main__':
    main()
