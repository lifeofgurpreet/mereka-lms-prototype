#!/usr/bin/env python3
"""Issue certificates for Kajabi course completions in Open edX.

Reads completions.ndjson, maps tag prefixes to course keys, and creates
GeneratedCertificate records with downloadable status.

Must be run inside the LMS container (or via kubectl exec).

Usage:
    # Dry-run
    python issue_certificates.py --dry-run

    # Issue all
    python issue_certificates.py

    # Issue for specific email
    python issue_certificates.py --email gurpreet@biji-biji.com
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import uuid
from pathlib import Path


def load_mapping(path: str) -> dict[str, list[str]]:
    """Load tag prefix -> list of course keys mapping."""
    with open(path) as f:
        data = json.load(f)
    prefix_to_keys: dict[str, list[str]] = {}
    for m in data["mappings"]:
        prefix = m["prefix"]
        keys = []
        if "course_key_en" in m:
            keys.append(m["course_key_en"])
        prefix_to_keys[prefix] = keys
    return prefix_to_keys


def load_completions(path: str, email_filter: str | None = None) -> list[dict]:
    """Load course_completed records from completions.ndjson."""
    records = []
    with open(path) as f:
        for line in f:
            c = json.loads(line)
            if c.get("tag_type") != "course_completed":
                continue
            if email_filter and c.get("email", "").strip().lower() != email_filter.lower():
                continue
            records.append(c)
    return records


def main():
    parser = argparse.ArgumentParser(description="Issue certificates for Kajabi completions")
    parser.add_argument("--completions", required=True, help="Path to completions.ndjson")
    parser.add_argument("--mapping", required=True, help="Path to tag_prefix_to_course_mapping.json")
    parser.add_argument("--output", default="/tmp/certificates_issued.csv")
    parser.add_argument("--email", help="Only process this email")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--settings", default="tutor.production")
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    mapping = load_mapping(args.mapping)
    completions = load_completions(args.completions, args.email)
    print(f"Loaded {len(completions)} course_completed records, {len(mapping)} prefix mappings")

    if not args.dry_run:
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", args.settings)
        import django
        django.setup()
        from django.contrib.auth import get_user_model
        from opaque_keys.edx.keys import CourseKey
        from lms.djangoapps.certificates.models import GeneratedCertificate, CertificateStatuses
        User = get_user_model()

    pairs_seen: set[tuple[str, str]] = set()
    stats = {"issued": 0, "skipped_dup": 0, "skipped_no_mapping": 0,
             "skipped_no_user": 0, "failed": 0, "already_exists": 0}
    output_rows = []

    for i, c in enumerate(completions):
        if i < args.offset:
            continue
        if args.limit and (i - args.offset) >= args.limit:
            break

        email = (c.get("email") or "").strip().lower()
        prefix = c.get("course_prefix", "")
        name = c.get("name", "")
        if not email or not prefix:
            continue

        course_keys = mapping.get(prefix, [])
        if not course_keys:
            stats["skipped_no_mapping"] += 1
            continue

        for ck_str in course_keys:
            pair = (email, ck_str)
            if pair in pairs_seen:
                stats["skipped_dup"] += 1
                continue
            pairs_seen.add(pair)

            if args.dry_run:
                stats["issued"] += 1
                output_rows.append({"email": email, "course_key": ck_str, "status": "dry-run"})
                continue

            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                stats["skipped_no_user"] += 1
                continue

            try:
                ck = CourseKey.from_string(ck_str)
                cert, created = GeneratedCertificate.objects.update_or_create(
                    user=user,
                    course_id=ck,
                    defaults={
                        "status": CertificateStatuses.downloadable,
                        "mode": "honor",
                        "name": name or (user.profile.name if hasattr(user, "profile") else ""),
                        "verify_uuid": uuid.uuid4().hex[:32],
                        "grade": "1.0",
                    }
                )
                if created:
                    stats["issued"] += 1
                    output_rows.append({"email": email, "course_key": ck_str, "status": "issued"})
                else:
                    stats["already_exists"] += 1
                    output_rows.append({"email": email, "course_key": ck_str, "status": "updated"})
            except Exception as err:
                stats["failed"] += 1
                output_rows.append({"email": email, "course_key": ck_str, "status": f"failed: {err}"})

    print(f"\nResults: {json.dumps(stats, indent=2)}")

    if output_rows and args.output:
        with open(args.output, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["email", "course_key", "status"])
            writer.writeheader()
            writer.writerows(output_rows)
        print(f"Wrote {len(output_rows)} rows to {args.output}")


if __name__ == "__main__":
    main()
