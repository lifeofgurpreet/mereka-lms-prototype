#!/usr/bin/env python3
"""Issue GeneratedCertificate records for Kajabi course completions.

Reads a CSV of completions exported from Kajabi, looks up users and courses in
Open edX, and creates (or skips existing) GeneratedCertificate rows with
status=downloadable.

Designed to run inside the LMS container via::

    python manage.py lms shell < /path/to/post_import_completions.py

Or equivalently via kubectl::

    kubectl exec -n mereka-lms-dev $LMS_POD -c lms -- \\
        python manage.py lms shell < scripts/migrations/post_import_completions.py

CSV format (completions_import.csv):
    email,course_id,completed,tag_name

Where course_id is already the Open edX course key, e.g.
    course-v1:MEREKA+F101-MS+course

Options are read from environment variables so the script is idempotent and
repeatable without editing:
    COMPLETIONS_CSV   Path to CSV inside the container (default: /tmp/kajabi_completions.csv)
    DRY_RUN           Set to "1" to skip writes (default: 0)
    BATCH_SIZE        DB commit batch size (default: 500)
    EMAIL_FILTER      Only process this single email address (optional)
    OUTPUT_CSV        Where to write the per-row result log (default: /tmp/cert_import_results.csv)
"""
from __future__ import annotations

import csv
import os
import sys
import uuid
from collections import Counter

# ---------------------------------------------------------------------------
# Configuration (from environment)
# ---------------------------------------------------------------------------
COMPLETIONS_CSV = os.environ.get("COMPLETIONS_CSV", "/tmp/kajabi_completions.csv")
DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "500"))
EMAIL_FILTER = os.environ.get("EMAIL_FILTER", "").strip().lower() or None
OUTPUT_CSV = os.environ.get("OUTPUT_CSV", "/tmp/cert_import_results.csv")

# ---------------------------------------------------------------------------
# Django imports (available when run inside manage.py lms shell)
# ---------------------------------------------------------------------------
from django.contrib.auth import get_user_model  # noqa: E402
from django.db import transaction  # noqa: E402
from lms.djangoapps.certificates.models import (  # noqa: E402
    CertificateStatuses,
    GeneratedCertificate,
)
from opaque_keys.edx.keys import CourseKey  # noqa: E402
from openedx.core.djangoapps.content.course_overviews.models import (  # noqa: E402
    CourseOverview,
)

User = get_user_model()

# ---------------------------------------------------------------------------
# Pre-load known courses and users to minimise DB round-trips
# ---------------------------------------------------------------------------
print("Loading available courses from Open edX...")
known_course_keys: set[str] = {
    str(pk) for pk in CourseOverview.objects.values_list("id", flat=True)
}
print(f"  {len(known_course_keys)} courses available in Open edX")

print("Loading existing certificates (for duplicate detection)...")
existing_certs: set[tuple[int, str]] = set(
    GeneratedCertificate.objects.values_list("user_id", "course_id")
)
print(f"  {len(existing_certs)} existing certificates found")

# ---------------------------------------------------------------------------
# Read the CSV
# ---------------------------------------------------------------------------
if not os.path.exists(COMPLETIONS_CSV):
    print(f"ERROR: CSV not found at {COMPLETIONS_CSV}", file=sys.stderr)
    print(
        "Copy it first:\n"
        "  kubectl cp exports/kajabi/openedx_import/completions_import.csv "
        "mereka-lms-dev/$LMS_POD:/tmp/kajabi_completions.csv -c lms",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"\nReading completions from {COMPLETIONS_CSV} ...")
completions: list[dict] = []
with open(COMPLETIONS_CSV, newline="", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        email = (row.get("email") or "").strip().lower()
        course_id = (row.get("course_id") or "").strip()
        completed = (row.get("completed") or "").strip().lower()
        tag_name = (row.get("tag_name") or "").strip()
        if not email or not course_id:
            continue
        if EMAIL_FILTER and email != EMAIL_FILTER:
            continue
        completions.append(
            {
                "email": email,
                "course_id": course_id,
                "completed": completed,
                "tag_name": tag_name,
            }
        )

print(f"  {len(completions)} rows loaded (EMAIL_FILTER={EMAIL_FILTER or 'none'})")

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
stats: Counter = Counter()
output_rows: list[dict] = []

# Cache: email -> User (or None sentinel)
_USER_NOT_FOUND = object()
user_cache: dict[str, object] = {}


def _get_user(email: str):
    if email not in user_cache:
        try:
            user_cache[email] = User.objects.get(email=email)
        except User.DoesNotExist:
            user_cache[email] = _USER_NOT_FOUND
    return user_cache[email]


def _get_display_name(user) -> str:
    try:
        return user.profile.name or user.username
    except Exception:
        return user.username


print(f"\nProcessing completions (DRY_RUN={DRY_RUN}, BATCH_SIZE={BATCH_SIZE}) ...")

# Track (user_id, course_id) pairs we've already queued in this run to deduplicate
# within the CSV itself (same user may appear twice for the same course).
seen_pairs: set[tuple[str, str]] = set()

batch: list[GeneratedCertificate] = []


def _flush_batch(batch: list) -> int:
    if not batch:
        return 0
    with transaction.atomic():
        GeneratedCertificate.objects.bulk_create(batch, ignore_conflicts=True)
    return len(batch)


for i, row in enumerate(completions, start=1):
    email = row["email"]
    course_id_str = row["course_id"]
    tag_name = row["tag_name"]

    # Deduplicate within run
    pair_key = (email, course_id_str)
    if pair_key in seen_pairs:
        stats["skipped_intrarun_dup"] += 1
        output_rows.append({**row, "result": "skipped:intrarun_dup"})
        continue
    seen_pairs.add(pair_key)

    # Course must exist in Open edX
    if course_id_str not in known_course_keys:
        stats["skipped_course_not_found"] += 1
        output_rows.append({**row, "result": "skipped:course_not_found"})
        continue

    # Parse the course key
    try:
        course_key = CourseKey.from_string(course_id_str)
    except Exception as exc:
        stats["error_bad_course_key"] += 1
        output_rows.append({**row, "result": f"error:bad_course_key:{exc}"})
        continue

    # Look up user
    user = _get_user(email)
    if user is _USER_NOT_FOUND:
        stats["skipped_user_not_found"] += 1
        output_rows.append({**row, "result": "skipped:user_not_found"})
        continue

    # Skip if cert already exists (pre-loaded set)
    if (user.id, course_id_str) in existing_certs:
        stats["skipped_already_exists"] += 1
        output_rows.append({**row, "result": "skipped:already_exists"})
        continue

    if DRY_RUN:
        stats["would_create"] += 1
        output_rows.append({**row, "result": "dry_run:would_create"})
        continue

    # Build the certificate object
    cert = GeneratedCertificate(
        user=user,
        course_id=course_key,
        status=CertificateStatuses.downloadable,
        mode="honor",
        name=_get_display_name(user),
        verify_uuid=uuid.uuid4().hex,
        grade="1.0",
        download_uuid="",
        download_url="",
        error_reason="",
    )
    batch.append(cert)
    # Mark as seen so we don't add it again even if the CSV has a duplicate row below
    existing_certs.add((user.id, course_id_str))
    stats["created"] += 1
    output_rows.append({**row, "result": "created"})

    # Flush on batch boundary
    if len(batch) >= BATCH_SIZE:
        _flush_batch(batch)
        batch.clear()
        print(f"  ... flushed batch at row {i}")

# Final flush
if batch:
    _flush_batch(batch)
    print(f"  ... flushed final batch ({len(batch)} records)")

# ---------------------------------------------------------------------------
# Write output CSV
# ---------------------------------------------------------------------------
with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
    fieldnames = ["email", "course_id", "completed", "tag_name", "result"]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(output_rows)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("CERTIFICATE IMPORT SUMMARY")
print("=" * 60)
for key, count in sorted(stats.items()):
    label = {
        "created": "Created",
        "would_create": "Would create (dry-run)",
        "skipped_already_exists": "Skipped (cert already exists)",
        "skipped_intrarun_dup": "Skipped (duplicate in CSV)",
        "skipped_user_not_found": "Skipped (user not in Open edX)",
        "skipped_course_not_found": "Skipped (course not in Open edX)",
        "error_bad_course_key": "Error (bad course key)",
    }.get(key, key)
    print(f"  {label:45s} {count:>6,}")
print("-" * 60)
print(f"  {'Total rows processed':45s} {sum(stats.values()):>6,}")
print(f"\nResults written to: {OUTPUT_CSV}")

final_count = GeneratedCertificate.objects.count()
print(f"Total certs in DB now: {final_count:,}")
