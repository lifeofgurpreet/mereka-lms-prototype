#!/usr/bin/env python3
"""
Generate certificate breakdown by course for both Kajabi and Open edX.

Creates comparison reports showing:
- Certificates/eligibility per course in Kajabi
- Actual certificates per course in Open edX
- Comparison and discrepancies

Usage:
    python scripts/analytics/certificate-breakdown-by-course.py \
        --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
        --openedx-certificates exports/openedx/certificates.csv \
        --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
        --output-dir scripts/migrations/kajabi/output/certificate_breakdown
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


def read_ndjson(path: Path) -> list[dict]:
    """Read NDJSON file."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def read_csv(path: Path) -> list[dict]:
    """Read CSV file."""
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)


def normalize_email(email: str) -> str:
    """Normalize email for comparison."""
    return email.lower().strip() if email else ""


def build_course_mapping(manifest_path: Path) -> dict[str, str]:
    """Map Kajabi course_id to Open edX course_id."""
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


def build_kajabi_certificate_breakdown(cert_path: Path) -> dict[str, dict]:
    """
    Build certificate breakdown by course from Kajabi eligibility data.
    Returns: {course_id: {total_eligible, unique_users, sample_emails}}
    """
    certs = read_ndjson(cert_path)

    breakdown: dict[str, dict] = defaultdict(lambda: {
        'total_eligible': 0,
        'unique_users': set(),
        'sample_emails': [],
    })

    for cert in certs:
        course_id = cert.get("course_id", "")
        email = normalize_email(cert.get("email", ""))

        if course_id and email:
            breakdown[course_id]['total_eligible'] += 1
            breakdown[course_id]['unique_users'].add(email)
            if len(breakdown[course_id]['sample_emails']) < 10:
                breakdown[course_id]['sample_emails'].append(email)

    # Convert sets to counts
    result = {}
    for course_id, data in breakdown.items():
        result[course_id] = {
            'total_eligible': data['total_eligible'],
            'unique_users': len(data['unique_users']),
            'sample_emails': data['sample_emails'],
        }

    return result


def build_openedx_certificate_breakdown(cert_path: Path) -> dict[str, dict]:
    """
    Build certificate breakdown by course from Open edX certificates.
    Returns: {course_id: {total_certificates, unique_users, status_breakdown}}
    """
    certs = read_csv(cert_path)

    breakdown: dict[str, dict] = defaultdict(lambda: {
        'total_certificates': 0,
        'unique_users': set(),
        'status_breakdown': defaultdict(int),
        'sample_emails': [],
    })

    for cert in certs:
        course_id = cert.get("course_id", "").strip()
        email = normalize_email(cert.get("email", ""))
        status = cert.get("status", "").strip()

        if course_id:
            breakdown[course_id]['total_certificates'] += 1
            if email:
                breakdown[course_id]['unique_users'].add(email)
                if len(breakdown[course_id]['sample_emails']) < 10:
                    breakdown[course_id]['sample_emails'].append(email)
            if status:
                breakdown[course_id]['status_breakdown'][status] += 1

    # Convert sets to counts
    result = {}
    for course_id, data in breakdown.items():
        result[course_id] = {
            'total_certificates': data['total_certificates'],
            'unique_users': len(data['unique_users']),
            'status_breakdown': dict(data['status_breakdown']),
            'sample_emails': data['sample_emails'],
        }

    return result


def write_breakdown_report(
    kajabi_breakdown: dict[str, dict],
    openedx_breakdown: dict[str, dict],
    course_mapping: dict[str, str],
    courses_info: dict[str, dict],
    output_path: Path,
) -> None:
    """Write breakdown report to CSV."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        'kajabi_course_id',
        'course_title',
        'openedx_course_id',
        'kajabi_total_eligible',
        'kajabi_unique_users',
        'openedx_total_certificates',
        'openedx_unique_users',
        'openedx_status_breakdown',
        'discrepancy',
        'kajabi_sample_emails',
        'openedx_sample_emails',
    ]

    with output_path.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        # Get all courses
        all_courses = set(kajabi_breakdown.keys()) | set(openedx_breakdown.keys())

        for kajabi_course_id in sorted(all_courses):
            openedx_course_id = course_mapping.get(kajabi_course_id, "")
            kajabi_data = kajabi_breakdown.get(kajabi_course_id, {})
            openedx_data = openedx_breakdown.get(openedx_course_id, {}) if openedx_course_id else {}

            course_info = courses_info.get(kajabi_course_id, {})
            course_title = course_info.get('title', kajabi_course_id)

            kajabi_total = kajabi_data.get('total_eligible', 0)
            openedx_total = openedx_data.get('total_certificates', 0)
            discrepancy = kajabi_total - openedx_total

            writer.writerow({
                'kajabi_course_id': kajabi_course_id,
                'course_title': course_title,
                'openedx_course_id': openedx_course_id or 'NOT_MAPPED',
                'kajabi_total_eligible': kajabi_total,
                'kajabi_unique_users': kajabi_data.get('unique_users', 0),
                'openedx_total_certificates': openedx_total,
                'openedx_unique_users': openedx_data.get('unique_users', 0),
                'openedx_status_breakdown': json.dumps(openedx_data.get('status_breakdown', {})),
                'discrepancy': discrepancy,
                'kajabi_sample_emails': '; '.join(kajabi_data.get('sample_emails', [])[:5]),
                'openedx_sample_emails': '; '.join(openedx_data.get('sample_emails', [])[:5]),
            })


def load_course_titles(courses_path: Path) -> dict[str, dict]:
    """Load course titles from Kajabi courses file."""
    courses = {}
    if courses_path.exists():
        for line in courses_path.open():
            if not line.strip():
                continue
            try:
                course = json.loads(line)
                course_id = course.get('id', '')
                if course_id:
                    courses[course_id] = {
                        'title': course.get('attributes', {}).get('title', ''),
                    }
            except json.JSONDecodeError:
                continue
    return courses


def main() -> None:
    parser = argparse.ArgumentParser(description="Certificate breakdown by course")
    parser.add_argument("--kajabi-certificates", required=True, help="Kajabi certificate eligibility NDJSON")
    parser.add_argument("--openedx-certificates", help="Open edX certificates CSV")
    parser.add_argument("--course-manifest", required=True, help="Course manifest CSV")
    parser.add_argument("--kajabi-courses", help="Kajabi courses NDJSON (for titles)")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Loading data...")

    # Load course titles
    courses_info = {}
    if args.kajabi_courses:
        courses_info = load_course_titles(Path(args.kajabi_courses))
    else:
        # Try default location
        default_courses = Path("exports/kajabi/courses_index.ndjson")
        if default_courses.exists():
            courses_info = load_course_titles(default_courses)

    print(f"  Loaded {len(courses_info)} course titles")

    # Build Kajabi breakdown
    kajabi_breakdown = build_kajabi_certificate_breakdown(Path(args.kajabi_certificates))
    print(f"  Kajabi: {len(kajabi_breakdown)} courses, {sum(d['total_eligible'] for d in kajabi_breakdown.values())} total eligible")

    # Build Open edX breakdown
    openedx_breakdown = {}
    if args.openedx_certificates and Path(args.openedx_certificates).exists():
        openedx_breakdown = build_openedx_certificate_breakdown(Path(args.openedx_certificates))
        print(f"  Open edX: {len(openedx_breakdown)} courses, {sum(d['total_certificates'] for d in openedx_breakdown.values())} total certificates")
    else:
        print("  Open edX: No certificate file found (optional)")

    # Build course mapping
    course_mapping = build_course_mapping(Path(args.course_manifest))
    print(f"  Course mappings: {len(course_mapping)}")

    # Write breakdown report
    report_path = output_dir / "certificate_breakdown_by_course.csv"
    write_breakdown_report(
        kajabi_breakdown,
        openedx_breakdown,
        course_mapping,
        courses_info,
        report_path,
    )

    # Write summary
    summary_path = output_dir / "summary.txt"
    with summary_path.open('w', encoding='utf-8') as f:
        f.write("Certificate Breakdown by Course\n")
        f.write("=" * 60 + "\n\n")

        f.write("Kajabi Certificate Eligibility:\n")
        f.write(f"  Total courses: {len(kajabi_breakdown)}\n")
        f.write(f"  Total eligible: {sum(d['total_eligible'] for d in kajabi_breakdown.values())}\n")
        f.write(f"  Unique users: {sum(d['unique_users'] for d in kajabi_breakdown.values())}\n\n")

        if openedx_breakdown:
            f.write("Open edX Certificates:\n")
            f.write(f"  Total courses: {len(openedx_breakdown)}\n")
            f.write(f"  Total certificates: {sum(d['total_certificates'] for d in openedx_breakdown.values())}\n")
            f.write(f"  Unique users: {sum(d['unique_users'] for d in openedx_breakdown.values())}\n\n")

        f.write("Top 10 Courses by Kajabi Eligibility:\n")
        sorted_courses = sorted(
            kajabi_breakdown.items(),
            key=lambda x: x[1]['total_eligible'],
            reverse=True
        )[:10]
        for course_id, data in sorted_courses:
            title = courses_info.get(course_id, {}).get('title', course_id)
            f.write(f"  {title[:50]}: {data['total_eligible']} eligible ({data['unique_users']} users)\n")

    print(f"\n✓ Breakdown report written to: {report_path}")
    print(f"✓ Summary written to: {summary_path}")


if __name__ == "__main__":
    main()




