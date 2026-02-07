#!/usr/bin/env python3
"""MCT data export pipeline with Infisical integration and delta support.

Reads credentials from Infisical (/mereka-lms/mct/) and exports MCT platform
data to ~/projects/mereka-lms/exports/mct/.

Usage:
  # Full export (all resources):
  cd ~/projects/mereka-lms
  infisical run --env prod --path /mereka-lms/mct -- python3 scripts/migrations/mct/mct_export.py

  # Delta export (only users and enrollments):
  infisical run --env prod --path /mereka-lms/mct -- python3 scripts/migrations/mct/mct_export.py --delta

  # Export specific resources:
  infisical run --env prod --path /mereka-lms/mct -- python3 scripts/migrations/mct/mct_export.py --resources admin_users,enrollments

  # Dry run:
  infisical run --env prod --path /mereka-lms/mct -- python3 scripts/migrations/mct/mct_export.py --dry-run

Environment variables (set by Infisical):
  MCT_CLIENT_ID      - SOF S2S-Client ID (whitelisted in ServiceApplicationIds)
  MCT_CLIENT_SECRET  - Client secret (expires 2026-08-07)
  MCT_TENANT_ID      - Azure AD tenant ID
  MCT_API_URI        - API audience URI (api://bf8331fd-...)
  MCT_BASE_URL       - Platform URL (https://learn.skillourfuture.org)

IMPORTANT: Only the SOF S2S-Client (caa4dce3) is whitelisted in MCT's
ServiceApplicationIds. The UNDP S2S-Client (f16cdc2f) will get 401.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# -- Config --

EXPORT_ROOT = Path.home() / "projects" / "mereka-lms" / "exports" / "mct"
RAW_API_DIR = EXPORT_ROOT / "raw_api"
ENROLLMENTS_DIR = EXPORT_ROOT / "enrollments_by_course"

ALL_RESOURCES = [
    "organizations",
    "courses_v1",
    "courses_v2",
    "courses_v3",
    "groups",
    "learningpaths_v1",
    "learningpaths_v2",
    "certificates",
    "admin_users",
    "reports_users",
    "enrollments",
]

DELTA_RESOURCES = ["admin_users", "reports_users", "enrollments"]


# -- Auth --

def require_env(name):
    val = os.environ.get(name)
    if not val:
        print(f"ERROR: {name} not set. Run via:")
        print(f"  infisical run --env prod --path /mereka-lms/mct -- python3 {sys.argv[0]}")
        sys.exit(1)
    return val


def get_token():
    client_id = require_env("MCT_CLIENT_ID")
    client_secret = require_env("MCT_CLIENT_SECRET")
    tenant_id = require_env("MCT_TENANT_ID")
    api_uri = require_env("MCT_API_URI")

    data = (
        "grant_type=client_credentials"
        "&client_id=" + client_id +
        "&client_secret=" + urllib.parse.quote(client_secret) +
        "&scope=" + urllib.parse.quote(api_uri + "/.default")
    ).encode()
    req = urllib.request.Request(
        "https://login.microsoft.com/" + tenant_id + "/oauth2/v2.0/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["access_token"]


# -- HTTP --

def fetch(url, token):
    req = urllib.request.Request(url)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Accept", "application/json")
    req.add_header("ClientType", "service")
    with urllib.request.urlopen(req, timeout=120) as resp:
        content_type = resp.headers.get("Content-Type", "")
        raw = resp.read()
        if "json" in content_type:
            return json.loads(raw), "json"
        return raw, "csv"


# -- Export functions --

def export_simple(name, endpoint, token, dry_run):
    base_url = require_env("MCT_BASE_URL")
    url = base_url + endpoint
    print("  Fetching " + url)
    if dry_run:
        return {"status": "dry_run"}
    data, fmt = fetch(url, token)
    out = RAW_API_DIR / (name + ".json")
    with open(out, "w") as f:
        json.dump(data, f, indent=2)
    size = out.stat().st_size
    count = len(data) if isinstance(data, list) else "dict"
    print("  Saved %s: %s records, %s bytes" % (out.name, count, f"{size:,}"))
    return {"file": str(out), "size": size, "count": str(count)}


def export_admin_users(token, dry_run):
    base_url = require_env("MCT_BASE_URL")
    all_users = []
    page = 0
    take = 1000

    while True:
        skip = page * take
        url = "%s/api/v1/admin/users?skip=%d&take=%d" % (base_url, skip, take)
        if dry_run:
            print("  [dry-run] Would fetch page %d: %s" % (page + 1, url))
            return {"status": "dry_run"}

        data, _ = fetch(url, token)
        users = data.get("UserDetails", []) if isinstance(data, dict) else []
        if not users:
            break
        all_users.extend(users)
        if (page + 1) % 10 == 0:
            print("  Page %d: %s users..." % (page + 1, f"{len(all_users):,}"))
        if len(users) < take:
            break
        page += 1
        time.sleep(0.3)
        if (page + 1) % 50 == 0:
            token = get_token()

    out = RAW_API_DIR / "admin_users.json"
    with open(out, "w") as f:
        json.dump(all_users, f)
    size = out.stat().st_size
    print("  Total: %s users, %s bytes" % (f"{len(all_users):,}", f"{size:,}"))
    return {"file": str(out), "size": size, "count": len(all_users)}


def export_reports_users(token, dry_run):
    base_url = require_env("MCT_BASE_URL")
    url = base_url + "/api/v1/Reports/Users"
    if dry_run:
        print("  [dry-run] Would fetch " + url)
        return {"status": "dry_run"}

    data, fmt = fetch(url, token)
    if fmt == "csv":
        out = RAW_API_DIR / "reports_users.csv"
        with open(out, "wb") as f:
            f.write(data)
        lines = data.decode("utf-8-sig", errors="replace").count("\n")
        print("  Saved CSV: %s lines, %s bytes" % (f"{lines:,}", f"{len(data):,}"))
        return {"file": str(out), "size": len(data), "lines": lines}
    else:
        out = RAW_API_DIR / "reports_users.json"
        with open(out, "w") as f:
            json.dump(data, f)
        size = out.stat().st_size
        print("  Saved JSON: %s bytes" % f"{size:,}")
        return {"file": str(out), "size": size}


def export_enrollments(token, dry_run):
    base_url = require_env("MCT_BASE_URL")

    v3_path = RAW_API_DIR / "categories_and_courses_v3.json"
    if not v3_path.exists():
        print("  ERROR: courses_v3 must be exported first (need course IDs)")
        return {"error": "missing courses_v3"}

    with open(v3_path) as f:
        v3 = json.load(f)
    course_ids = [item["Id"] for item in (v3.get("CourseItems") or []) if item.get("Id")]
    print("  %d courses to export" % len(course_ids))

    if dry_run:
        return {"status": "dry_run", "courses": len(course_ids)}

    ENROLLMENTS_DIR.mkdir(parents=True, exist_ok=True)
    total_enrollments = 0
    errors = 0
    new_files = 0

    for i, cid in enumerate(course_ids):
        try:
            data, fmt = fetch("%s/api/v1/Reports/Course/%s/Learners" % (base_url, cid), token)
            if fmt == "csv":
                out = ENROLLMENTS_DIR / ("course_%s.csv" % cid)
                with open(out, "wb") as f:
                    f.write(data)
                lines = data.decode("utf-8-sig", errors="replace").count("\n") - 1
                total_enrollments += max(0, lines)
                new_files += 1
            else:
                out = ENROLLMENTS_DIR / ("course_%s.json" % cid)
                with open(out, "w") as f:
                    json.dump(data, f)
                new_files += 1
        except Exception as e:
            errors += 1
            if errors <= 5:
                print("    ERROR course %s: %s" % (cid, e))

        if (i + 1) % 20 == 0:
            print("    Progress: %d/%d, ~%s enrollments" % (i + 1, len(course_ids), f"{total_enrollments:,}"))
            time.sleep(0.5)

        if (i + 1) % 50 == 0:
            token = get_token()

        time.sleep(0.2)

    print("  Done: %d files, ~%s enrollments, %d errors" % (new_files, f"{total_enrollments:,}", errors))
    return {"files": new_files, "enrollments": total_enrollments, "errors": errors}


# -- Orchestrator --

RESOURCE_MAP = {
    "organizations": lambda t, d: export_simple("organizations", "/api/v1/organization", t, d),
    "courses_v1": lambda t, d: export_simple("courses_v1", "/api/v1/Courses", t, d),
    "courses_v2": lambda t, d: export_simple("courses_v2", "/api/v2/Courses", t, d),
    "courses_v3": lambda t, d: export_simple("categories_and_courses_v3", "/api/v3/admin/categoriesAndCourses", t, d),
    "groups": lambda t, d: export_simple("groups", "/api/v1/Groups", t, d),
    "learningpaths_v1": lambda t, d: export_simple("learningpaths_v1", "/api/v1/learningpaths", t, d),
    "learningpaths_v2": lambda t, d: export_simple("learningpaths_v2", "/api/v2/learningpaths", t, d),
    "certificates": lambda t, d: export_simple("certificates", "/api/v1/Certificates", t, d),
    "admin_users": lambda t, d: export_admin_users(t, d),
    "reports_users": lambda t, d: export_reports_users(t, d),
    "enrollments": lambda t, d: export_enrollments(t, d),
}


def main():
    parser = argparse.ArgumentParser(description="MCT data export pipeline")
    parser.add_argument("--resources", help="Comma-separated list of resources to export")
    parser.add_argument("--delta", action="store_true", help="Delta mode: only users + enrollments")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be exported")
    args = parser.parse_args()

    if args.resources:
        resources = [r.strip() for r in args.resources.split(",")]
        invalid = [r for r in resources if r not in RESOURCE_MAP]
        if invalid:
            print("Unknown resources: %s" % invalid)
            print("Available: %s" % list(RESOURCE_MAP.keys()))
            sys.exit(1)
    elif args.delta:
        resources = DELTA_RESOURCES
    else:
        resources = ALL_RESOURCES

    RAW_API_DIR.mkdir(parents=True, exist_ok=True)
    ENROLLMENTS_DIR.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    mode = "delta" if args.delta else "full"
    print("MCT Export -- %s" % now)
    print("Mode: %s | Resources: %s" % (mode, resources))
    print("Output: %s" % EXPORT_ROOT)
    if args.dry_run:
        print("DRY RUN -- no data will be written")
    print()

    token = get_token()
    print("Token acquired\n")

    results = {}
    for resource in resources:
        print("=== %s ===" % resource)
        try:
            results[resource] = RESOURCE_MAP[resource](token, args.dry_run)
        except Exception as e:
            print("  FAILED: %s" % e)
            results[resource] = {"error": str(e)}
        print()

    if not args.dry_run:
        manifest = {
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "mode": mode,
            "resources": resources,
            "results": {k: {kk: str(vv) for kk, vv in v.items()} for k, v in results.items()},
        }
        manifest_path = EXPORT_ROOT / "last_export.json"
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
        print("Export manifest: %s" % manifest_path)

    print("\n" + "=" * 60)
    print("EXPORT COMPLETE")
    total_size = 0
    for p in [RAW_API_DIR, ENROLLMENTS_DIR]:
        if p.exists():
            for item in p.iterdir():
                total_size += item.stat().st_size
    print("Total data: %.1f MB" % (total_size / 1024 / 1024))


if __name__ == "__main__":
    main()
