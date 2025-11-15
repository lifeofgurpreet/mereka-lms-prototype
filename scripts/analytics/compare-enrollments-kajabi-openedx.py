#!/usr/bin/env python3
"""
Compare enrollments between Kajabi and Open edX.

Generates a comparison report showing:
- Enrollments per course in Kajabi vs Open edX
- Discrepancies (missing enrollments, extra enrollments)
- Certificate eligibility vs actual certificates

Usage:
    python scripts/analytics/compare-enrollments-kajabi-openedx.py \
        --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
        --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
        --openedx-enrollments exports/openedx/enrollments.csv \
        --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
        --output-dir ops/migrations/kajabi/output/comparison
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Set


def read_csv(path: Path) -> List[dict]:
    """Read CSV file into list of dicts."""
    with path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)


def read_ndjson(path: Path) -> List[dict]:
    """Read NDJSON file into list of dicts."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def normalize_email(email: str) -> str:
    """Normalize email for comparison."""
    return email.lower().strip() if email else ""


def build_course_mapping(manifest_path: Path) -> Dict[str, str]:
    """Build mapping from Kajabi course_id to Open edX course_id."""
    mapping = {}
    if manifest_path.exists():
        for row in read_csv(manifest_path):
            kajabi_id = row.get("kajabi_course_id", "")
            org = row.get("org", "")
            number = row.get("course_number", "")
            run = row.get("run", "")
            if kajabi_id and org and number and run:
                openedx_id = f"course-v1:{org}+{number}+{run}"
                mapping[kajabi_id] = openedx_id
    return mapping


def build_kajabi_enrollments(enrollments_path: Path, users_path: Path | None = None) -> Dict[str, Set[str]]:
    """
    Build enrollment map: course_id -> set of emails.
    Uses contact_id/customer_id to look up email from users CSV.
    """
    enrollments = read_csv(enrollments_path)
    
    # Build contact/customer -> email mapping
    email_map: Dict[str, str] = {}
    if users_path and users_path.exists():
        users = read_csv(users_path)
        for user in users:
            email = normalize_email(user.get("email", ""))
            contact_id = user.get("kajabi_contact_id", "")
            customer_id = user.get("kajabi_customer_id", "")
            if email:
                if contact_id:
                    email_map[f"contact_{contact_id}"] = email
                if customer_id:
                    email_map[f"customer_{customer_id}"] = email
    
    kajabi_map: Dict[str, Set[str]] = defaultdict(set)
    
    for row in enrollments:
        # Try to get email directly first
        email = normalize_email(row.get("email", ""))
        
        # If no email, try to look up via contact_id or customer_id
        if not email:
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


def build_openedx_enrollments(enrollments_path: Path) -> Dict[str, Set[str]]:
    """Build enrollment map: course_id -> set of emails."""
    enrollments = read_csv(enrollments_path)
    openedx_map: Dict[str, Set[str]] = defaultdict(set)
    
    for row in enrollments:
        email = normalize_email(row.get("email", ""))
        course_id = row.get("course_id", "")
        if email and course_id:
            openedx_map[course_id].add(email)
    
    return openedx_map


def build_certificate_eligibility(cert_path: Path) -> Dict[str, Set[str]]:
    """Build certificate eligibility map: course_id -> set of emails."""
    certs = read_ndjson(cert_path)
    cert_map: Dict[str, Set[str]] = defaultdict(set)
    
    for cert in certs:
        email = normalize_email(cert.get("email", ""))
        course_id = cert.get("course_id", "")
        if email and course_id:
            cert_map[course_id].add(email)
    
    return cert_map


def compare_enrollments(
    kajabi_enrollments: Dict[str, Set[str]],
    openedx_enrollments: Dict[str, Set[str]],
    course_mapping: Dict[str, str],
) -> List[dict]:
    """Compare enrollments and generate report rows."""
    report_rows = []
    
    # Get all unique courses
    all_courses = set(kajabi_enrollments.keys()) | set(
        openedx_id for openedx_id in openedx_enrollments.keys()
    )
    
    for kajabi_course_id in sorted(all_courses):
        openedx_course_id = course_mapping.get(kajabi_course_id, "")
        
        kajabi_emails = kajabi_enrollments.get(kajabi_course_id, set())
        openedx_emails = openedx_enrollments.get(openedx_course_id, set()) if openedx_course_id else set()
        
        kajabi_count = len(kajabi_emails)
        openedx_count = len(openedx_emails)
        
        missing_in_openedx = kajabi_emails - openedx_emails
        extra_in_openedx = openedx_emails - kajabi_emails
        
        discrepancy = kajabi_count - openedx_count
        
        report_rows.append({
            "kajabi_course_id": kajabi_course_id,
            "openedx_course_id": openedx_course_id or "NOT_MAPPED",
            "kajabi_enrollments": kajabi_count,
            "openedx_enrollments": openedx_count,
            "discrepancy": discrepancy,
            "missing_in_openedx": len(missing_in_openedx),
            "extra_in_openedx": len(extra_in_openedx),
            "missing_emails": "; ".join(sorted(missing_in_openedx)[:10]),  # First 10
            "extra_emails": "; ".join(sorted(extra_in_openedx)[:10]),  # First 10
        })
    
    return report_rows


def write_comparison_report(
    report_rows: List[dict],
    output_path: Path,
    certificate_eligibility: Dict[str, Set[str]] | None = None,
) -> None:
    """Write comparison report to CSV."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    fieldnames = [
        "kajabi_course_id",
        "openedx_course_id",
        "kajabi_enrollments",
        "openedx_enrollments",
        "discrepancy",
        "missing_in_openedx",
        "extra_in_openedx",
        "certificate_eligible",
        "missing_emails",
        "extra_emails",
    ]
    
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        for row in report_rows:
            kajabi_course_id = row["kajabi_course_id"]
            if certificate_eligibility:
                cert_count = len(certificate_eligibility.get(kajabi_course_id, set()))
                row["certificate_eligible"] = cert_count
            else:
                row["certificate_eligible"] = ""
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare Kajabi and Open edX enrollments")
    parser.add_argument("--kajabi-enrollments", required=True, help="Kajabi enrollments CSV")
    parser.add_argument("--kajabi-users", help="Kajabi users CSV (for email lookup)")
    parser.add_argument("--kajabi-certificates", help="Kajabi certificate eligibility NDJSON")
    parser.add_argument("--openedx-enrollments", required=True, help="Open edX enrollments CSV")
    parser.add_argument("--course-manifest", required=True, help="Course manifest CSV")
    parser.add_argument("--output-dir", required=True, help="Output directory for reports")
    args = parser.parse_args()
    
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("Loading data...")
    course_mapping = build_course_mapping(Path(args.course_manifest))
    print(f"  Course mappings: {len(course_mapping)}")
    
    users_path = Path(args.kajabi_users) if args.kajabi_users else None
    kajabi_enrollments = build_kajabi_enrollments(Path(args.kajabi_enrollments), users_path)
    print(f"  Kajabi enrollments: {sum(len(e) for e in kajabi_enrollments.values())} total")
    
    openedx_enrollments = build_openedx_enrollments(Path(args.openedx_enrollments))
    print(f"  Open edX enrollments: {sum(len(e) for e in openedx_enrollments.values())} total")
    
    certificate_eligibility = None
    if args.kajabi_certificates and Path(args.kajabi_certificates).exists():
        certificate_eligibility = build_certificate_eligibility(Path(args.kajabi_certificates))
        print(f"  Certificate eligible: {sum(len(e) for e in certificate_eligibility.values())} total")
    
    print("\nComparing enrollments...")
    report_rows = compare_enrollments(kajabi_enrollments, openedx_enrollments, course_mapping)
    
    report_path = output_dir / "enrollment_comparison.csv"
    write_comparison_report(report_rows, report_path, certificate_eligibility)
    
    # Summary statistics
    total_discrepancy = sum(abs(r["discrepancy"]) for r in report_rows)
    courses_with_discrepancies = sum(1 for r in report_rows if r["discrepancy"] != 0)
    
    print(f"\n=== Comparison Summary ===")
    print(f"Total courses compared: {len(report_rows)}")
    print(f"Courses with discrepancies: {courses_with_discrepancies}")
    print(f"Total enrollment discrepancy: {total_discrepancy}")
    print(f"\nReport written to: {report_path}")
    
    # Write summary
    summary_path = output_dir / "summary.txt"
    with summary_path.open("w", encoding="utf-8") as f:
        f.write("Enrollment Comparison Summary\n")
        f.write("=" * 50 + "\n\n")
        f.write(f"Total courses: {len(report_rows)}\n")
        f.write(f"Courses with discrepancies: {courses_with_discrepancies}\n")
        f.write(f"Total discrepancy: {total_discrepancy}\n\n")
        f.write("Top 10 courses with largest discrepancies:\n")
        for row in sorted(report_rows, key=lambda x: abs(x["discrepancy"]), reverse=True)[:10]:
            f.write(f"  {row['kajabi_course_id']}: {row['discrepancy']:+d} "
                   f"(Kajabi: {row['kajabi_enrollments']}, Open edX: {row['openedx_enrollments']})\n")
    
    print(f"Summary written to: {summary_path}")


if __name__ == "__main__":
    main()

