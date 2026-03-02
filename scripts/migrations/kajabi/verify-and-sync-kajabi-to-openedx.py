#!/usr/bin/env python3
"""
End-to-end verification and sync tool for Kajabi → Open edX migration.

This script:
1. Exports enrollments and certificates from Open edX
2. Compares with Kajabi data (source of truth)
3. Identifies discrepancies
4. Generates fix scripts to sync missing data
5. Creates comprehensive reports

Usage:
    python tools/verify-and-sync-kajabi-to-openedx.py \
        --django-settings lms.envs.tutor.production \
        --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
        --kajabi-users scripts/migrations/kajabi/output/users.csv \
        --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
        --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
        --output-dir scripts/migrations/kajabi/output/verification
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


def read_csv(path: Path) -> list[dict]:
    """Read CSV file."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)


def read_ndjson(path: Path) -> list[dict]:
    """Read NDJSON file."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def write_csv(rows: list[dict], fieldnames: list[str], path: Path) -> None:
    """Write CSV file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def normalize_email(email: str) -> str:
    """Normalize email for comparison."""
    return email.lower().strip() if email else ""


def export_openedx_enrollments(settings_module: str, output_path: Path) -> bool:
    """Export enrollments from Open edX using Django."""
    try:
        import django
        django.setup()

        from student.models import CourseEnrollment

        rows = []
        for enrollment in CourseEnrollment.objects.select_related("user").all():
            rows.append({
                "email": enrollment.user.email or "",
                "username": enrollment.user.username,
                "course_id": str(enrollment.course_id),
                "enrollment_date": enrollment.created.isoformat() if enrollment.created else "",
                "is_active": "True" if enrollment.is_active else "False",
            })

        write_csv(rows, ["email", "username", "course_id", "enrollment_date", "is_active"], output_path)
        print(f"✓ Exported {len(rows)} enrollments from Open edX")
        return True
    except Exception as e:
        print(f"✗ Failed to export Open edX enrollments: {e}")
        return False


def export_openedx_certificates(settings_module: str, output_path: Path) -> bool:
    """Export certificates from Open edX using Django."""
    try:
        import django
        django.setup()

        try:
            from certificates.models import GeneratedCertificate
        except ImportError:
            try:
                from lms.djangoapps.certificates.models import GeneratedCertificate
            except ImportError:
                from common.djangoapps.certificates.models import GeneratedCertificate

        rows = []
        for cert in GeneratedCertificate.objects.select_related("user").all():
            rows.append({
                "email": cert.user.email if cert.user else "",
                "username": cert.user.username if cert.user else "",
                "course_id": str(cert.course_id) if cert.course_id else "",
                "status": cert.status or "",
                "created_date": cert.created_date.isoformat() if cert.created_date else "",
                "modified_date": cert.modified_date.isoformat() if cert.modified_date else "",
                "grade": str(cert.grade) if cert.grade is not None else "",
                "mode": cert.mode or "",
            })

        write_csv(rows, ["email", "username", "course_id", "status", "created_date", "modified_date", "grade", "mode"], output_path)
        print(f"✓ Exported {len(rows)} certificates from Open edX")
        return True
    except Exception as e:
        print(f"✗ Failed to export Open edX certificates: {e}")
        return False


def build_email_mapping(users_path: Path) -> dict[str, str]:
    """Build mapping from contact_id/customer_id to email."""
    users = read_csv(users_path)
    mapping = {}
    for user in users:
        email = normalize_email(user.get("email", ""))
        contact_id = user.get("kajabi_contact_id", "")
        customer_id = user.get("kajabi_customer_id", "")
        if email:
            if contact_id:
                mapping[f"contact_{contact_id}"] = email
            if customer_id:
                mapping[f"customer_{customer_id}"] = email
    return mapping


def build_kajabi_enrollments(enrollments_path: Path, email_map: dict[str, str]) -> dict[str, set[str]]:
    """Build Kajabi enrollment map: course_id -> set of emails."""
    enrollments = read_csv(enrollments_path)
    kajabi_map: dict[str, set[str]] = defaultdict(set)

    for row in enrollments:
        email = normalize_email(row.get("email", ""))
        if not email:
            # Try to look up via contact_id or customer_id
            contact_id = row.get("contact_id", "")
            customer_id = row.get("customer_id", "")
            if contact_id:
                email = email_map.get(f"contact_{contact_id}", "")
            if not email and customer_id:
                email = email_map.get(f"customer_{customer_id}", "")

        course_id = row.get("course_id", "")
        if email and course_id:
            kajabi_map[course_id].add(email)

    return kajabi_map


def build_openedx_enrollments(enrollments_path: Path) -> dict[str, set[str]]:
    """Build Open edX enrollment map: course_id -> set of emails."""
    enrollments = read_csv(enrollments_path)
    openedx_map: dict[str, set[str]] = defaultdict(set)

    for row in enrollments:
        email = normalize_email(row.get("email", ""))
        course_id = row.get("course_id", "").strip()
        if email and course_id:
            openedx_map[course_id].add(email)

    return openedx_map


def build_kajabi_certificates(cert_path: Path) -> dict[str, set[str]]:
    """Build Kajabi certificate eligibility map: course_id -> set of emails."""
    certs = read_ndjson(cert_path)
    cert_map: dict[str, set[str]] = defaultdict(set)

    for cert in certs:
        email = normalize_email(cert.get("email", ""))
        course_id = cert.get("course_id", "")
        if email and course_id:
            cert_map[course_id].add(email)

    return cert_map


def build_openedx_certificates(cert_path: Path) -> dict[str, set[str]]:
    """Build Open edX certificate map: course_id -> set of emails."""
    certs = read_csv(cert_path)
    cert_map: dict[str, set[str]] = defaultdict(set)

    for cert in certs:
        email = normalize_email(cert.get("email", ""))
        course_id = cert.get("course_id", "").strip()
        status = cert.get("status", "").strip()
        # Only count successful certificates
        if email and course_id and status in ("downloadable", "generated", "certificate"):
            cert_map[course_id].add(email)

    return cert_map


def build_course_mapping(manifest_path: Path, prepared_enrollments_path: Path | None = None) -> dict[str, str]:
    """
    Build mapping from Kajabi course_id to Open edX course_id.

    First tries to use the prepared enrollments file to get actual course IDs,
    then falls back to manifest.
    """
    mapping = {}

    # If prepared enrollments file exists, use it to get actual course IDs
    if prepared_enrollments_path and prepared_enrollments_path.exists():
        for row in read_csv(prepared_enrollments_path):
            course_id = row.get("course_id", "").strip()
            if course_id and "MEKA-" in course_id:
                # Extract Kajabi ID from course number (MEKA-2147807941)
                try:
                    kajabi_id = course_id.split("MEKA-")[1].split("+")[0]
                    if kajabi_id:
                        mapping[kajabi_id] = course_id
                except IndexError:
                    pass

    # Fall back to manifest if needed
    for row in read_csv(manifest_path):
        kajabi_id = row.get("kajabi_course_id", "")
        if kajabi_id not in mapping:  # Don't override if we already have it
            org = row.get("org", "")
            number = row.get("course_number", "")
            run = row.get("run", "")
            if kajabi_id and org and number and run:
                openedx_id = f"course-v1:{org}+{number}+{run}"
                mapping[kajabi_id] = openedx_id

    return mapping


def compare_and_generate_fixes(
    kajabi_enrollments: dict[str, set[str]],
    openedx_enrollments: dict[str, set[str]],
    kajabi_certificates: dict[str, set[str]],
    openedx_certificates: dict[str, set[str]],
    course_mapping: dict[str, str],
    users_csv: Path,
    output_dir: Path,
) -> None:
    """Compare data and generate fix scripts."""

    # Build reverse mapping (openedx -> kajabi)
    {v: k for k, v in course_mapping.items()}

    # Find missing enrollments
    missing_enrollments = []
    enrollment_report = []

    for kajabi_course_id, kajabi_emails in kajabi_enrollments.items():
        openedx_course_id = course_mapping.get(kajabi_course_id, "")
        openedx_emails = openedx_enrollments.get(openedx_course_id, set()) if openedx_course_id else set()

        missing = kajabi_emails - openedx_emails
        extra = openedx_emails - kajabi_emails

        enrollment_report.append({
            "kajabi_course_id": kajabi_course_id,
            "openedx_course_id": openedx_course_id or "NOT_MAPPED",
            "kajabi_count": len(kajabi_emails),
            "openedx_count": len(openedx_emails),
            "missing_count": len(missing),
            "extra_count": len(extra),
        })

        # Add missing enrollments to fix list
        for email in missing:
            if openedx_course_id:  # Only add if course is mapped
                missing_enrollments.append({
                    "email": email,
                    "course_id": openedx_course_id,
                    "mode": "audit",
                    "is_active": "true",
                })

    # Find missing certificates
    missing_certificates = []
    certificate_report = []

    for kajabi_course_id, kajabi_emails in kajabi_certificates.items():
        openedx_course_id = course_mapping.get(kajabi_course_id, "")
        openedx_emails = openedx_certificates.get(openedx_course_id, set()) if openedx_course_id else set()

        missing = kajabi_emails - openedx_emails

        certificate_report.append({
            "kajabi_course_id": kajabi_course_id,
            "openedx_course_id": openedx_course_id or "NOT_MAPPED",
            "kajabi_eligible": len(kajabi_emails),
            "openedx_certificates": len(openedx_emails),
            "missing_count": len(missing),
        })

        # Add missing certificates to fix list
        for email in missing:
            if openedx_course_id:  # Only add if course is mapped
                missing_certificates.append({
                    "email": email,
                    "course_id": openedx_course_id,
                })

    # Write reports
    write_csv(enrollment_report, [
        "kajabi_course_id", "openedx_course_id", "kajabi_count",
        "openedx_count", "missing_count", "extra_count"
    ], output_dir / "enrollment_comparison.csv")

    write_csv(certificate_report, [
        "kajabi_course_id", "openedx_course_id", "kajabi_eligible",
        "openedx_certificates", "missing_count"
    ], output_dir / "certificate_comparison.csv")

    # Write fix scripts
    if missing_enrollments:
        write_csv(missing_enrollments, ["email", "course_id", "mode", "is_active"],
                 output_dir / "fix_missing_enrollments.csv")
        print(f"✓ Generated fix script for {len(missing_enrollments)} missing enrollments")

    if missing_certificates:
        write_csv(missing_certificates, ["email", "course_id"],
                 output_dir / "fix_missing_certificates.csv")
        print(f"✓ Generated fix script for {len(missing_certificates)} missing certificates")

    # Write summary
    with (output_dir / "summary.txt").open("w", encoding="utf-8") as f:
        f.write("Kajabi → Open edX Verification Summary\n")
        f.write("=" * 60 + "\n\n")

        f.write("ENROLLMENTS:\n")
        f.write(f"  Kajabi total: {sum(len(e) for e in kajabi_enrollments.values())}\n")
        f.write(f"  Open edX total: {sum(len(e) for e in openedx_enrollments.values())}\n")
        f.write(f"  Missing in Open edX: {len(missing_enrollments)}\n")
        f.write(f"  Courses with discrepancies: {sum(1 for r in enrollment_report if r['missing_count'] > 0)}\n\n")

        f.write("CERTIFICATES:\n")
        f.write(f"  Kajabi eligible: {sum(len(e) for e in kajabi_certificates.values())}\n")
        f.write(f"  Open edX certificates: {sum(len(e) for e in openedx_certificates.values())}\n")
        f.write(f"  Missing in Open edX: {len(missing_certificates)}\n")
        f.write(f"  Courses with discrepancies: {sum(1 for r in certificate_report if r['missing_count'] > 0)}\n\n")

        f.write("TOP 10 COURSES WITH MISSING ENROLLMENTS:\n")
        top_missing = sorted(enrollment_report, key=lambda x: x['missing_count'], reverse=True)[:10]
        for r in top_missing:
            f.write(f"  {r['kajabi_course_id']}: {r['missing_count']} missing\n")

        f.write("\nTOP 10 COURSES WITH MISSING CERTIFICATES:\n")
        top_certs = sorted(certificate_report, key=lambda x: x['missing_count'], reverse=True)[:10]
        for r in top_certs:
            f.write(f"  {r['kajabi_course_id']}: {r['missing_count']} missing\n")

    print(f"\n✓ Reports written to: {output_dir}")
    print(f"✓ Summary: {output_dir / 'summary.txt'}")


def generate_import_scripts(output_dir: Path) -> None:
    """Generate shell scripts to import fixes."""

    # Enrollment import script
    enrollments_csv = output_dir / "fix_missing_enrollments.csv"
    if enrollments_csv.exists():
        script_path = output_dir / "import_missing_enrollments.sh"
        with script_path.open("w") as f:
            f.write("#!/bin/bash\n")
            f.write("# Import missing enrollments from Kajabi\n\n")
            f.write("set -euo pipefail\n\n")
            f.write("source infrastructure/tutor/tutor-env.sh\n\n")
            f.write(f"tutor local run lms bash -c 'cat > /tmp/missing-enrollments.csv' < {enrollments_csv}\n")
            f.write("tutor local run lms ./manage.py lms bulk_enroll \\\n")
            f.write("  --csv /tmp/missing-enrollments.csv \\\n")
            f.write("  --settings=tutor.production \\\n")
            f.write("  --email-students False \\\n")
            f.write("  --auto-enroll True\n")
        script_path.chmod(0o755)
        print(f"✓ Generated import script: {script_path}")

    # Certificate import script
    certificates_csv = output_dir / "fix_missing_certificates.csv"
    if certificates_csv.exists():
        script_path = output_dir / "generate_missing_certificates.sh"
        with script_path.open("w") as f:
            f.write("#!/bin/bash\n")
            f.write("# Generate missing certificates from Kajabi eligibility\n\n")
            f.write("set -euo pipefail\n\n")
            f.write("source infrastructure/tutor/tutor-env.sh\n\n")
            f.write("# Read CSV and generate certificates per course\n")
            f.write("python3 <<'PYTHON'\n")
            f.write("import csv\n")
            f.write("from collections import defaultdict\n\n")
            f.write("courses = defaultdict(set)\n")
            f.write(f"with open('{certificates_csv}', 'r') as f:\n")
            f.write("    reader = csv.DictReader(f)\n")
            f.write("    for row in reader:\n")
            f.write("        courses[row['course_id']].add(row['email'])\n\n")
            f.write("for course_id in courses:\n")
            f.write("    print(f'Generating certificates for {course_id}...')\n")
            f.write("    # Note: Certificate generation requires course completion\n")
            f.write("    # This script lists courses that need certificates\n")
            f.write("    print(f'  Course: {course_id}, Users: {len(courses[course_id])}')\n")
            f.write("PYTHON\n")
            f.write("\n# To actually generate certificates, use:\n")
            f.write("# tutor local run lms ./manage.py lms generate_certificates \\\n")
            f.write("#   --course-id course-v1:ORG+NUMBER+RUN \\\n")
            f.write("#   --settings=tutor.production\n")
        script_path.chmod(0o755)
        print(f"✓ Generated certificate script: {script_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify and sync Kajabi → Open edX")
    parser.add_argument("--django-settings", help="Django settings module for Open edX export")
    parser.add_argument("--kajabi-enrollments", required=True, help="Kajabi enrollments CSV")
    parser.add_argument("--kajabi-users", required=True, help="Kajabi users CSV")
    parser.add_argument("--kajabi-certificates", required=True, help="Kajabi certificate eligibility NDJSON")
    parser.add_argument("--course-manifest", required=True, help="Course manifest CSV")
    parser.add_argument("--prepared-enrollments", help="Prepared enrollments CSV (to get actual course IDs)")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    parser.add_argument("--skip-openedx-export", action="store_true", help="Skip Open edX export (use existing files)")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("Kajabi → Open edX Verification & Sync")
    print("=" * 60)
    print()

    # Step 1: Export from Open edX
    openedx_enrollments_path = output_dir / "openedx_enrollments.csv"
    openedx_certificates_path = output_dir / "openedx_certificates.csv"

    if not args.skip_openedx_export and args.django_settings:
        print("Step 1: Exporting from Open edX...")
        if not export_openedx_enrollments(args.django_settings, openedx_enrollments_path):
            print("Warning: Could not export enrollments. Using existing file if available.")
        if not export_openedx_certificates(args.django_settings, openedx_certificates_path):
            print("Warning: Could not export certificates. Using existing file if available.")
        print()

    # Step 2: Load Kajabi data
    print("Step 2: Loading Kajabi data...")
    email_map = build_email_mapping(Path(args.kajabi_users))
    kajabi_enrollments = build_kajabi_enrollments(Path(args.kajabi_enrollments), email_map)
    kajabi_certificates = build_kajabi_certificates(Path(args.kajabi_certificates))

    # Build course mapping - use prepared enrollments if available to get actual course IDs
    prepared_enrollments_path = Path(args.prepared_enrollments) if args.prepared_enrollments else None
    if not prepared_enrollments_path:
        # Try default location
        default_prepared = Path("scripts/migrations/kajabi/output/openedx/enrollments_import.csv")
        if default_prepared.exists():
            prepared_enrollments_path = default_prepared

    course_mapping = build_course_mapping(Path(args.course_manifest), prepared_enrollments_path)
    print(f"  Kajabi enrollments: {sum(len(e) for e in kajabi_enrollments.values())} total")
    print(f"  Kajabi certificates: {sum(len(e) for e in kajabi_certificates.values())} eligible")
    print()

    # Step 3: Load Open edX data
    print("Step 3: Loading Open edX data...")
    openedx_enrollments = build_openedx_enrollments(openedx_enrollments_path) if openedx_enrollments_path.exists() else {}
    openedx_certificates = build_openedx_certificates(openedx_certificates_path) if openedx_certificates_path.exists() else {}
    print(f"  Open edX enrollments: {sum(len(e) for e in openedx_enrollments.values())} total")
    print(f"  Open edX certificates: {sum(len(e) for e in openedx_certificates.values())} total")
    print()

    # Step 4: Compare and generate fixes
    print("Step 4: Comparing and generating fixes...")
    compare_and_generate_fixes(
        kajabi_enrollments,
        openedx_enrollments,
        kajabi_certificates,
        openedx_certificates,
        course_mapping,
        Path(args.kajabi_users),
        output_dir,
    )
    print()

    # Step 5: Generate import scripts
    print("Step 5: Generating import scripts...")
    generate_import_scripts(output_dir)
    print()

    print("=" * 60)
    print("✓ Verification complete!")
    print(f"✓ Reports in: {output_dir}")
    print(f"✓ Fix scripts ready in: {output_dir}")
    print("=" * 60)


if __name__ == "__main__":
    main()

