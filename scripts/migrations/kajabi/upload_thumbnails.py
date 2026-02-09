#!/usr/bin/env python3
"""Upload course thumbnails to Open edX CMS contentstore.

Must be run inside the CMS container (or via kubectl exec).
Reads thumbnail images from /tmp/thumbnails/ and sets course_image for each course.

Usage:
    python upload_thumbnails.py --manifest /tmp/thumbnail_manifest.csv --settings tutor.production
    python upload_thumbnails.py --manifest /tmp/thumbnail_manifest.csv --dry-run
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Upload course thumbnails")
    parser.add_argument("--manifest", required=True,
                        help="CSV with kajabi_course_id,course_key,image_filename")
    parser.add_argument("--thumbs-dir", default="/tmp/thumbnails")
    parser.add_argument("--settings", default="tutor.production")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    rows = []
    with open(args.manifest) as f:
        for row in csv.DictReader(f):
            rows.append(row)

    print("Loaded %d courses from manifest" % len(rows))

    if args.dry_run:
        for row in rows:
            img = Path(args.thumbs_dir) / row["image_filename"]
            exists = img.exists()
            status = "OK" if exists else "MISSING"
            print("  %s %s -> %s" % (status, row["course_key"], row["image_filename"]))
        return

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", args.settings)
    os.environ.setdefault("SERVICE_VARIANT", "cms")
    import django
    django.setup()

    from opaque_keys.edx.keys import CourseKey
    from xmodule.modulestore.django import modulestore
    from xmodule.contentstore.django import contentstore
    from xmodule.contentstore.content import StaticContent

    store = modulestore()
    stats = {"uploaded": 0, "skipped": 0, "failed": 0}

    for row in rows:
        course_key_str = row["course_key"]
        image_filename = row["image_filename"]
        image_path = Path(args.thumbs_dir) / image_filename

        if not image_path.exists():
            print("  SKIP %s: %s not found" % (course_key_str, image_filename))
            stats["skipped"] += 1
            continue

        try:
            course_key = CourseKey.from_string(course_key_str)
            content_bytes = image_path.read_bytes()

            ext = image_path.suffix.lower()
            content_type = {
                ".png": "image/png",
                ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg",
                ".gif": "image/gif",
                ".webp": "image/webp",
            }.get(ext, "image/jpeg")

            asset_name = "course_image" + ext
            asset_key = course_key.make_asset_key("asset", asset_name)

            sc = StaticContent(
                asset_key,
                asset_name,
                content_type,
                content_bytes,
            )
            contentstore().save(sc)

            course = store.get_course(course_key)
            if course:
                course.course_image = asset_name
                store.update_item(course, None)
                stats["uploaded"] += 1
                if stats["uploaded"] % 10 == 0:
                    print("  Uploaded %d..." % stats["uploaded"])
            else:
                print("  FAIL %s: course not found in modulestore" % course_key_str)
                stats["failed"] += 1

        except Exception as e:
            print("  FAIL %s: %s" % (course_key_str, e))
            stats["failed"] += 1

    print("Results: uploaded=%d skipped=%d failed=%d" % (
        stats["uploaded"], stats["skipped"], stats["failed"]))


if __name__ == "__main__":
    main()
