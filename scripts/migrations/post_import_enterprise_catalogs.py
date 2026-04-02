#!/usr/bin/env python3
"""
Create enterprise catalog assignments for Mereka LMS dev environment.

This script connects to the LMS pod via kubectl exec and creates
EnterpriseCustomerCatalog records so each tenant sees the right courses.

Catalog assignments:
  - SOF (Skill Our Future): All MCT courses + FOW courses (35 total)
  - BijiBiji (Biji-Biji Academy): UPAI courses (3 total: UPAI1-EN, UPAI2-EN, UPAI3-EN)
  - Mereka Academy: All courses via org key MEREKA (platform-wide visibility)

FOW course key prefixes: PB, PW, PF, SYFJ, F101, MYFC, SP, SYFC, TYJ, LLP, PP

The script is idempotent — safe to re-run. It will update the content_filter
on existing matching catalogs rather than creating duplicates.

Usage:
    python scripts/migrations/post_import_enterprise_catalogs.py [--dry-run] [--namespace NS]

Requirements:
    - kubectl context set to rke2-nonprod
    - python3 in PATH
    - kubectl in PATH
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import textwrap

# ---------------------------------------------------------------------------
# Enterprise customer UUIDs (dev environment, rke2-nonprod cluster)
# ---------------------------------------------------------------------------
ENTERPRISE_CUSTOMERS = {
    "mereka": {
        "uuid": "caee80bc-2e05-4b92-8ebe-d0ec045edaeb",
        "name": "Mereka Academy",
        "catalog_title": "Mereka Academy Full Catalog",
        "content_filter": {
            "content_type": "course",
            # All courses published under the MEREKA org
            "organizations.key": ["MEREKA"],
        },
        "description": "Platform-wide visibility: all MEREKA org courses",
    },
    "sof": {
        "uuid": "ef9e4eff-4c5d-464b-a650-2000bad56c99",
        "name": "Skill Our Future",
        "catalog_title": "Skill Our Future Catalog",
        # SOF sees MCT courses + FOW courses (everything except UPAI)
        # content_filter uses course_key__in with a list of exact keys
        # populated dynamically by the Django shell fragment below.
        "content_filter": None,  # Set dynamically in the Django snippet
        "description": "SOF: MCT courses + FOW courses (excludes UPAI)",
    },
    "bijibiji": {
        "uuid": "7ad11569-d027-4e9d-a08f-e65c57e27c8b",
        "name": "Biji-Biji Academy",
        "catalog_title": "Biji-Biji Academy UPAI Catalog",
        "content_filter": {
            "content_type": "course",
            # UPAI courses identified by course key prefix
            "course_key__startswith": "course-v1:MEREKA+UPAI",
        },
        "description": "BijiBiji: UPAI courses only",
    },
}

# FOW course key prefixes (non-MCT, non-UPAI courses in the SOF bundle)
FOW_PREFIXES = ("PB", "PW", "PF", "SYFJ", "F101", "MYFC", "SP", "SYFC", "TYJ", "LLP", "PP")

# Namespace where LMS pods run
DEFAULT_NAMESPACE = "mereka-lms-dev"


def find_lms_pod(namespace: str) -> str:
    """Find the first running LMS pod (excludes workers)."""
    result = subprocess.run(
        ["kubectl", "get", "pods", "-n", namespace, "-o", "name"],
        capture_output=True,
        text=True,
        check=True,
    )
    for line in result.stdout.splitlines():
        name = line.removeprefix("pod/")
        if name.startswith("lms-") and "worker" not in name:
            return name
    raise RuntimeError(f"No LMS pod found in namespace {namespace}")


def kubectl_exec(pod: str, namespace: str, python_code: str) -> str:
    """Run a Python snippet in the LMS Django shell via kubectl exec."""
    cmd = [
        "kubectl", "exec", "-n", namespace, pod, "-c", "lms",
        "--",
        "python", "manage.py", "lms", "shell", "-c", python_code,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        # Print stdout first (it may contain useful partial output) then raise
        if result.stdout.strip():
            print(result.stdout)
        raise RuntimeError(
            f"kubectl exec failed (exit {result.returncode}):\n"
            f"stderr: {result.stderr}"
        )
    return result.stdout


def build_django_snippet(dry_run: bool) -> str:
    """
    Build the Django shell Python snippet that creates/updates catalogs.

    Returns a single string that can be passed to `manage.py lms shell -c`.
    """
    fow_prefixes_repr = repr(FOW_PREFIXES)
    customers_repr = repr(
        {k: {"uuid": v["uuid"], "catalog_title": v["catalog_title"]} for k, v in ENTERPRISE_CUSTOMERS.items()}
    )
    dry_run_repr = repr(dry_run)

    # We build the SOF content_filter dynamically inside the snippet
    # because it needs to enumerate actual course keys from the DB.
    snippet = textwrap.dedent(f"""
import json
import sys

DRY_RUN = {dry_run_repr}
FOW_PREFIXES = {fow_prefixes_repr}

from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from enterprise.models import EnterpriseCustomer, EnterpriseCustomerCatalog

# ---------------------------------------------------------------------------
# Determine SOF course key list dynamically from DB
# ---------------------------------------------------------------------------
all_course_keys = list(
    CourseOverview.objects.all().values_list("id", flat=True)
)
sof_course_keys = [
    str(ck) for ck in all_course_keys
    if "MCT" in str(ck) or any(
        str(ck).split("+")[1].startswith(p) for p in FOW_PREFIXES
    )
]
upai_course_keys = [str(ck) for ck in all_course_keys if "UPAI" in str(ck)]

print(f"[INFO] Total courses in DB: {{len(all_course_keys)}}")
print(f"[INFO] SOF course keys ({{len(sof_course_keys)}}): MCT + FOW")
print(f"[INFO] UPAI course keys ({{len(upai_course_keys)}}): BijiBiji")

# ---------------------------------------------------------------------------
# Catalog definitions
# ---------------------------------------------------------------------------
CATALOGS = [
    {{
        "ec_uuid": "caee80bc-2e05-4b92-8ebe-d0ec045edaeb",
        "title":   "Mereka Academy Full Catalog",
        "content_filter": {{
            "content_type": "course",
            "organizations.key": ["MEREKA"],
        }},
        "description": "Mereka: all MEREKA org courses (platform-wide)",
    }},
    {{
        "ec_uuid": "ef9e4eff-4c5d-464b-a650-2000bad56c99",
        "title":   "Skill Our Future Catalog",
        "content_filter": {{
            "content_type": "course",
            "course_key__in": sof_course_keys,
        }},
        "description": f"SOF: MCT + FOW courses ({{len(sof_course_keys)}} courses)",
    }},
    {{
        "ec_uuid": "7ad11569-d027-4e9d-a08f-e65c57e27c8b",
        "title":   "Biji-Biji Academy UPAI Catalog",
        "content_filter": {{
            "content_type": "course",
            "course_key__in": upai_course_keys,
        }},
        "description": f"BijiBiji: UPAI courses ({{len(upai_course_keys)}} courses)",
    }},
]

DEFAULT_COURSE_MODES = [
    "verified", "professional", "no-id-professional",
    "audit", "honor", "unpaid-executive-education",
]

results = []

for spec in CATALOGS:
    ec_uuid   = spec["ec_uuid"]
    title     = spec["title"]
    cf        = spec["content_filter"]
    desc      = spec["description"]

    try:
        ec = EnterpriseCustomer.objects.get(uuid=ec_uuid)
    except EnterpriseCustomer.DoesNotExist:
        print(f"[ERROR] EnterpriseCustomer {{ec_uuid}} not found — skipping")
        results.append({{"title": title, "status": "EC_NOT_FOUND"}})
        continue

    # Idempotency: look for an existing catalog with the same title for this EC
    existing = EnterpriseCustomerCatalog.objects.filter(
        enterprise_customer=ec,
        title=title,
    ).first()

    if DRY_RUN:
        if existing:
            print(f"[DRY-RUN] WOULD UPDATE  | {{ec.name}} | {{title}}")
            print(f"           filter: {{json.dumps(cf, indent=2)}}")
        else:
            print(f"[DRY-RUN] WOULD CREATE  | {{ec.name}} | {{title}}")
            print(f"           filter: {{json.dumps(cf, indent=2)}}")
        results.append({{"title": title, "status": "DRY_RUN"}})
        continue

    if existing:
        existing.content_filter = cf
        existing.enabled_course_modes = DEFAULT_COURSE_MODES
        existing.save()
        action = "UPDATED"
        cat_uuid = str(existing.uuid)
    else:
        new_cat = EnterpriseCustomerCatalog.objects.create(
            enterprise_customer=ec,
            title=title,
            content_filter=cf,
            enabled_course_modes=DEFAULT_COURSE_MODES,
            publish_audit_enrollment_urls=False,
        )
        action = "CREATED"
        cat_uuid = str(new_cat.uuid)

    print(f"[OK] {{action:<8}} | {{ec.name}} | {{title}} | uuid={{cat_uuid}}")
    print(f"       {{desc}}")
    results.append({{"title": title, "status": action, "uuid": cat_uuid}})

# ---------------------------------------------------------------------------
# Verification: print final state
# ---------------------------------------------------------------------------
print()
print("=" * 70)
print("VERIFICATION — Final catalog state")
print("=" * 70)
try:
    for ec in EnterpriseCustomer.objects.all():
        cats = EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec)
        print(f"  {{ec.name}} ({{ec.uuid}})")
        for cat in cats:
            # content_filter may be a JSONString, dict, or None — normalize to dict
            try:
                cf = dict(cat.content_filter) if cat.content_filter else {{}}
            except Exception:
                cf = {{}}
            cf_keys = list(cf.keys())
            course_count = ""
            if "course_key__in" in cf:
                course_count = f" [{{len(cf['course_key__in'])}} courses]"
            print(f"    - {{cat.title}} | uuid={{cat.uuid}}")
            print(f"      filter keys: {{cf_keys}}{{course_count}}")
except Exception as _ve:
    print(f"[WARN] Verification query failed: {{_ve}}")

print()
if DRY_RUN:
    print("DRY RUN complete — no changes made. Re-run without --dry-run to apply.")
else:
    print("Done.")
""")
    return snippet


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create/update enterprise catalog assignments for Mereka LMS dev",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""
        Catalog assignments:
          Mereka Academy  -> all MEREKA org courses (platform-wide)
          Skill Our Future -> MCT + FOW courses (27 MCT + 8 FOW = 35)
          Biji-Biji Academy -> UPAI courses (1)

        Examples:
          # Preview changes without writing anything
          python scripts/migrations/post_import_enterprise_catalogs.py --dry-run

          # Apply to dev namespace (default)
          python scripts/migrations/post_import_enterprise_catalogs.py

          # Apply to a different namespace
          python scripts/migrations/post_import_enterprise_catalogs.py --namespace mereka-lms
        """),
    )
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without writing")
    parser.add_argument("--namespace", default=DEFAULT_NAMESPACE, help=f"K8s namespace (default: {DEFAULT_NAMESPACE})")
    args = parser.parse_args()

    print("=" * 70)
    print("Enterprise Catalog Assignment — Mereka LMS")
    print("=" * 70)
    print(f"  Namespace : {args.namespace}")
    print(f"  Dry run   : {args.dry_run}")
    print()

    # 1. Locate LMS pod
    try:
        pod = find_lms_pod(args.namespace)
        print(f"[INFO] Using pod: {pod}")
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    # 2. Build the Django snippet
    snippet = build_django_snippet(dry_run=args.dry_run)

    # 3. Execute via kubectl exec
    print("[INFO] Running Django shell snippet ...")
    print()
    try:
        output = kubectl_exec(pod, args.namespace, snippet)
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    # Strip noisy Django startup warnings from output, keep meaningful lines
    meaningful_lines = []
    skip_prefixes = (
        "WARNING", "INFO", "DeprecationWarning", "imghdr", "casbin",
        "RemovedIn", "URLField", "forms.", "objects could",
        "objects imported", "return form_class",
    )
    skip_contains = (
        "lms.djangoapps.", "openedx.", "openassessment.", "common.djangoapps.",
        "pgpy", "casbin", "tenant_cache",
    )
    for line in output.splitlines():
        stripped = line.strip()
        if any(stripped.startswith(p) for p in skip_prefixes):
            continue
        if any(s in stripped for s in skip_contains):
            continue
        if stripped.startswith("2026-") or stripped.startswith("202"):
            # Skip log timestamps
            if " WARNING " in stripped or " INFO " in stripped:
                continue
        meaningful_lines.append(line)

    print("\n".join(meaningful_lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
