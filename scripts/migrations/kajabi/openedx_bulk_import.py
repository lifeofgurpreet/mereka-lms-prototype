#!/usr/bin/env python3
"""Utility helpers to import Kajabi CSVs directly into Open edX via Django."""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
from dataclasses import dataclass, field


def bootstrap(settings_module: str) -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", settings_module)
    import django

    django.setup()
    suppress_tracking()


def suppress_tracking() -> None:
    logging.getLogger("tracking").setLevel(logging.ERROR)
    logging.getLogger("eventtracking").setLevel(logging.ERROR)
    logging.getLogger("common.djangoapps.student.models").setLevel(logging.ERROR)
    try:
        from eventtracking import tracker

        tracker.get_tracker().subscribers = []  # type: ignore[attr-defined]
    except Exception:
        pass


def sanitize_text(value: str | None) -> str:
    if not value:
        return ""
    return "".join(ch for ch in value if ord(ch) <= 0xFFFF)


@dataclass
class ImportStats:
    processed: int = 0
    created: int = 0
    updated: int = 0
    skipped: int = 0
    failed: int = 0
    start_offset: int = 0
    last_offset: int = 0
    errors: list[str] = field(default_factory=list)

    def __str__(self) -> str:  # pragma: no cover
        return (
            f"processed={self.processed} created={self.created} updated={self.updated} "
            f"skipped={self.skipped} failed={self.failed} start={self.start_offset} "
            f"last={self.last_offset}"
        )


def load_csv_rows(csv_path: str, start: int, limit: int | None):
    with open(csv_path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for idx, row in enumerate(reader):
            if idx < start:
                continue
            consumed = idx - start
            if limit is not None and consumed >= limit:
                break
            yield idx, row


def import_users(csv_path: str, settings_module: str, start: int, limit: int | None) -> ImportStats:
    bootstrap(settings_module)
    from common.djangoapps.student.models import UserProfile
    from django.contrib.auth import get_user_model
    from django.db import IntegrityError

    stats = ImportStats(start_offset=start)
    User = get_user_model()

    for idx, row in load_csv_rows(csv_path, start, limit):
        try:
            email = (row.get("email") or "").strip().lower()
            username = (row.get("username") or "").strip()
            full_name = sanitize_text(row.get("full_name"))
            country = (row.get("country") or "").strip().upper()
            is_active = str(row.get("is_active", "true")).lower() not in ("false", "0")
            if not email or not username:
                stats.skipped += 1
                continue

            defaults = {
                "email": email,
                "is_active": is_active,
            }
            try:
                user, created = User.objects.update_or_create(username=username, defaults=defaults)
            except IntegrityError as err:
                message = str(err)
                if "auth_user.email" in message:
                    existing = User.objects.filter(email=email).first()
                    if not existing:
                        stats.failed += 1
                        stats.errors.append(
                            f"row={idx} user={username} error={err}"
                        )
                        continue

                    user = existing
                    created = False

                    username_changed = False
                    if username and user.username != username:
                        username_conflict = (
                            User.objects.filter(username=username)
                            .exclude(id=user.id)
                            .exists()
                        )
                        if not username_conflict:
                            user.username = username
                            username_changed = True

                    fields_to_update: list[str] = []
                    if user.email != email:
                        user.email = email
                        fields_to_update.append("email")
                    if user.is_active != is_active:
                        user.is_active = is_active
                        fields_to_update.append("is_active")
                    if username_changed:
                        fields_to_update.append("username")
                    if fields_to_update:
                        user.save(update_fields=fields_to_update)
                else:
                    stats.failed += 1
                    stats.errors.append(
                        f"row={idx} user={username} error={err}"
                    )
                    continue

            if created:
                user.set_unusable_password()
                user.save()
            elif user.email != email or user.is_active != is_active:
                user.email = email
                user.is_active = is_active
                user.save(update_fields=["email", "is_active"])

            profile, _ = UserProfile.objects.get_or_create(user=user)
            if full_name:
                profile.name = full_name
            if country:
                profile.country = country
            meta = profile.meta or {}
            if isinstance(meta, str):
                try:
                    meta = json.loads(meta)
                except Exception:
                    meta = {}
            meta.update({
                "kajabi_contact_id": row.get("kajabi_contact_id"),
                "kajabi_customer_id": row.get("kajabi_customer_id"),
            })
            profile.meta = meta
            profile.save()

            if created:
                stats.created += 1
            else:
                stats.updated += 1
            stats.processed += 1
        except Exception as err:  # pragma: no cover
            stats.failed += 1
            stats.errors.append(f"row={idx} user={row.get('username')} error={err}")

    stats.last_offset = start + stats.processed
    return stats


def import_enrollments(csv_path: str, settings_module: str, start: int, limit: int | None) -> ImportStats:
    bootstrap(settings_module)
    from common.djangoapps.student.models import CourseEnrollment
    from django.contrib.auth import get_user_model
    from opaque_keys.edx.keys import CourseKey
    from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

    stats = ImportStats(start_offset=start)
    User = get_user_model()

    for idx, row in load_csv_rows(csv_path, start, limit):
        try:
            email = (row.get("email") or "").strip().lower()
            course_id = (row.get("course_id") or "").strip()
            if not email or not course_id:
                stats.skipped += 1
                continue
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                stats.skipped += 1
                if stats.skipped <= 10 or idx % 5000 == 0:
                    print(f"Row {idx}: user not found for email {email}, skipping")
                continue
            try:
                course_key = CourseKey.from_string(course_id)
            except Exception as err:  # pragma: no cover
                stats.skipped += 1
                if stats.skipped <= 10:
                    print(f"Row {idx}: invalid course key {course_id}: {err}")
                continue

            if not CourseOverview.objects.filter(id=course_key).exists():
                stats.skipped += 1
                if stats.skipped <= 10 or idx % 5000 == 0:
                    print(f"Row {idx}: course not found for key {course_id}, skipping")
                continue

            mode = (row.get("mode") or "audit").strip() or "audit"
            is_active = str(row.get("is_active", "true")).lower() not in ("false", "0")

            try:
                CourseEnrollment.enroll(user, course_key, mode=mode, check_access=False)
                if not is_active:
                    CourseEnrollment.unenroll(user, course_key, skip_refund=True)
            except Exception as err:
                message = str(err).lower()
                if "course" in message and ("not found" in message or "does not exist" in message):
                    stats.skipped += 1
                    if stats.skipped <= 10 or idx % 5000 == 0:
                        print(f"Row {idx}: course enrollment skipped for {course_id}: {err}")
                    continue
                stats.failed += 1
                stats.errors.append(f"row={idx} email={email} error={err}")
                continue

            stats.updated += 1
            stats.processed += 1
        except Exception as err:  # pragma: no cover
            stats.failed += 1
            stats.errors.append(f"row={idx} email={row.get('email')} error={err}")

    stats.last_offset = start + stats.processed
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Kajabi CSVs into Open edX")
    subparsers = parser.add_subparsers(dest="command", required=True)

    user_parser = subparsers.add_parser("users", help="Import users from CSV")
    user_parser.add_argument("--csv", required=True, help="Path to users_import.csv")
    user_parser.add_argument("--settings", default="lms.envs.tutor.production")
    user_parser.add_argument("--offset", type=int, default=None, help="Row offset to start from")
    user_parser.add_argument("--limit", type=int, default=None, help="Maximum rows to process in this batch")
    user_parser.add_argument("--state-file", help="Optional file to store last processed offset")

    enr_parser = subparsers.add_parser("enrollments", help="Import enrollments from CSV")
    enr_parser.add_argument("--csv", required=True, help="Path to enrollments_import.csv")
    enr_parser.add_argument("--settings", default="lms.envs.tutor.production")
    enr_parser.add_argument("--offset", type=int, default=None)
    enr_parser.add_argument("--limit", type=int, default=None)
    enr_parser.add_argument("--state-file", help="Optional file to store last processed offset")

    args = parser.parse_args()

    start_offset = args.offset if args.offset is not None else 0
    if args.offset is None and args.state_file and os.path.exists(args.state_file):
        try:
            with open(args.state_file, encoding="utf-8") as sf:
                start_offset = int(sf.read().strip() or start_offset)
        except Exception:
            pass

    if args.command == "users":
        stats = import_users(args.csv, args.settings, start_offset, args.limit)
    else:
        stats = import_enrollments(args.csv, args.settings, start_offset, args.limit)

    print(stats)

    if args.state_file:
        with open(args.state_file, "w", encoding="utf-8") as sf:
            sf.write(str(stats.last_offset))


if __name__ == "__main__":
    main()
