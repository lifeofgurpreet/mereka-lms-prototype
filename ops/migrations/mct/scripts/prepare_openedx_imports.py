#!/usr/bin/env python3
"""Prepare CSVs that match Open edX's built-in import commands for MCT data."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Dict, Iterable


def read_csv(path: Path) -> Iterable[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            yield row


def write_csv(path: Path, fieldnames, rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def build_user_map(users_csv: Path) -> Dict[str, dict]:
    """Build a map of email -> user data."""
    by_email: Dict[str, dict] = {}
    for row in read_csv(users_csv):
        email = row.get("email", "").strip().lower()
        if email:
            by_email[email] = row
    return by_email


def build_course_key_map(manifest_csv: Path) -> Dict[str, str]:
    """Build a map of MCT course_id -> Open edX course key."""
    mapping: Dict[str, str] = {}
    for row in read_csv(manifest_csv):
        mct_id = row["mct_course_id"]
        course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
        mapping[mct_id] = course_key
    return mapping


def create_users_import(users_csv: Path, output_csv: Path) -> None:
    """Create Open edX users import CSV."""
    rows = []
    for row in read_csv(users_csv):
        email = row.get("email", "").strip()
        if not email:
            continue
        
        rows.append(
            {
                "email": email,
                "username": row.get("username", ""),
                "full_name": row.get("full_name", ""),
                "password": "",  # Tutor will auto-generate reset emails
                "roles": "",
                "is_active": "true",  # MCT users are active by default
                "country": row.get("country", ""),
            }
        )
    write_csv(
        output_csv,
        ["email", "username", "full_name", "password", "roles", "is_active", "country"],
        rows,
    )


def create_enrollments_import(
    enrollments_csv: Path,
    user_map: Dict[str, dict],
    course_map: Dict[str, str],
    output_csv: Path,
) -> None:
    """Create Open edX enrollments import CSV."""
    rows = []
    skipped = 0
    for row in read_csv(enrollments_csv):
        course_id = (row.get("course_id") or row.get("category_id") or "").strip()
        if not course_id or course_id not in course_map:
            skipped += 1
            continue
        
        email = row.get("email", "").strip().lower()
        if not email or email not in user_map:
            skipped += 1
            continue
        
        user = user_map[email]
        rows.append(
            {
                "email": email,
                "username": user.get("username", ""),
                "course_id": course_map[course_id],
                "mode": "audit",  # MCT courses are typically audit mode
                "is_active": "true",
            }
        )
    write_csv(output_csv, ["email", "username", "course_id", "mode", "is_active"], rows)
    print(f"Enrollments written to {output_csv} (skipped {skipped} rows without email/course match)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Open edX-ready CSVs from MCT data")
    parser.add_argument("--output-root", required=True, help="ops/migrations/mct/output directory")
    parser.add_argument(
        "--manifest",
        required=True,
        help="Path to course_packages_manifest.csv produced by build_course_packages.py",
    )
    args = parser.parse_args()

    root = Path(args.output_root)
    manifest_csv = Path(args.manifest)
    users_csv = root / "users.csv"
    # Prefer category-level enrollments file if present
    enrollments_csv = root / "enrollments_categories.csv"
    if not enrollments_csv.exists():
        enrollments_csv = root / "enrollments.csv"
    openedx_dir = root / "openedx"
    openedx_dir.mkdir(parents=True, exist_ok=True)

    user_map = build_user_map(users_csv)
    course_map = build_course_key_map(manifest_csv)

    create_users_import(users_csv, openedx_dir / "users_import.csv")
    create_enrollments_import(
        enrollments_csv,
        user_map,
        course_map,
        openedx_dir / "enrollments_import.csv",
    )

    print("Open edX CSVs generated in", openedx_dir)


if __name__ == "__main__":
    main()

