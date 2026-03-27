#!/usr/bin/env python3
"""Import MCT users and enrollments into Open edX via Django."""

from __future__ import annotations

import argparse
import csv
import hashlib
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
    """Remove non-BMP characters that cause MySQL issues."""
    if not value:
        return ""
    return "".join(ch for ch in value if ord(ch) <= 0xFFFF)


def make_unique_username(base_username: str, email: str) -> str:
    """Create a unique username by appending email hash if needed."""
    # Take first 6 chars of email hash
    email_hash = hashlib.md5(email.encode()).hexdigest()[:6]
    return f"{base_username}_{email_hash}"


@dataclass
class ImportStats:
    processed: int = 0
    created: int = 0
    updated: int = 0
    skipped: int = 0
    failed: int = 0
    username_conflicts: int = 0
    start_offset: int = 0
    last_offset: int = 0
    errors: list[str] = field(default_factory=list)

    def __str__(self) -> str:  # pragma: no cover
        return (
            f"processed={self.processed} created={self.created} updated={self.updated} "
            f"skipped={self.skipped} failed={self.failed} username_conflicts={self.username_conflicts} "
            f"start={self.start_offset} last={self.last_offset}"
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
    """Import MCT users from CSV.

    CSV Format:
    username,email,full_name,first_name,last_name,country,gender,dob,learning_pathways,mct_user_id
    """
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
            sanitize_text(row.get("first_name"))
            sanitize_text(row.get("last_name"))
            country = (row.get("country") or "").strip()[:2].upper() if row.get("country") else ""
            gender = (row.get("gender") or "").strip().lower()
            dob = (row.get("dob") or "").strip()
            learning_pathways = (row.get("learning_pathways") or "").strip()
            mct_user_id = (row.get("mct_user_id") or "").strip()

            if not email or not username:
                stats.skipped += 1
                if idx % 1000 == 0:
                    print(f"Row {idx}: Skipped - missing email or username")
                continue

            # Map gender to Open edX format (m/f/o)
            gender_map = {
                "man": "m",
                "male": "m",
                "woman": "f",
                "female": "f",
            }
            gender_code = gender_map.get(gender, "o") if gender else None

            # Try to create user with original username first
            user_created = False
            user = None
            original_username = username

            try:
                # Check if user with email already exists
                existing_user = User.objects.filter(email=email).first()

                if existing_user:
                    # User with this email exists, update them
                    user = existing_user
                    user_created = False

                    # If username is different, try to update (if no conflict)
                    if user.username != username:
                        username_conflict = (
                            User.objects.filter(username=username)
                            .exclude(id=user.id)
                            .exists()
                        )
                        if not username_conflict:
                            user.username = username
                        else:
                            stats.username_conflicts += 1

                    user.is_active = True
                    user.save()
                else:
                    # Try to create new user with original username
                    try:
                        user = User.objects.create_user(
                            username=username,
                            email=email,
                            is_active=True
                        )
                        user.set_unusable_password()
                        user.save()
                        user_created = True
                    except IntegrityError as err:
                        # Username conflict, try with unique username
                        if "auth_user.username" in str(err) or "UNIQUE constraint" in str(err):
                            username = make_unique_username(original_username, email)
                            stats.username_conflicts += 1
                            try:
                                user = User.objects.create_user(
                                    username=username,
                                    email=email,
                                    is_active=True
                                )
                                user.set_unusable_password()
                                user.save()
                                user_created = True
                            except Exception as err2:
                                stats.failed += 1
                                stats.errors.append(
                                    f"row={idx} user={original_username} email={email} error={err2}"
                                )
                                continue
                        else:
                            raise

                # Create or update profile
                profile, _ = UserProfile.objects.get_or_create(user=user)

                # Update profile fields
                if full_name:
                    profile.name = full_name
                if country and len(country) == 2:
                    profile.country = country
                if gender_code:
                    profile.gender = gender_code

                # Parse date of birth (format: DD/MM/YYYY)
                if dob:
                    try:
                        # Parse DD/MM/YYYY format
                        parts = dob.split('/')
                        if len(parts) == 3:
                            day, month, year = parts
                            # Convert to YYYY-MM-DD for database
                            profile.year_of_birth = int(year)
                    except Exception:
                        pass  # Skip invalid dates

                # Store MCT metadata
                meta = profile.meta or {}
                if isinstance(meta, str):
                    try:
                        meta = json.loads(meta)
                    except Exception:
                        meta = {}

                meta.update({
                    "mct_user_id": mct_user_id,
                    "mct_original_username": original_username if username != original_username else None,
                    "mct_learning_pathways": learning_pathways,
                })
                profile.meta = meta
                profile.save()

                if user_created:
                    stats.created += 1
                else:
                    stats.updated += 1
                stats.processed += 1

                # Progress reporting
                if stats.processed % 1000 == 0:
                    print(f"Processed {stats.processed} users (created={stats.created}, updated={stats.updated}, conflicts={stats.username_conflicts})")

            except Exception as err:
                stats.failed += 1
                stats.errors.append(f"row={idx} user={username} email={email} error={err}")
                if stats.failed <= 10:  # Only print first 10 errors
                    print(f"ERROR at row {idx}: {err}")

        except Exception as err:  # Outer exception handler
            stats.failed += 1
            stats.errors.append(f"row={idx} error={err}")
            if stats.failed <= 10:
                print(f"ERROR at row {idx}: {err}")

    stats.last_offset = start + stats.processed
    return stats


def import_enrollments(csv_path: str, settings_module: str, start: int, limit: int | None) -> ImportStats:
    """Import MCT enrollments from CSV.

    CSV Format:
    email,course_id,mode,is_active
    """
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
                if idx % 5000 == 0:
                    print(f"Row {idx}: User not found for email {email}")
                continue

            try:
                course_key = CourseKey.from_string(course_id)
            except Exception as err:
                stats.skipped += 1
                if stats.skipped <= 10:
                    print(f"Row {idx}: Invalid course_id {course_id}: {err}")
                continue

            if not CourseOverview.objects.filter(id=course_key).exists():
                stats.skipped += 1
                if stats.skipped <= 10 or idx % 5000 == 0:
                    print(f"Row {idx}: Course not found for key {course_id}, skipping")
                continue

            mode = (row.get("mode") or "audit").strip() or "audit"
            is_active = str(row.get("is_active", "true")).lower() not in ("false", "0")

            # Create enrollment
            # Note: get_or_create_enrollment returns just the enrollment, not (enrollment, created)
            # Check if enrollment already exists
            existing = CourseEnrollment.objects.filter(user=user, course_id=course_key).first()
            created = existing is None

            try:
                enrollment = CourseEnrollment.get_or_create_enrollment(user, course_key)
            except Exception as err:
                message = str(err).lower()
                if "course" in message and ("not found" in message or "does not exist" in message):
                    stats.skipped += 1
                    if stats.skipped <= 10 or idx % 5000 == 0:
                        print(f"Row {idx}: Enrollment skipped for missing course {course_id}: {err}")
                    continue
                raise
            if enrollment.mode != mode:
                enrollment.change_mode(mode)

            if is_active and not enrollment.is_active:
                enrollment.activate()
            elif not is_active and enrollment.is_active:
                enrollment.deactivate()

            if created:
                stats.created += 1
            else:
                stats.updated += 1
            stats.processed += 1

            if stats.processed % 5000 == 0:
                print(f"Processed {stats.processed} enrollments (created={stats.created}, updated={stats.updated})")

        except Exception as err:
            stats.failed += 1
            stats.errors.append(f"row={idx} email={row.get('email')} error={err}")
            if stats.failed <= 10:
                print(f"ERROR at row {idx}: {err}")

    stats.last_offset = start + stats.processed
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description="Import MCT CSVs into Open edX")
    subparsers = parser.add_subparsers(dest="command", required=True)

    user_parser = subparsers.add_parser("users", help="Import users from CSV")
    user_parser.add_argument("--csv", required=True, help="Path to users.csv")
    user_parser.add_argument("--settings", default="lms.envs.tutor.production")
    user_parser.add_argument("--offset", type=int, default=None, help="Row offset to start from")
    user_parser.add_argument("--limit", type=int, default=None, help="Maximum rows to process in this batch")
    user_parser.add_argument("--state-file", help="Optional file to store last processed offset")

    enr_parser = subparsers.add_parser("enrollments", help="Import enrollments from CSV")
    enr_parser.add_argument("--csv", required=True, help="Path to enrollments.csv")
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

    print(f"Starting import from offset {start_offset}, limit={args.limit}")

    if args.command == "users":
        stats = import_users(args.csv, args.settings, start_offset, args.limit)
    else:
        stats = import_enrollments(args.csv, args.settings, start_offset, args.limit)

    print(f"\n{'='*60}")
    print(f"IMPORT COMPLETE: {stats}")
    print(f"{'='*60}")

    if stats.errors:
        print("\nFirst 20 errors:")
        for err in stats.errors[:20]:
            print(f"  {err}")
        if len(stats.errors) > 20:
            print(f"  ... and {len(stats.errors) - 20} more errors")

    if args.state_file:
        with open(args.state_file, "w", encoding="utf-8") as sf:
            sf.write(str(stats.last_offset))
        print(f"\nState saved to {args.state_file}: offset={stats.last_offset}")


if __name__ == "__main__":
    main()
