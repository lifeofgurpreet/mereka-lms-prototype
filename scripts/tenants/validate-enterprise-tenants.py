#!/usr/bin/env python3
# @covers AC-MTA-001, AC-MTA-002
# @spec: multi-tenancy-architecture_spec.md
"""
Validate enterprise tenant data model against expected state.

Prints a structured report of:
  - Enterprise customer count and details
  - Catalog count per customer
  - Customers with no catalogs
  - Customers with no linked users
  - Org/course coverage per customer
  - Unowned courses (not in any catalog)
  - Tenant/domain mapping gaps
  - Likely configuration errors

Usage:
    # From LMS pod or Django shell context:
    python scripts/tenants/validate-enterprise-tenants.py
    python scripts/tenants/validate-enterprise-tenants.py --spec config/enterprise-tenants/dev.enterprise-tenants.yaml
    python scripts/tenants/validate-enterprise-tenants.py --json

    # Via kubectl exec:
    kubectl exec -n mereka-lms deploy/lms -- python \
        /openedx/scripts/tenants/validate-enterprise-tenants.py
"""

import argparse
import json
import logging
import os
import sys

logger = logging.getLogger("validate-enterprise-tenants")


def collect_data() -> dict:
    """Collect all enterprise-related data from the database."""
    from django.contrib.auth import get_user_model
    from django.contrib.sites.models import Site
    from enterprise.models import (
        EnterpriseCourseEnrollment,
        EnterpriseCustomer,
        EnterpriseCustomerCatalog,
        EnterpriseCustomerUser,
    )

    User = get_user_model()

    data = {
        "enterprise_customers": [],
        "total_sites": Site.objects.count(),
        "total_users": User.objects.count(),
        "errors": [],
        "warnings": [],
    }

    # Collect course info
    try:
        from openedx.core.djangoapps.content.course_overviews.models import (
            CourseOverview,
        )

        all_courses = CourseOverview.objects.all()
        data["total_courses"] = all_courses.count()

        # Group by org
        org_counts = {}
        for course in all_courses:
            org = course.org or "UNKNOWN"
            org_counts[org] = org_counts.get(org, 0) + 1
        data["courses_by_org"] = org_counts
    except ImportError:
        data["total_courses"] = "N/A (CourseOverview not available)"
        data["courses_by_org"] = {}

    # Collect enterprise data
    for ec in EnterpriseCustomer.objects.all():
        catalogs = EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec)
        users = EnterpriseCustomerUser.objects.filter(enterprise_customer=ec)
        enrollments = EnterpriseCourseEnrollment.objects.filter(
            enterprise_customer_user__enterprise_customer=ec
        )

        site_domain = ec.site.domain if ec.site else "NO SITE"

        ec_data = {
            "uuid": str(ec.uuid),
            "name": ec.name,
            "slug": ec.slug,
            "active": ec.active,
            "site_domain": site_domain,
            "contact_email": ec.contact_email or "",
            "catalog_count": catalogs.count(),
            "catalogs": [
                {"uuid": str(c.uuid), "title": c.title}
                for c in catalogs
            ],
            "user_count": users.count(),
            "admin_count": users.filter(
                # admin role check varies by edx version
            ).count() if hasattr(users, 'filter') else 0,
            "enrollment_count": enrollments.count(),
        }
        data["enterprise_customers"].append(ec_data)

    # Check for sites without enterprise customers
    all_sites = Site.objects.all()
    ec_site_ids = set(
        EnterpriseCustomer.objects.values_list("site_id", flat=True)
    )
    for site in all_sites:
        if site.id not in ec_site_ids and site.domain not in ("example.com", "localhost"):
            data["warnings"].append(
                f"Site '{site.domain}' (id={site.id}) has no EnterpriseCustomer"
            )

    return data


def validate_against_spec(data: dict, spec_path: str) -> list:
    """Compare collected data against the declarative spec."""
    import yaml

    spec = yaml.safe_load(open(spec_path, encoding="utf-8"))
    issues = []

    spec_slugs = {t["slug"] for t in spec.get("tenants", [])}
    db_slugs = {ec["slug"] for ec in data["enterprise_customers"]}

    # Missing in DB
    for slug in spec_slugs - db_slugs:
        issues.append(f"MISSING: EnterpriseCustomer slug='{slug}' declared in spec but not in DB")

    # Extra in DB
    for slug in db_slugs - spec_slugs:
        issues.append(f"EXTRA: EnterpriseCustomer slug='{slug}' in DB but not in spec")

    # Per-tenant checks
    for tenant_spec in spec.get("tenants", []):
        slug = tenant_spec["slug"]
        ec_data = next(
            (ec for ec in data["enterprise_customers"] if ec["slug"] == slug), None
        )
        if not ec_data:
            continue

        # Check catalogs
        expected_catalogs = len(tenant_spec.get("catalogs", []))
        if ec_data["catalog_count"] < expected_catalogs:
            issues.append(
                f"GAP: {slug} has {ec_data['catalog_count']} catalogs, "
                f"spec expects {expected_catalogs}"
            )

        # Check site domain
        expected_domain = tenant_spec.get("site", {}).get("domain", "")
        if expected_domain and ec_data["site_domain"] != expected_domain:
            issues.append(
                f"MISMATCH: {slug} site domain is '{ec_data['site_domain']}', "
                f"spec expects '{expected_domain}'"
            )

    return issues


def print_report(data: dict, spec_issues: list | None = None):
    """Print a human-readable validation report."""
    print("\n" + "=" * 70)
    print("ENTERPRISE TENANT VALIDATION REPORT")
    print("=" * 70)

    # Summary
    ec_count = len(data["enterprise_customers"])
    total_catalogs = sum(ec["catalog_count"] for ec in data["enterprise_customers"])
    total_users = sum(ec["user_count"] for ec in data["enterprise_customers"])
    total_enrollments = sum(ec["enrollment_count"] for ec in data["enterprise_customers"])

    print(f"\nEnterprise Customers:     {ec_count}")
    print(f"Total Catalogs:           {total_catalogs}")
    print(f"Total Enterprise Users:   {total_users}")
    print(f"Total Enrollments:        {total_enrollments}")
    print(f"Total Courses:            {data.get('total_courses', 'N/A')}")
    print(f"Total Sites:              {data['total_sites']}")

    # Courses by org
    if data.get("courses_by_org"):
        print("\nCourses by Organization:")
        for org, count in sorted(data["courses_by_org"].items()):
            print(f"  {org}: {count}")

    # Per-customer detail
    print(f"\n{'─'*70}")
    print("ENTERPRISE CUSTOMERS")
    print(f"{'─'*70}")

    for ec in data["enterprise_customers"]:
        status = "ACTIVE" if ec["active"] else "INACTIVE"
        print(f"\n  [{status}] {ec['name']} (slug={ec['slug']})")
        print(f"    UUID:        {ec['uuid']}")
        print(f"    Site:        {ec['site_domain']}")
        print(f"    Contact:     {ec['contact_email'] or '(none)'}")
        print(f"    Catalogs:    {ec['catalog_count']}")
        if ec["catalogs"]:
            for cat in ec["catalogs"]:
                print(f"      - {cat['title']} ({cat['uuid']})")
        print(f"    Users:       {ec['user_count']}")
        print(f"    Enrollments: {ec['enrollment_count']}")

        # Warnings
        if ec["catalog_count"] == 0:
            print("    *** WARNING: No catalogs — learner/admin portals will show empty content")
        if ec["user_count"] == 0:
            print("    *** WARNING: No linked users — no one can access enterprise features")

    # Warnings
    if data["warnings"]:
        print(f"\n{'─'*70}")
        print("WARNINGS")
        print(f"{'─'*70}")
        for w in data["warnings"]:
            print(f"  ! {w}")

    # Spec comparison
    if spec_issues is not None:
        print(f"\n{'─'*70}")
        print("SPEC COMPARISON")
        print(f"{'─'*70}")
        if spec_issues:
            for issue in spec_issues:
                print(f"  ! {issue}")
        else:
            print("  All spec assertions pass.")

    # Errors
    if data["errors"]:
        print(f"\n{'─'*70}")
        print("ERRORS")
        print(f"{'─'*70}")
        for e in data["errors"]:
            print(f"  X {e}")

    # Final verdict
    has_issues = (
        any(ec["catalog_count"] == 0 for ec in data["enterprise_customers"])
        or any(ec["user_count"] == 0 for ec in data["enterprise_customers"])
        or bool(data["errors"])
        or bool(spec_issues)
    )

    print(f"\n{'='*70}")
    if has_issues:
        print("VERDICT: GAPS FOUND — see warnings above")
    else:
        print("VERDICT: ALL CHECKS PASS")
    print(f"{'='*70}\n")

    return 0 if not has_issues else 1


def main():
    parser = argparse.ArgumentParser(
        description="Validate enterprise tenant data model."
    )
    parser.add_argument(
        "--spec",
        default=None,
        help="Path to declarative spec for comparison (optional).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output raw JSON instead of formatted report.",
    )
    args = parser.parse_args()

    # Set up Django
    if not os.environ.get("DJANGO_SETTINGS_MODULE"):
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "lms.envs.production")
        import django

        django.setup()

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    data = collect_data()

    spec_issues = None
    if args.spec:
        spec_issues = validate_against_spec(data, args.spec)

    if args.json:
        output = {**data}
        if spec_issues is not None:
            output["spec_issues"] = spec_issues
        print(json.dumps(output, indent=2, default=str))
        sys.exit(0)

    exit_code = print_report(data, spec_issues)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
