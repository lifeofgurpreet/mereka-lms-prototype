#!/usr/bin/env python3
"""
Fix Mux video titles.

The upload script set passthrough metadata but not the actual 'name' field
that Mux displays in the dashboard. This script updates all assets with
their proper titles.

Usage:
    source .env.mux
    python scripts/migrations/mct/fix_mux_titles.py
"""

import json
import os
import sys
import time
from pathlib import Path

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
        print("Error: MUX_TOKEN_ID and MUX_TOKEN_SECRET required")
        sys.exit(1)

    configuration = mux_python.Configuration()
    configuration.username = token_id
    configuration.password = token_secret

    return mux_python.ApiClient(configuration)


def main():
    # Load the upload results
    base_dir = Path(__file__).parent.parent.parent.parent
    results_file = base_dir / 'exports' / 'mct' / 'mux_upload_complete.json'

    if not results_file.exists():
        print(f"Error: Results file not found: {results_file}")
        sys.exit(1)

    with open(results_file) as f:
        data = json.load(f)

    videos = data['successful']
    print(f"Loaded {len(videos)} videos to update")

    # Initialize Mux client
    api_client = get_mux_client()
    assets_api = mux_python.AssetsApi(api_client)

    updated = 0
    failed = 0

    for i, video in enumerate(videos):
        asset_id = video['mux_asset_id']
        title = video['title']

        print(f"[{i+1}/{len(videos)}] Updating: {title[:50]}...")

        try:
            # Update asset with meta.title
            meta = mux_python.AssetMetadata(
                title=title,
                external_id=str(video['mct_lesson_id'])
            )
            update_request = mux_python.UpdateAssetRequest(meta=meta)
            assets_api.update_asset(asset_id, update_request)
            updated += 1
            print("  ✓ Updated")
        except ApiException as e:
            print(f"  ✗ Error: {e}")
            failed += 1

        # Rate limiting
        time.sleep(0.3)

        # Progress save every 50
        if (i + 1) % 50 == 0:
            print(f"\nProgress: {updated} updated, {failed} failed\n")

    print(f"\n{'='*60}")
    print("Complete!")
    print(f"  Updated: {updated}")
    print(f"  Failed: {failed}")


if __name__ == '__main__':
    main()
