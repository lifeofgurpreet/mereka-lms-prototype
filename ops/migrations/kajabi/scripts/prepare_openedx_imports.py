#!/usr/bin/env python3
"""Prepare CSVs that match Open edX's built-in import commands."""

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


def build_user_maps(users_csv: Path) -> Dict[str, dict]:
    by_contact: Dict[str, dict] = {}
    by_customer: Dict[str, dict] = {}
    for row in read_csv(users_csv):
        if row.get("kajabi_contact_id"):
            by_contact[row["kajabi_contact_id"]] = row
        if row.get("kajabi_customer_id"):
            by_customer[row["kajabi_customer_id"]] = row
    return {"contact": by_contact, "customer": by_customer}


def build_course_key_map(manifest_csv: Path) -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    for row in read_csv(manifest_csv):
        kajabi_id = row["kajabi_course_id"]
        course_key = f"course-v1:{row['org']}+{row['course_number']}+{row['run']}"
        mapping[kajabi_id] = course_key
    return mapping


def create_users_import(users_csv: Path, output_csv: Path) -> None:
    rows = []
    for row in read_csv(users_csv):
        subscribed = str(row.get("subscribed", "")).lower()
        rows.append(
            {
                "email": row.get("email", ""),
                "username": row.get("username", ""),
                "full_name": row.get("full_name", ""),
                "password": "",  # Tutor will auto-generate reset emails
                "roles": "",
                "is_active": "true" if subscribed not in ("false", "0", "") else "false",
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
    user_maps: Dict[str, Dict[str, dict]],
    course_map: Dict[str, str],
    output_csv: Path,
) -> None:
    rows = []
    skipped = 0
    for row in read_csv(enrollments_csv):
        course_id = (row.get("course_id") or row.get("product_id") or "").strip()
        if not course_id or course_id not in course_map:
            skipped += 1
            continue
        contact_id = row.get("contact_id")
        customer_id = row.get("customer_id")
        user = None
        if contact_id and contact_id in user_maps["contact"]:
            user = user_maps["contact"][contact_id]
        elif customer_id and customer_id in user_maps["customer"]:
            user = user_maps["customer"][customer_id]
        if not user or not user.get("email"):
            skipped += 1
            continue
        is_active = str(row.get("is_active", "")).lower() in ("true", "1")
        rows.append(
            {
                "email": user["email"],
                "username": user["username"],
                "course_id": course_map[course_id],
                "mode": "audit",
                "is_active": "true" if is_active else "false",
            }
        )
    write_csv(output_csv, ["email", "username", "course_id", "mode", "is_active"], rows)
    print(f"Enrollments written to {output_csv} (skipped {skipped} rows without email/course match)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Open edX-ready CSVs")
    parser.add_argument("--output-root", required=True, help="ops/migrations/kajabi/output directory")
    parser.add_argument(
        "--manifest",
        required=True,
        help="Path to course_packages_manifest.csv produced by build_course_packages.py",
    )
    args = parser.parse_args()

    root = Path(args.output_root)
    manifest_csv = Path(args.manifest)
    users_csv = root / "users.csv"
    enrollments_csv = root / "enrollments.csv"
    openedx_dir = root / "openedx"
    openedx_dir.mkdir(parents=True, exist_ok=True)

    user_maps = build_user_maps(users_csv)
    course_map = build_course_key_map(manifest_csv)

    create_users_import(users_csv, openedx_dir / "users_import.csv")
    create_enrollments_import(
        enrollments_csv,
        user_maps,
        course_map,
        openedx_dir / "enrollments_import.csv",
    )

    print("Open edX CSVs generated in", openedx_dir)


if __name__ == "__main__":
    main()
