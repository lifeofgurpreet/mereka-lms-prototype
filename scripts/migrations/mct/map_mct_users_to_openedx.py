#!/usr/bin/env python3
"""Map MCT users and enrollments to Open edX import format.

Merges three data sources:

1. ``exports/mct/raw_api/admin_users_canonical.json``  (or admin_users.json)
   71 K users: Id, EmailAddress, FirstName, LastName, OrganizationId, IsActive

2. ``exports/mct/raw_api/reports_users.csv``
   71 K rows: Contact (email), Gender, DOB (DD/MM/YYYY), Country, University,
   Linkedin Profile Link, and more demographics.

3. ``exports/mct/enrollments_by_course/course_N.csv``
   178 CSVs: Course (name), Contact (email), Lessons Completed,
   Course Completion Percentage.

Outputs (written to ``exports/mct/openedx_import/``):

- ``users_import.csv``       username, email, name, country, gender,
                              year_of_birth, is_active, password
- ``user_profiles.json``     extended profile (mct_user_id, university, linkedin, …)
- ``enrollments_import.csv`` email, course_id, mode, is_active,
                              mct_completion_pct, mct_lessons_completed

Usage
-----
    python scripts/migrations/mct/map_mct_users_to_openedx.py

    python scripts/migrations/mct/map_mct_users_to_openedx.py --dry-run

    # Only generate user files, skip enrollments (faster)
    python scripts/migrations/mct/map_mct_users_to_openedx.py --users-only
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
EXPORTS_MCT = REPO_ROOT / "exports" / "mct"
RAW_API = EXPORTS_MCT / "raw_api"
OUTPUT_DIR = EXPORTS_MCT / "openedx_import"

ADMIN_USERS_CANONICAL = RAW_API / "admin_users_canonical.json"
ADMIN_USERS_FALLBACK = RAW_API / "admin_users.json"
REPORTS_USERS_CSV = RAW_API / "reports_users.csv"
ENROLLMENTS_DIR = EXPORTS_MCT / "enrollments_by_course"
MANIFEST_CSV = EXPORTS_MCT / "olx_packages" / "course_packages_manifest.csv"

# ---------------------------------------------------------------------------
# MCT organisation_id -> ISO 3166-1 alpha-2 country code
# ---------------------------------------------------------------------------
ORG_TO_COUNTRY: dict[int, str] = {
    6: "ID",   # Indonesia
    7: "VN",   # Vietnam
    8: "TH",   # Thailand
    9: "KH",   # Cambodia
    10: "MY",  # Malaysia
    11: "CN",  # China
    12: "PH",  # Philippines
}

# ---------------------------------------------------------------------------
# Gender normalisation
# ---------------------------------------------------------------------------
GENDER_MAP: dict[str, str] = {
    "male": "m",
    "man": "m",
    "men": "m",
    "female": "f",
    "woman": "f",
    "women": "f",
    "other": "o",
    "prefer not to say": "o",
    "nonbinary": "o",
    "non-binary": "o",
}


def _normalise_gender(raw: str) -> str:
    return GENDER_MAP.get(raw.strip().lower(), "")


# ---------------------------------------------------------------------------
# Username generation
# ---------------------------------------------------------------------------

def _sanitise_username(raw: str, max_len: int = 25) -> str:
    """Create a safe Open edX username from a raw string."""
    # Normalise unicode to ASCII approximation
    normalised = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode("ascii")
    # Keep only alphanumeric, underscore, hyphen, period
    cleaned = re.sub(r"[^a-zA-Z0-9._-]", "_", normalised).strip("_.-")
    if not cleaned:
        cleaned = "user"
    return cleaned[:max_len]


def _make_unique_username(base: str, taken: set[str]) -> str:
    """Append a numeric suffix until the username is unique."""
    candidate = base
    counter = 2
    while candidate.lower() in taken:
        suffix = str(counter)
        candidate = base[: max(1, 25 - len(suffix) - 1)] + "_" + suffix
        counter += 1
    return candidate


# ---------------------------------------------------------------------------
# Date parsing
# ---------------------------------------------------------------------------

def _parse_year_of_birth(dob: str) -> str:
    """Extract year from DD/MM/YYYY or YYYY-MM-DD or similar."""
    dob = dob.strip()
    # DD/MM/YYYY
    m = re.match(r"(\d{1,2})/(\d{1,2})/(\d{4})", dob)
    if m:
        return m.group(3)
    # YYYY-MM-DD
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", dob)
    if m:
        return m.group(1)
    return ""


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

def _load_admin_users() -> list[dict]:
    path = ADMIN_USERS_CANONICAL if ADMIN_USERS_CANONICAL.exists() else ADMIN_USERS_FALLBACK
    if not path.exists():
        print(f"ERROR: cannot find admin_users file at {path}", file=sys.stderr)
        sys.exit(1)
    with path.open(encoding="utf-8") as fh:
        data = json.load(fh)
    return data if isinstance(data, list) else data.get("users", data.get("Users", []))


def _load_reports_users() -> dict[str, dict]:
    """Return email (lower) -> row dict."""
    if not REPORTS_USERS_CSV.exists():
        print(f"WARN: {REPORTS_USERS_CSV} not found; demographics will be empty", file=sys.stderr)
        return {}
    result: dict[str, dict] = {}
    with REPORTS_USERS_CSV.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            # Strip BOM / invisible chars from keys
            clean_row = {k.strip().lstrip("\ufeff"): (v or "").strip() for k, v in row.items() if k is not None}
            email = (clean_row.get("Contact") or "").strip().lower()
            if email:
                result[email] = clean_row
    return result


def _load_manifest() -> dict[str, str]:
    """Return mct_course_id -> openedx_course_key."""
    if not MANIFEST_CSV.exists():
        print(f"WARN: {MANIFEST_CSV} not found; enrollment mapping will be empty", file=sys.stderr)
        return {}
    mapping: dict[str, str] = {}
    with MANIFEST_CSV.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            mct_id = row["mct_course_id"]
            key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
            mapping[mct_id] = key
    return mapping


def _load_enrollments(manifest: dict[str, str]) -> list[dict]:
    """Merge all per-course enrollment CSVs into one list."""
    if not ENROLLMENTS_DIR.exists():
        print(f"WARN: {ENROLLMENTS_DIR} not found; no enrollments will be generated", file=sys.stderr)
        return []

    # Build course_name -> course_key from manifest values
    # The enrollment CSV has a "Course" column that is the course name; we need
    # the numeric course ID from the filename (course_N.csv) and cross-reference
    # with admin users data.
    # Strategy: use filename course_N.csv -> MCT course_id=N -> manifest key.
    result: list[dict] = []
    csv_files = sorted(ENROLLMENTS_DIR.glob("course_*.csv"))

    for csv_file in csv_files:
        # Filename: course_279.csv → MCT course_id = 279
        m = re.match(r"course_(\d+)\.csv$", csv_file.name)
        if not m:
            continue
        mct_id_int = int(m.group(1))

        # Try to find matching course key from manifest
        # Manifest uses human-readable IDs (MCT1-EN, MCT2-VI, etc.), not numeric IDs.
        # We will look up via the admin categories_and_courses_v3 in a separate
        # mapping. For now, fall back to the MCT numeric id.
        # Load categories_and_courses_v3 to get the numeric_id->course_number mapping
        course_key = _mct_numeric_to_course_key(mct_id_int, manifest)
        if not course_key:
            continue  # Course not in manifest, skip

        with csv_file.open(newline="", encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh):
                clean = {k.strip().lstrip("\ufeff"): v.strip() for k, v in row.items()}
                email = (clean.get("Contact") or "").strip().lower()
                if not email:
                    continue
                pct = clean.get("Course Completion Percentage", "0").strip() or "0"
                lessons = clean.get("Lessons Completed", "0").strip() or "0"
                result.append({
                    "email": email,
                    "course_id": course_key,
                    "mode": "audit",
                    "is_active": "true",
                    "mct_completion_pct": pct,
                    "mct_lessons_completed": lessons,
                })
    return result


# Cache the numeric id mapping to avoid re-reading the file each call
_NUMERIC_TO_KEY_CACHE: dict[int, str] | None = None


def _mct_numeric_to_course_key(mct_id: int, manifest: dict[str, str]) -> str:
    """Map a numeric MCT course ID to an Open edX course key.

    Uses categories_and_courses_v3.json to find which Offer (category) numeric
    ID corresponds to which manifest course_number, then resolves via the
    manifest.

    Falls back to empty string if not found.
    """
    global _NUMERIC_TO_KEY_CACHE
    if _NUMERIC_TO_KEY_CACHE is None:
        _NUMERIC_TO_KEY_CACHE = {}
        cats_path = RAW_API / "categories_and_courses_v3.json"
        if cats_path.exists():
            with cats_path.open(encoding="utf-8") as fh:
                data = json.load(fh)
            # Each CourseItem has Id (module/course id), ParentId (category id)
            # The OLX packages are built per-category, not per-module.
            # We need: numeric_category_id → manifest_course_number.
            # video_mapping_openedx.json has: category_id → openedx_course_id
            vm_path = EXPORTS_MCT / "video_mapping_openedx.json"
            if vm_path.exists():
                with vm_path.open(encoding="utf-8") as fh:
                    vm = json.load(fh)
                for cat_id_str, cat_data in vm.get("categories", {}).items():
                    oex = cat_data.get("openedx_course_id", "")
                    cat_id = int(cat_id_str) if cat_id_str.isdigit() else None
                    if cat_id and oex:
                        # oex is like course-v1:MEREKA+MCT1-EN+course
                        m = re.search(r"\+([^+]+)\+course", oex)
                        if m:
                            _NUMERIC_TO_KEY_CACHE[cat_id] = oex

            # Also map CourseItems to their parent category -> course key
            # (some enrollment CSVs are per-module, not per-category)
            for item in data.get("CourseItems", []):
                item_id = item.get("Id")
                parent_id = item.get("ParentId")
                if item_id and parent_id:
                    if parent_id in _NUMERIC_TO_KEY_CACHE:
                        _NUMERIC_TO_KEY_CACHE[item_id] = _NUMERIC_TO_KEY_CACHE[parent_id]

    return _NUMERIC_TO_KEY_CACHE.get(mct_id, "")


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------

USERS_FIELDS = ["username", "email", "name", "country", "gender", "year_of_birth", "is_active", "password"]
ENROLLMENTS_FIELDS = ["email", "course_id", "mode", "is_active", "mct_completion_pct", "mct_lessons_completed"]


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict], dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would write {len(rows)} rows to {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  Wrote {len(rows)} rows → {path}")


def _write_json(path: Path, data: Any, dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would write {len(data)} records to {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print(f"  Wrote {len(data)} records → {path}")


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def run(users_only: bool = False, dry_run: bool = False) -> None:
    """Build Open edX import files from MCT export data."""

    print("Loading MCT admin users...")
    admin_users = _load_admin_users()
    print(f"  Loaded {len(admin_users)} users")

    print("Loading demographic data from reports_users.csv...")
    demographics = _load_reports_users()
    print(f"  Loaded demographics for {len(demographics)} emails")

    print("Building user records...")
    user_rows: list[dict] = []
    profile_records: list[dict] = []
    taken_usernames: set[str] = set()

    for user in admin_users:
        email = (user.get("EmailAddress") or "").strip().lower()
        if not email:
            continue

        first = (user.get("FirstName") or "").strip()
        last = (user.get("LastName") or "").strip()
        full_name = f"{first} {last}".strip() or email.split("@")[0]
        org_id = user.get("OrganizationId", 0)
        is_active = "true" if user.get("IsActive", True) else "false"

        # Demographics from reports CSV
        demo = demographics.get(email, {})
        gender_raw = (demo.get("Gender") or "").strip()
        dob_raw = (demo.get("When were you born?") or "").strip()
        country_raw = (demo.get("Which Country are you from?") or "").strip()
        university = (demo.get("University") or "").strip()
        linkedin = (demo.get("Linkedin Profile Link") or "").strip()
        learning_pathway = (demo.get("Which learning pathway are you interested in?") or "").strip()

        # Resolve country: prefer demographics CSV, fall back to org mapping
        country = ""
        if country_raw:
            # Normalise to ISO-2 if it's a full name (rough mapping)
            _COUNTRY_NAME_MAP = {
                "indonesia": "ID", "vietnam": "VN", "viet nam": "VN",
                "thailand": "TH", "cambodia": "KH", "malaysia": "MY",
                "china": "CN", "philippines": "PH",
            }
            country = _COUNTRY_NAME_MAP.get(country_raw.lower(), country_raw[:2].upper())
        if not country:
            country = ORG_TO_COUNTRY.get(org_id, "")

        gender = _normalise_gender(gender_raw)
        year_of_birth = _parse_year_of_birth(dob_raw)

        # Username: use email prefix, sanitised
        email_prefix = email.split("@")[0]
        base_username = _sanitise_username(email_prefix)
        username = _make_unique_username(base_username, taken_usernames)
        taken_usernames.add(username.lower())

        user_rows.append({
            "username": username,
            "email": email,
            "name": full_name,
            "country": country,
            "gender": gender,
            "year_of_birth": year_of_birth,
            "is_active": is_active,
            "password": "",
        })

        profile_records.append({
            "email": email,
            "username": username,
            "meta": {
                "mct_user_id": user.get("Id"),
                "mct_org_id": org_id,
                "university": university,
                "linkedin": linkedin,
                "learning_pathway": learning_pathway,
            },
        })

    print(f"  Built {len(user_rows)} user records")

    print("Writing output files...")
    _write_csv(OUTPUT_DIR / "users_import.csv", USERS_FIELDS, user_rows, dry_run)
    _write_json(OUTPUT_DIR / "user_profiles.json", profile_records, dry_run)

    if users_only:
        print("--users-only: skipping enrollments")
        return

    print("Loading course manifest...")
    manifest = _load_manifest()
    print(f"  Manifest: {len(manifest)} courses")

    print("Loading enrollment CSVs...")
    enrollments = _load_enrollments(manifest)
    print(f"  Loaded {len(enrollments)} enrollment rows")

    print("Writing enrollments...")
    _write_csv(OUTPUT_DIR / "enrollments_import.csv", ENROLLMENTS_FIELDS, enrollments, dry_run)

    print("\nDone.")
    if not dry_run:
        print(f"Output directory: {OUTPUT_DIR}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Map MCT users and enrollments to Open edX import format.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--users-only",
        action="store_true",
        help="Generate only users_import.csv and user_profiles.json (skip enrollments)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be generated without writing files",
    )
    args = parser.parse_args()

    run(users_only=args.users_only, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
