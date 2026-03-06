#!/usr/bin/env python3
"""
Verify downloaded MCT thumbnails are valid image files.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def verify_image(file_path: Path) -> tuple[bool, str]:
    """
    Verify an image file using the 'file' command.

    Returns (is_valid, file_type)
    """
    try:
        result = subprocess.run(
            ['file', '-b', str(file_path)],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode != 0:
            return False, "Error running file command"

        file_type = result.stdout.strip()

        # Check if it's a valid image type
        valid_types = ['JPEG', 'PNG', 'SVG', 'image data']
        is_valid = any(t in file_type for t in valid_types)

        return is_valid, file_type

    except Exception as e:
        return False, str(e)


def resolve_repo_root() -> Path:
    """Resolve repository root from env, git, then script-relative fallback."""
    configured = os.environ.get('MEREKA_LMS_REPO_ROOT') or os.environ.get('REPO_ROOT')
    if configured:
        return Path(configured).expanduser().resolve()
    try:
        top = subprocess.check_output(
            ['git', 'rev-parse', '--show-toplevel'],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if top:
            return Path(top)
    except Exception:
        pass
    return Path(__file__).resolve().parents[1]


def main():
    base_dir = resolve_repo_root()
    thumbnails_dir = base_dir / 'var' / 'migrations' / 'mct' / 'thumbnails'
    manifest_path = thumbnails_dir / 'manifest.json'

    if not manifest_path.exists():
        print(f"❌ Manifest not found: {manifest_path}")
        sys.exit(1)

    # Load manifest
    with open(manifest_path, encoding='utf-8') as f:
        manifest = json.load(f)

    downloaded = manifest.get('downloaded', {})

    print("🔍 Verifying downloaded thumbnails...\n")

    valid_count = 0
    invalid_count = 0
    missing_count = 0

    for filename, info in downloaded.items():
        file_path = Path(info['path'])

        if not file_path.exists():
            print(f"  ❌ MISSING: {filename}")
            missing_count += 1
            continue

        is_valid, file_type = verify_image(file_path)

        if is_valid:
            size_kb = file_path.stat().st_size / 1024
            valid_count += 1
            if valid_count <= 5 or valid_count % 20 == 0:
                print(f"  ✅ {filename:40s} ({size_kb:6.1f} KB) - {file_type[:50]}")
        else:
            print(f"  ❌ INVALID: {filename} - {file_type}")
            invalid_count += 1

    print(f"\n{'='*80}")
    print("Verification Summary:")
    print(f"{'='*80}")
    print(f"  Total files in manifest: {len(downloaded)}")
    print(f"  ✅ Valid images:         {valid_count}")
    print(f"  ❌ Invalid images:       {invalid_count}")
    print(f"  ❌ Missing files:        {missing_count}")
    print(f"{'='*80}")

    if invalid_count == 0 and missing_count == 0:
        print("\n✅ All thumbnails are valid and intact!")
        return 0
    else:
        print(f"\n⚠️  Found {invalid_count + missing_count} issues!")
        return 1


if __name__ == '__main__':
    sys.exit(main())
