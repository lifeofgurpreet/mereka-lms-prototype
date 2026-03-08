#!/usr/bin/env python3
"""
Download MCT lesson thumbnails using fresh Azure SAS token.
Replaces expired SAS tokens with new one and downloads to local directory.
"""

import json
import os
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Config
STORAGE_ACCOUNT = "mctindonesiastj6v44p6u6o"
SAS_TOKEN = os.environ.get("AZURE_SAS_TOKEN", "")
MAX_WORKERS = 10


def resolve_repo_root() -> Path:
    """Resolve repository root from env, git, then script-relative fallback."""
    configured = os.environ.get("MEREKA_LMS_REPO_ROOT") or os.environ.get("REPO_ROOT")
    if configured:
        return Path(configured).expanduser().resolve()
    try:
        top = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if top:
            return Path(top)
    except Exception:
        pass
    return Path(__file__).resolve().parents[3]


REPO_ROOT = resolve_repo_root()
INPUT_FILE = str(REPO_ROOT / "exports" / "mct" / "structure" / "course_content.ndjson")
OUTPUT_DIR = str(REPO_ROOT / "var" / "migrations" / "mct" / "thumbnails")

def extract_thumbnails():
    """Extract lesson thumbnails from course content."""
    thumbnails = []

    with open(INPUT_FILE) as f:
        for line in f:
            if not line.strip():
                continue
            course = json.loads(line)
            course_id = course.get('courseId', 'unknown')

            for item in course.get('CourseItems', []):
                # Data is nested inside CourseItems[].Data
                data = item.get('Data', {})
                lesson_id = data.get('Id') or item.get('CourseItemId')
                thumb_url = data.get('ThumbnailUrl', '')

                if thumb_url and lesson_id:
                    thumbnails.append({
                        'lesson_id': lesson_id,
                        'course_id': course_id,
                        'original_url': thumb_url,
                        'title': data.get('Title', '')
                    })

    return thumbnails

def build_fresh_url(original_url):
    """Replace CDN URL with direct blob storage URL using fresh SAS token."""
    if not original_url:
        return None

    # Parse original URL to extract path
    parsed = urllib.parse.urlparse(original_url)
    path = parsed.path  # e.g., /output-xxx/thumbnail/thumbnail-1_0.jpg

    # Build direct blob storage URL with fresh SAS
    blob_url = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net{path}?{SAS_TOKEN}"
    return blob_url

def download_thumbnail(thumb_info):
    """Download a single thumbnail."""
    lesson_id = thumb_info['lesson_id']
    original_url = thumb_info['original_url']

    fresh_url = build_fresh_url(original_url)
    if not fresh_url:
        return {'lesson_id': lesson_id, 'success': False, 'error': 'No URL'}

    # Determine filename from URL
    parsed = urllib.parse.urlparse(original_url)
    path_parts = parsed.path.split('/')

    # Create filename: lesson_{id}_{original_filename}
    original_filename = path_parts[-1] if path_parts else 'thumbnail.jpg'
    local_filename = f"lesson_{lesson_id}_{original_filename}"
    local_path = os.path.join(OUTPUT_DIR, local_filename)

    try:
        # Create SSL context that doesn't verify (for corporate proxies)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(fresh_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30, context=ctx) as response:
            with open(local_path, 'wb') as f:
                f.write(response.read())

        return {
            'lesson_id': lesson_id,
            'success': True,
            'local_path': local_path,
            'size': os.path.getsize(local_path)
        }
    except Exception as e:
        return {
            'lesson_id': lesson_id,
            'success': False,
            'error': str(e)
        }

def main():
    if not SAS_TOKEN:
        print("ERROR: Set AZURE_SAS_TOKEN environment variable")
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Extracting thumbnails from course content...")
    thumbnails = extract_thumbnails()
    print(f"Found {len(thumbnails)} lessons with thumbnails")

    # Dry run check
    if '--dry-run' in sys.argv:
        print("\nDRY RUN - First 5 URLs:")
        for t in thumbnails[:5]:
            fresh = build_fresh_url(t['original_url'])
            print(f"  Lesson {t['lesson_id']}: {fresh[:80]}...")
        return

    # Download with progress
    print(f"\nDownloading thumbnails to {OUTPUT_DIR}...")
    results = {'success': 0, 'failed': 0, 'errors': []}

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(download_thumbnail, t): t for t in thumbnails}

        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            if result['success']:
                results['success'] += 1
            else:
                results['failed'] += 1
                results['errors'].append(result)

            if i % 50 == 0 or i == len(thumbnails):
                print(f"  Progress: {i}/{len(thumbnails)} ({results['success']} ok, {results['failed']} failed)")

    print(f"\n✓ Downloaded: {results['success']}")
    print(f"✗ Failed: {results['failed']}")

    if results['errors']:
        print("\nFirst 5 errors:")
        for e in results['errors'][:5]:
            print(f"  Lesson {e['lesson_id']}: {e.get('error', 'unknown')}")

    # Save results
    results_file = os.path.join(OUTPUT_DIR, 'download_results.json')
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {results_file}")

if __name__ == '__main__':
    main()
