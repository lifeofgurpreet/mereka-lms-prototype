#!/usr/bin/env python3
"""Set course descriptions and thumbnail images after OLX import.

Two-phase workflow
------------------
Phase 1 — build plan (runs on the host, no Django required):

    python scripts/migrations/post_import_metadata.py --build-plan

    Reads:
      - exports/mct/raw_api/categories_and_courses_v3.json  → course descriptions
      - exports/kajabi/products.ndjson                       → Kajabi descriptions
      - exports/mct/video_mapping_openedx.json               → Mux playback IDs for MCT
      - exports/drive/mux_upload_results.json                → Mux playback IDs for Drive
      - exports/drive/videos_for_mux.json                    → Drive course key mapping
      - exports/mct/olx_packages/course_packages_manifest.csv
      - exports/drive/olx_packages/course_packages_manifest.csv

    Writes:
      scripts/migrations/metadata_plan.json

Phase 2 — apply plan (runs inside the CMS pod via manage.py cms shell):

    kubectl exec -n mereka-lms $CMS_POD -c cms -- \\
        python manage.py cms shell < scripts/migrations/post_import_metadata.py

    Reads: /tmp/metadata_plan.json  (copy the plan into the pod first)
    Env vars:
        METADATA_PLAN     Path to plan JSON (default: /tmp/metadata_plan.json)
        DRY_RUN           Set to "1" to skip writes (default: 0)
        COURSE_FILTER     Only process this course key (optional)
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Repo-relative paths (used in Phase 1 only)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
EXPORTS_MCT = REPO_ROOT / "exports" / "mct"
EXPORTS_KAJABI = REPO_ROOT / "exports" / "kajabi"
EXPORTS_DRIVE = REPO_ROOT / "exports" / "drive"
PLAN_FILE = Path(__file__).resolve().parent / "metadata_plan.json"


# ===========================================================================
# PHASE 1 — build plan
# ===========================================================================

def _load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def _iter_ndjson(path: Path):
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


def _extract_mct_descriptions() -> dict[str, str]:
    """Return course_number -> description from MCT API data.

    MCT CourseItems are nested: each Offer (category) has a ParentId = category_id.
    We pair them with the manifest to map category → course_number.

    Strategy:
    - The manifest maps mct_course_id to course_number.
    - CourseItems have Id, ParentId (category), Description.
    - Video mapping maps category_id -> openedx_course_id.
    So: course_number = strip 'course-v1:MEREKA+' and '+course' from openedx_course_id.
    """
    path = EXPORTS_MCT / "raw_api" / "categories_and_courses_v3.json"
    if not path.exists():
        print(f"  SKIP MCT descriptions: {path} not found", file=sys.stderr)
        return {}

    data = _load_json(path)
    items = data.get("CourseItems", [])

    # Build Offer (category) id -> name
    offers_by_id: dict[int, str] = {}
    for offer in data.get("Offers", []):
        oid = offer.get("Id")
        names = offer.get("Names", [])
        en_name = next((n["Value"] for n in names if n.get("LanguageCode", "").startswith("en")), names[0]["Value"] if names else "")
        offers_by_id[oid] = en_name.strip()

    # Build category_id -> openedx course key from video_mapping
    vm_path = EXPORTS_MCT / "video_mapping_openedx.json"
    cat_to_key: dict[str, str] = {}
    if vm_path.exists():
        vm = _load_json(vm_path)
        for cat_id, cat_data in vm.get("categories", {}).items():
            oex = cat_data.get("openedx_course_id", "")
            if oex:
                # e.g. course-v1:SKILLOURFUTURE+MCT-24+course -> MCT24
                # or   course-v1:MEREKA+MCT32-EN+course       -> MCT32-EN
                m = re.search(r"MEREKA\+([^+]+)\+", oex)
                if m:
                    cat_to_key[str(cat_id)] = m.group(1)
                else:
                    m = re.search(r"SKILLOURFUTURE\+MCT-(\d+)\+", oex)
                    if m:
                        cat_to_key[str(cat_id)] = f"MCT{m.group(1)}-EN"

    # Also load the MCT manifest to directly map category → course_number
    manifest_path = EXPORTS_MCT / "olx_packages" / "course_packages_manifest.csv"
    manifest_course_numbers: dict[str, str] = {}
    if manifest_path.exists():
        with manifest_path.open(newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                manifest_course_numbers[row["mct_course_id"]] = row["course_number"]

    # Each item has ParentId (the Offer/category id) and optional Description
    # Map: course_number -> first non-empty description found in its modules
    result: dict[str, str] = {}
    for item in items:
        desc = (item.get("Description") or "").strip()
        if not desc:
            continue
        parent_id = str(item.get("ParentId", ""))
        # Try to resolve course number from category
        course_num = cat_to_key.get(parent_id)
        if not course_num:
            continue
        if course_num not in result:
            result[course_num] = desc

    return result


def _extract_kajabi_descriptions() -> dict[str, str]:
    """Return kajabi_product_id -> description from products.ndjson."""
    path = EXPORTS_KAJABI / "products.ndjson"
    if not path.exists():
        print(f"  SKIP Kajabi descriptions: {path} not found", file=sys.stderr)
        return {}

    result: dict[str, str] = {}
    for rec in _iter_ndjson(path):
        pid = str(rec.get("id", ""))
        desc = (rec.get("attributes", {}).get("description") or "").strip()
        title = (rec.get("attributes", {}).get("title") or "").strip()
        if pid:
            result[pid] = desc
    return result


def _build_kajabi_product_to_course() -> dict[str, str]:
    """Return kajabi_product_id -> openedx_course_key from completions/purchases.

    We use the products.ndjson title to infer the course key via known mapping.
    """
    TITLE_TO_COURSE: dict[str, str] = {
        "Personal Branding": "course-v1:MEREKA+PB-EN+course",
        "Freelancing 101": "course-v1:MEREKA+F101-MS+course",
        "Personal Finance": "course-v1:MEREKA+PF-ID+course",
        "Professional Writing": "course-v1:MEREKA+PW-EN+course",
        "Thriving in Your Job": "course-v1:MEREKA+TYJ-EN+course",
        "Securing Your First Job": "course-v1:MEREKA+SYFJ-ID+course",
        "Securing Your First Client": "course-v1:MEREKA+SYFC-MS+course",
        "Managing Your First Client": "course-v1:MEREKA+MYFC-MS+course",
        "Skills Profiling": "course-v1:MEREKA+SP-MS+course",
        "Boosting Sales and Productivity with ChatGPT": "course-v1:MEREKA+UPAI2-EN+course",
        "Getting Started with ChatGPT": "course-v1:MEREKA+UPAI1-EN+course",
        "ChatGPT for Job Search": "course-v1:MEREKA+UPAI3-EN+course",
    }
    path = EXPORTS_KAJABI / "products.ndjson"
    if not path.exists():
        return {}
    result: dict[str, str] = {}
    for rec in _iter_ndjson(path):
        pid = str(rec.get("id", ""))
        title = (rec.get("attributes", {}).get("title") or "").strip()
        course_key = TITLE_TO_COURSE.get(title)
        if pid and course_key:
            result[pid] = course_key
    return result


def _extract_mux_thumbnails_from_video_mapping() -> dict[str, str]:
    """Return openedx_course_key -> first Mux thumbnail URL from MCT video mapping."""
    vm_path = EXPORTS_MCT / "video_mapping_openedx.json"
    if not vm_path.exists():
        return {}
    vm = _load_json(vm_path)
    result: dict[str, str] = {}
    for cat_data in vm.get("categories", {}).values():
        course_key = cat_data.get("openedx_course_id", "")
        for course_data in cat_data.get("courses", {}).values():
            for lesson in course_data.get("lessons", []):
                playback_id = lesson.get("mux_playback_id")
                if playback_id and course_key not in result:
                    result[course_key] = f"https://image.mux.com/{playback_id}/thumbnail.jpg?time=5"
    return result


def _extract_mux_thumbnails_from_drive() -> dict[str, str]:
    """Return openedx_course_key -> first Mux thumbnail URL from Drive upload results."""
    results_path = EXPORTS_DRIVE / "mux_upload_results.json"
    videos_path = EXPORTS_DRIVE / "videos_for_mux.json"
    if not results_path.exists() or not videos_path.exists():
        return {}

    results_data = _load_json(results_path)
    successful = results_data.get("successful", [])
    # Build airtable_id / course_number -> playback_id
    by_course: dict[str, str] = {}
    for item in successful:
        pid = item.get("mux_playback_id")
        course_key = item.get("new_course_key")
        if pid and course_key and course_key not in by_course:
            by_course[course_key] = f"https://image.mux.com/{pid}/thumbnail.jpg?time=5"

    # Supplement from videos_for_mux if course key is present
    videos = _load_json(videos_path)
    for item in videos:
        course_key = item.get("new_course_key")
        if course_key and course_key not in by_course:
            # No playback yet, skip
            pass

    return by_course


def _read_manifests() -> list[dict]:
    """Return rows from both MCT and Drive OLX manifests, unified."""
    rows = []
    for manifest_path in [
        EXPORTS_MCT / "olx_packages" / "course_packages_manifest.csv",
        EXPORTS_DRIVE / "olx_packages" / "course_packages_manifest.csv",
    ]:
        if manifest_path.exists():
            with manifest_path.open(newline="", encoding="utf-8") as fh:
                for row in csv.DictReader(fh):
                    rows.append({
                        "course_number": row["course_number"],
                        "course_key": f"course-v1:{row['org']}+{row['course_number']}+{row['run']}",
                        "title": row["title"],
                    })
    return rows


def build_plan(output_path: Path, dry_run: bool = False) -> None:
    """Phase 1: build metadata_plan.json without Django."""
    print("Building metadata plan...")

    print("  Loading MCT descriptions...")
    mct_desc = _extract_mct_descriptions()
    print(f"  MCT descriptions: {len(mct_desc)} courses")

    print("  Loading Kajabi descriptions...")
    kajabi_desc_by_product = _extract_kajabi_descriptions()
    kajabi_product_to_course = _build_kajabi_product_to_course()
    # Combine: course_key -> description
    kajabi_desc_by_course: dict[str, str] = {}
    for pid, desc in kajabi_desc_by_product.items():
        course_key = kajabi_product_to_course.get(pid)
        if course_key and desc and course_key not in kajabi_desc_by_course:
            kajabi_desc_by_course[course_key] = desc

    print("  Loading Mux thumbnail URLs (MCT)...")
    mct_thumbnails = _extract_mux_thumbnails_from_video_mapping()

    print("  Loading Mux thumbnail URLs (Drive)...")
    drive_thumbnails = _extract_mux_thumbnails_from_drive()

    print("  Reading course manifests...")
    manifest_rows = _read_manifests()

    plan: list[dict] = []
    for row in manifest_rows:
        course_key = row["course_key"]
        course_number = row["course_number"]

        # Description priority: MCT API > Kajabi > empty
        description = (
            mct_desc.get(course_number)
            or kajabi_desc_by_course.get(course_key)
            or ""
        )

        # Thumbnail priority: MCT video mapping > Drive uploads
        thumbnail_url = (
            mct_thumbnails.get(course_key)
            or drive_thumbnails.get(course_key)
            or ""
        )

        plan.append({
            "course_key": course_key,
            "course_number": course_number,
            "title": row["title"],
            "short_description": description[:500] if description else "",
            "overview": description if description else "",
            "thumbnail_url": thumbnail_url,
        })

    # Sort for deterministic output
    plan.sort(key=lambda r: r["course_key"])

    stats = {
        "total": len(plan),
        "with_description": sum(1 for r in plan if r["short_description"]),
        "with_thumbnail": sum(1 for r in plan if r["thumbnail_url"]),
    }

    output = {"generated_at": _now_iso(), "statistics": stats, "courses": plan}

    if dry_run:
        print(f"  [DRY RUN] Would write {len(plan)} entries to {output_path}")
        print(f"  Stats: {stats}")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as fh:
        json.dump(output, fh, indent=2, ensure_ascii=False)

    print(f"  Written to {output_path}")
    print(f"  Stats: {stats}")


def _now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


# ===========================================================================
# PHASE 2 — apply plan (runs inside manage.py cms shell)
# ===========================================================================

# These imports only succeed inside the CMS Django shell
def _apply_plan_in_cms() -> None:
    """Apply metadata plan to Open edX via modulestore and contentstore."""

    METADATA_PLAN = os.environ.get("METADATA_PLAN", "/tmp/metadata_plan.json")
    DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"
    COURSE_FILTER = os.environ.get("COURSE_FILTER", "").strip() or None

    print(f"apply_plan: reading {METADATA_PLAN}")
    with open(METADATA_PLAN, encoding="utf-8") as fh:
        plan_data = json.load(fh)

    courses = plan_data.get("courses", [])
    if COURSE_FILTER:
        courses = [c for c in courses if c["course_key"] == COURSE_FILTER]
        print(f"apply_plan: filtered to {len(courses)} course(s)")

    # Django / Open edX imports
    from django.core.files.base import ContentFile  # noqa: E402
    from opaque_keys.edx.keys import CourseKey  # noqa: E402
    from xmodule.modulestore.django import modulestore  # noqa: E402
    from xmodule.contentstore.django import contentstore as get_contentstore  # noqa: E402
    from xmodule.contentstore.content import StaticContent  # noqa: E402

    store = modulestore()
    cstore = get_contentstore()

    counters = {"updated": 0, "skipped": 0, "errors": 0}

    for entry in courses:
        course_key_str = entry["course_key"]
        short_description = entry.get("short_description", "")
        overview = entry.get("overview", "")
        thumbnail_url = entry.get("thumbnail_url", "")

        try:
            course_key = CourseKey.from_string(course_key_str)
        except Exception as exc:
            print(f"  ERROR parsing {course_key_str}: {exc}")
            counters["errors"] += 1
            continue

        course = store.get_course(course_key, depth=0)
        if course is None:
            print(f"  SKIP {course_key_str}: course not found in modulestore")
            counters["skipped"] += 1
            continue

        changed = False

        if short_description and not getattr(course, "short_description", None):
            if not DRY_RUN:
                course.short_description = short_description[:500]
            changed = True

        if overview and not getattr(course, "overview", None):
            if not DRY_RUN:
                course.overview = overview
            changed = True

        if thumbnail_url:
            try:
                _set_course_image(
                    store, cstore, course, course_key,
                    thumbnail_url, dry_run=DRY_RUN
                )
                changed = True
            except Exception as exc:
                print(f"  WARN thumbnail failed for {course_key_str}: {exc}")

        if changed:
            if not DRY_RUN:
                with store.bulk_operations(course_key):
                    store.update_item(course, "metadata_importer")
            action = "[DRY RUN] would update" if DRY_RUN else "updated"
            print(f"  {action}: {course_key_str}")
            counters["updated"] += 1
        else:
            print(f"  unchanged: {course_key_str}")
            counters["skipped"] += 1

    print(f"\napply_plan complete: {counters}")


def _set_course_image(store, cstore, course, course_key, thumbnail_url: str, dry_run: bool = False) -> None:
    """Download thumbnail and store as course image in contentstore."""
    req = urllib.request.Request(
        thumbnail_url,
        headers={"User-Agent": "mereka-lms-metadata-importer/1.0"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        image_data = resp.read()

    filename = "course_image.jpg"
    content_loc = StaticContent.compute_location(course_key, filename)
    sc = StaticContent(content_loc, filename, "image/jpeg", image_data)

    if not dry_run:
        cstore.save(sc)
        course.course_image = filename


# ===========================================================================
# Entry point
# ===========================================================================

def _detect_phase() -> str:
    """Guess whether we're running in Phase 1 (CLI) or Phase 2 (Django shell)."""
    try:
        import django  # noqa: F401
        from django.apps import apps
        if apps.ready:
            return "phase2"
    except ImportError:
        pass
    return "phase1"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Set course descriptions and thumbnails after OLX import."
    )
    parser.add_argument(
        "--build-plan",
        action="store_true",
        help="Phase 1: build metadata_plan.json from export data (no Django needed)",
    )
    parser.add_argument(
        "--plan-output",
        type=Path,
        default=PLAN_FILE,
        help=f"Output path for the plan JSON (default: {PLAN_FILE})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not write any files or modify the database",
    )
    args = parser.parse_args()

    if args.build_plan:
        build_plan(args.plan_output, dry_run=args.dry_run)
    else:
        # Called directly or via manage.py shell
        phase = _detect_phase()
        if phase == "phase2":
            _apply_plan_in_cms()
        else:
            parser.print_help()
            print("\nHint: use --build-plan for Phase 1, or run inside manage.py cms shell for Phase 2.")
            sys.exit(1)


if __name__ == "__main__":
    main()
