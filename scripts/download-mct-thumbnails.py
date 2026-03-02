#!/usr/bin/env python3
"""
Download all course thumbnails from Azure CDN before they expire (Dec 19, 2025).

Extracts Logo URLs from:
- /exports/mct/courses.ndjson (178 courses)
- /exports/mct/categories.ndjson (31 categories)
- /exports/mct/learningpaths.ndjson (13 learning paths)

Downloads images to: /var/migrations/mct/thumbnails/
Creates manifest: /var/migrations/mct/thumbnails/manifest.json
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


def extract_urls_from_ndjson(file_path: Path, id_field: str, type_prefix: str) -> dict[str, str]:
    """
    Extract Logo URLs from NDJSON file.

    Returns dict mapping local_filename -> original_url
    """
    print(f"\n📂 Reading {file_path.name}...")

    url_map = {}
    count = 0

    with open(file_path, encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            try:
                obj = json.loads(line)
                logo_url = obj.get('Logo', '').strip()

                if not logo_url:
                    continue

                # Get ID
                record_id = obj.get(id_field)
                if not record_id:
                    print(f"  ⚠️  Line {line_num}: Missing {id_field}, skipping")
                    continue

                # Parse URL to get file extension
                parsed = urlparse(logo_url)
                path_part = parsed.path

                # Extract filename from path (e.g., /storage/images/coursesBlob/filename.jpg)
                original_filename = path_part.split('/')[-1]

                # Get extension
                _, ext = os.path.splitext(original_filename)
                if not ext:
                    ext = '.jpg'  # Default to .jpg if no extension

                # Create local filename: type_ID.ext
                local_filename = f"{type_prefix}_{record_id}{ext}"

                url_map[local_filename] = logo_url
                count += 1

            except json.JSONDecodeError as e:
                print(f"  ⚠️  Line {line_num}: JSON parse error: {e}")
            except Exception as e:
                print(f"  ⚠️  Line {line_num}: Error: {e}")

    print(f"  ✅ Found {count} logo URLs")
    return url_map


def download_image(url: str, output_path: Path) -> bool:
    """
    Download image using curl.

    Returns True if successful, False otherwise.
    """
    try:
        # Use curl with follow redirects, 30s timeout
        result = subprocess.run(
            [
                'curl',
                '-L',  # Follow redirects
                '-f',  # Fail silently on HTTP errors
                '-s',  # Silent mode
                '--max-time', '30',  # 30 second timeout
                '-o', str(output_path),
                url
            ],
            capture_output=True,
            timeout=35
        )

        if result.returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
            return True
        else:
            return False

    except subprocess.TimeoutExpired:
        print(f"    ⏱️  Timeout downloading {output_path.name}")
        return False
    except Exception as e:
        print(f"    ❌ Error downloading {output_path.name}: {e}")
        return False


def main():
    # Base paths
    base_dir = Path('/home/dev/code/mereka-lms')
    exports_dir = base_dir / 'exports' / 'mct'
    output_dir = base_dir / 'var' / 'migrations' / 'mct' / 'thumbnails'

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"📁 Output directory: {output_dir}")

    # Extract URLs from all sources
    all_urls = {}

    # 1. Courses
    courses_file = exports_dir / 'courses.ndjson'
    if courses_file.exists():
        course_urls = extract_urls_from_ndjson(courses_file, 'Id', 'course')
        all_urls.update(course_urls)
    else:
        print(f"⚠️  File not found: {courses_file}")

    # 2. Categories
    categories_file = exports_dir / 'categories.ndjson'
    if categories_file.exists():
        category_urls = extract_urls_from_ndjson(categories_file, 'Id', 'category')
        all_urls.update(category_urls)
    else:
        print(f"⚠️  File not found: {categories_file}")

    # 3. Learning Paths
    learningpaths_file = exports_dir / 'learningpaths.ndjson'
    if learningpaths_file.exists():
        learningpath_urls = extract_urls_from_ndjson(learningpaths_file, 'Id', 'learningpath')
        all_urls.update(learningpath_urls)
    else:
        print(f"⚠️  File not found: {learningpaths_file}")

    print(f"\n📊 Total unique images to download: {len(all_urls)}")

    if not all_urls:
        print("❌ No URLs found! Exiting.")
        sys.exit(1)

    # Download images
    print("\n⬇️  Starting downloads...\n")

    success_count = 0
    failed_count = 0
    skipped_count = 0

    manifest = {
        'downloaded': {},
        'failed': {},
        'skipped': []
    }

    for idx, (local_filename, url) in enumerate(all_urls.items(), 1):
        output_path = output_dir / local_filename

        # Skip if already downloaded
        if output_path.exists() and output_path.stat().st_size > 0:
            print(f"  [{idx}/{len(all_urls)}] ⏭️  Skip (exists): {local_filename}")
            skipped_count += 1
            manifest['skipped'].append(local_filename)
            continue

        print(f"  [{idx}/{len(all_urls)}] ⬇️  Downloading: {local_filename}")

        if download_image(url, output_path):
            file_size = output_path.stat().st_size
            print(f"    ✅ Success ({file_size:,} bytes)")
            success_count += 1
            manifest['downloaded'][local_filename] = {
                'url': url,
                'size_bytes': file_size,
                'path': str(output_path)
            }
        else:
            print(f"    ❌ Failed: {url[:80]}...")
            failed_count += 1
            manifest['failed'][local_filename] = url

            # Remove empty file if exists
            if output_path.exists():
                output_path.unlink()

    # Save manifest
    manifest_path = output_dir / 'manifest.json'
    manifest['summary'] = {
        'total_urls': len(all_urls),
        'downloaded': success_count,
        'failed': failed_count,
        'skipped': skipped_count
    }

    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"\n{'='*60}")
    print("📊 Download Summary:")
    print(f"{'='*60}")
    print(f"  Total URLs:        {len(all_urls)}")
    print(f"  ✅ Downloaded:     {success_count}")
    print(f"  ⏭️  Skipped:        {skipped_count}")
    print(f"  ❌ Failed:         {failed_count}")
    print(f"{'='*60}")
    print("\n📁 Output:")
    print(f"  Images:   {output_dir}")
    print(f"  Manifest: {manifest_path}")

    # List failed URLs if any
    if failed_count > 0:
        print("\n⚠️  Failed downloads:")
        for filename, url in manifest['failed'].items():
            print(f"    - {filename}: {url[:80]}...")

    return 0 if failed_count == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
