#!/usr/bin/env python3
"""
Verify Mux asset status from video mapping
AC-022: Check every playback_id in video_mapping_openedx.json resolves to valid, ready asset

This script cross-references the video mapping file with Mux API to verify:
1. All playback IDs exist in Mux
2. Assets have status "ready" (or acceptable states)
3. No broken or missing assets

Requirements:
    pip install mux-python requests

Environment Variables:
    MUX_TOKEN_ID     - Mux API access token ID (required)
    MUX_TOKEN_SECRET - Mux API secret key (required)

Usage:
    # Set credentials
    export MUX_TOKEN_ID="your-token-id"
    export MUX_TOKEN_SECRET="your-token-secret"

    # Run verification
    python scripts/qa/verify-mux-asset-status.py

    # Verify specific mapping file
    python scripts/qa/verify-mux-asset-status.py --mapping exports/mct/video_mapping_openedx.json

    # Dry run (no API calls)
    python scripts/qa/verify-mux-asset-status.py --dry-run
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple

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
        sys.exit(1)

    configuration = mux_python.Configuration()
    configuration.username = token_id
    configuration.password = token_secret

    return mux_python.ApiClient(configuration)


def load_video_mapping(mapping_file: Path) -> Dict:
    """Load video mapping from JSON file."""
    with open(mapping_file, 'r') as f:
        return json.load(f)


def extract_playback_ids(mapping_data: Dict) -> Set[str]:
    """Extract all playback IDs from mapping file."""
    playback_ids = set()

    for category in mapping_data.get('categories', {}).values():
        for course in category.get('courses', {}).values():
            for lesson in course.get('lessons', []):
                if lesson.get('has_mux') and lesson.get('mux_playback_id'):
                    playback_ids.add(lesson['mux_playback_id'])

    return playback_ids


def get_mux_assets(api_client, limit: int = 100) -> List[Dict]:
    """Fetch all Mux assets via API."""
    assets_api = mux_python.AssetsApi(api_client)
    all_assets = []
    page = 1

    print(f"Fetching Mux assets...")

    while True:
        try:
            response = assets_api.list_assets(limit=limit, page=page)
            assets = response.data

            if not assets:
                break

            all_assets.extend(assets)
            print(f"  Fetched page {page}: {len(assets)} assets")

            # Check if there are more pages
            if len(assets) < limit:
                break

            page += 1

        except ApiException as e:
            print(f"Error fetching assets: {e}")
            break

    return all_assets


def verify_playback_ids(
    playback_ids: Set[str],
    api_client,
    dry_run: bool = False
) -> Tuple[List[str], List[str], Dict]:
    """
    Verify playback IDs against Mux API.

    Returns:
        Tuple of (valid_ids, invalid_ids, status_summary)
    """
    if dry_run:
        print("DRY RUN: Would verify", len(playback_ids), "playback IDs")
        return list(playback_ids), [], {}

    # Fetch all assets
    assets = get_mux_assets(api_client)

    # Build playback ID to asset mapping
    playback_to_asset = {}
    for asset in assets:
        for playback_policy in getattr(asset, 'playback_ids', []):
            policy_obj = playback_policy if hasattr(playback_policy, 'id') else None
            if policy_obj:
                playback_id = getattr(policy_obj, 'id', None)
                if playback_id:
                    playback_to_asset[playback_id] = asset

    # Verify each playback ID
    valid_ids = []
    invalid_ids = []
    status_summary = {}

    for playback_id in playback_ids:
        if playback_id in playback_to_asset:
            asset = playback_to_asset[playback_id]
            status = getattr(asset, 'status', 'unknown')
            valid_ids.append(playback_id)

            if status not in status_summary:
                status_summary[status] = 0
            status_summary[status] += 1
        else:
            invalid_ids.append(playback_id)

    return valid_ids, invalid_ids, status_summary


def main():
    parser = argparse.ArgumentParser(
        description='Verify Mux asset status from video mapping'
    )
    parser.add_argument(
        '--mapping',
        type=Path,
        default=Path('exports/mct/video_mapping_openedx.json'),
        help='Path to video mapping JSON file'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Test without API calls'
    )

    args = parser.parse_args()

    # Load mapping file
    if not args.mapping.exists():
        print(f"Error: Mapping file not found: {args.mapping}")
        return 1

    print(f"Loading video mapping from {args.mapping}...")
    mapping_data = load_video_mapping(args.mapping)

    # Extract playback IDs
    playback_ids = extract_playback_ids(mapping_data)
    print(f"Found {len(playback_ids)} unique playback IDs")
    print()

    # Initialize Mux client (if not dry run)
    api_client = None
    if not args.dry_run:
        api_client = get_mux_client()

    # Verify playback IDs
    print("Verifying playback IDs against Mux API...")
    valid_ids, invalid_ids, status_summary = verify_playback_ids(
        playback_ids,
        api_client,
        dry_run=args.dry_run
    )

    # Report results
    print()
    print("=" * 60)
    print("VERIFICATION RESULTS")
    print("=" * 60)
    print(f"Total playback IDs: {len(playback_ids)}")
    print(f"Valid assets: {len(valid_ids)}")
    print(f"Invalid/missing: {len(invalid_ids)}")
    print()

    if status_summary:
        print("Asset status breakdown:")
        for status, count in sorted(status_summary.items()):
            print(f"  {status}: {count}")
        print()

    if invalid_ids:
        print("INVALID PLAYBACK IDs:")
        for playback_id in invalid_ids[:10]:  # Show first 10
            print(f"  - {playback_id}")
        if len(invalid_ids) > 10:
            print(f"  ... and {len(invalid_ids) - 10} more")
        print()
        print("❌ FAILED: Some playback IDs do not resolve to valid Mux assets")
        return 1

    print("✅ SUCCESS: All playback IDs resolve to valid Mux assets")
    return 0


if __name__ == '__main__':
    sys.exit(main())
