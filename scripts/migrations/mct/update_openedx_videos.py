#!/usr/bin/env python3
"""
Update Open edX courses with Mux video URLs

After uploading videos to Mux, this script updates the Open edX course
XBlocks to point to the Mux playback URLs.

This script should be run inside the Open edX CMS container.

Usage:
    # Copy to CMS pod
    kubectl cp scripts/migrations/mct/update_openedx_videos.py \
        mereka-lms/cms-xxx:/tmp/update_openedx_videos.py

    # Run inside pod
    kubectl exec -it cms-xxx -- python /tmp/update_openedx_videos.py \
        --results-file /tmp/mux_upload_results.json
"""

import argparse
import json
import os

# Django setup (when running in CMS container)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'cms.envs.tutor.production')
os.environ.setdefault('SERVICE_VARIANT', 'cms')

try:
    import django
    django.setup()
except Exception as e:
    print(f"Warning: Could not initialize Django: {e}")
    print("This script should be run inside the Open edX CMS container")


def get_mux_embed_code(playback_id, title="Video"):
    """Generate Mux video embed HTML."""
    return f'''<iframe
    src="https://stream.mux.com/{playback_id}?autoplay=false"
    width="100%"
    height="400"
    style="aspect-ratio: 16/9;"
    frameborder="0"
    allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen
    title="{title}">
</iframe>'''


def update_video_xblock(course_key, unit_location, mux_playback_id, title):
    """
    Update a video XBlock to use Mux URL.

    Note: Open edX video XBlock supports external URLs.
    We can set the video_url field to the Mux HLS URL.
    """
    from opaque_keys.edx.keys import UsageKey
    from xmodule.modulestore.django import modulestore

    store = modulestore()

    # The Mux HLS URL format
    mux_hls_url = f"https://stream.mux.com/{mux_playback_id}.m3u8"

    try:
        # Get the XBlock
        usage_key = UsageKey.from_string(unit_location)
        block = store.get_item(usage_key)

        # Update video sources
        # Open edX video XBlock expects a list of video URLs
        if hasattr(block, 'html5_sources'):
            block.html5_sources = [mux_hls_url]

        if hasattr(block, 'source'):
            block.source = mux_hls_url

        # Save changes
        store.update_item(block, None)
        return True

    except Exception as e:
        print(f"  Error updating {unit_location}: {e}")
        return False


def create_mapping_file(results_file, output_file):
    """
    Create a mapping file from Mux upload results to Open edX locations.

    This creates a CSV that can be used to manually update courses or
    as input for bulk updates.
    """
    with open(results_file) as f:
        results = json.load(f)

    # Load the MCT to Open edX course mapping
    # MCT categoryId -> Open edX course-v1:SKILLOURFUTURE+MCT-{id}+course
    mapping = []

    for video in results.get('successful', []):
        mct_category_id = video.get('mct_course_id')  # This is actually category ID in our context
        mct_lesson_id = video.get('mct_lesson_id')
        mux_playback_id = video.get('mux_playback_id')
        title = video.get('title')

        if not mux_playback_id:
            continue

        # Open edX course key (MCT category = Open edX course)
        course_key = f"course-v1:SKILLOURFUTURE+MCT-{mct_category_id}+course"

        mapping.append({
            'course_key': course_key,
            'mct_lesson_id': mct_lesson_id,
            'title': title,
            'mux_playback_id': mux_playback_id,
            'mux_stream_url': f"https://stream.mux.com/{mux_playback_id}",
            'mux_hls_url': f"https://stream.mux.com/{mux_playback_id}.m3u8",
            'embed_code': get_mux_embed_code(mux_playback_id, title)
        })

    # Save mapping
    with open(output_file, 'w') as f:
        json.dump(mapping, f, indent=2)

    print(f"Created mapping file with {len(mapping)} entries: {output_file}")
    return mapping


def main():
    parser = argparse.ArgumentParser(description='Update Open edX with Mux videos')
    parser.add_argument('--results-file', required=True, help='Mux upload results JSON file')
    parser.add_argument('--output', default='openedx_video_mapping.json', help='Output mapping file')
    parser.add_argument('--dry-run', action='store_true', help='Just create mapping, do not update')
    args = parser.parse_args()

    # Create the mapping file
    create_mapping_file(args.results_file, args.output)

    if args.dry_run:
        print("\nDry run - mapping file created but no updates applied")
        return

    print("\nNote: Automatic XBlock updates require running inside CMS container")
    print("The mapping file can be used to manually update video URLs in Studio")


if __name__ == '__main__':
    main()
