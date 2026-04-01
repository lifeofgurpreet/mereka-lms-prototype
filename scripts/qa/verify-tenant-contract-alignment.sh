#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-003, AC-MTA-022
# @spec: multi-tenancy-architecture_spec.md
#
# Verify alignment between:
#   - infrastructure/tenants/tenant-contracts.yml (tenant metadata + convenience domains)
#   - deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml (K8s ConfigMap)
#   - infrastructure/tutor/multisite-sites.yml (multisite config)
#   - deploy/k8s/base/apps/caddy/Caddyfile (routing)
#
# Canonical domain truth: deploy/k8s/tenancy/tenant-registry.yaml
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REGISTRY_SYNC_SCRIPT="${REPO_ROOT}/scripts/tenants/sync-tenant-registry-configmap.sh"
if [[ ! -x "$REGISTRY_SYNC_SCRIPT" ]]; then
  echo "FAIL tenant registry sync script missing or not executable: ${REGISTRY_SYNC_SCRIPT}"
  exit 1
fi

if ! "$REGISTRY_SYNC_SCRIPT" --check; then
  echo "FAIL tenant registry sync contract check failed"
  exit 1
fi

python3 - "$REPO_ROOT" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])

contract_path = repo_root / "infrastructure/tenants/tenant-contracts.yml"
multisite_path = repo_root / "infrastructure/tutor/multisite-sites.yml"
registry_path = repo_root / "deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml"
caddy_path = repo_root / "deploy/k8s/base/apps/caddy/Caddyfile"

failed = 0
passed = 0


def ok(msg: str) -> None:
    global passed
    passed += 1
    print(f"PASS {msg}")


def fail(msg: str) -> None:
    global failed
    failed += 1
    print(f"FAIL {msg}")


def require_file(path: Path, label: str) -> None:
    if path.exists():
        ok(f"{label} exists")
    else:
        fail(f"{label} missing: {path}")


print("=== Tenant Contract Alignment Verification ===")

for required, label in [
    (contract_path, "tenant contract"),
    (multisite_path, "multisite-sites.yml"),
    (registry_path, "tenant registry configmap"),
    (caddy_path, "Caddyfile"),
]:
    require_file(required, label)

if failed:
    print(f"Summary: PASS={passed} FAIL={failed}")
    raise SystemExit(1)

contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))
multisite = yaml.safe_load(multisite_path.read_text(encoding="utf-8"))
registry_docs = list(yaml.safe_load_all(registry_path.read_text(encoding="utf-8")))
caddy_text = caddy_path.read_text(encoding="utf-8")

registry_cm = next((doc for doc in registry_docs if isinstance(doc, dict) and doc.get("kind") == "ConfigMap"), None)
if not registry_cm:
    fail("tenant registry configmap has no ConfigMap document")
    print(f"Summary: PASS={passed} FAIL={failed}")
    raise SystemExit(1)

registry_yaml_blob = (registry_cm.get("data") or {}).get("tenants.yaml", "")
if not registry_yaml_blob.strip():
    fail("tenant registry ConfigMap data.tenants.yaml is empty")
    print(f"Summary: PASS={passed} FAIL={failed}")
    raise SystemExit(1)

registry_tenants = yaml.safe_load(registry_yaml_blob) or []
registry_by_slug = {tenant.get("slug"): tenant for tenant in registry_tenants if isinstance(tenant, dict)}

sites = multisite.get("sites") or []
site_by_domain = {site.get("domain"): site for site in sites if isinstance(site, dict)}

active_tenants = [tenant for tenant in contract.get("tenants", []) if tenant.get("active", True)]
if not active_tenants:
    fail("tenant contract has no active tenants")

for tenant in active_tenants:
    slug = tenant["slug"]
    name = tenant["name"]
    org_code = tenant["org_code"]
    domains = tenant["domains"]
    lms = domains["lms"]
    studio = domains["studio"]
    apps = domains["apps"]
    admin = domains["admin"]

    print(f"--- tenant: {slug} ({name}) ---")

    # multisite-sites.yml alignment
    site = site_by_domain.get(lms)
    if not site:
        fail(f"{slug}: multisite-sites.yml missing site for {lms}")
    else:
        ok(f"{slug}: multisite site exists ({lms})")
        orgs = site.get("orgs") or []
        if org_code in orgs:
            ok(f"{slug}: multisite orgs contains {org_code}")
        else:
            fail(f"{slug}: multisite orgs missing {org_code}")

        values = site.get("site_values") or {}
        expected_values = {
            "LMS_ROOT_URL": f"https://{lms}",
            "CMS_ROOT_URL": f"https://{studio}",
            "MFE_BASE_URL": f"https://{apps}",
        }
        for key, expected in expected_values.items():
            actual = values.get(key)
            if actual == expected:
                ok(f"{slug}: {key} matches contract")
            else:
                fail(f"{slug}: {key} mismatch (expected {expected}, got {actual})")

        course_org_filter = values.get("course_org_filter") or []
        if org_code in course_org_filter:
            ok(f"{slug}: course_org_filter contains {org_code}")
        else:
            fail(f"{slug}: course_org_filter missing {org_code}")

    # tenant-registry configmap alignment
    registry_slug = tenant.get("registry_slug") or slug
    registry_entry = registry_by_slug.get(registry_slug)
    if not registry_entry:
        fail(f"{slug}: tenant-registry missing slug {registry_slug}")
    else:
        ok(f"{slug}: tenant-registry entry exists ({registry_slug})")
        registry_domain = registry_entry.get("domain")
        if registry_domain == lms:
            ok(f"{slug}: tenant-registry domain matches {lms}")
        else:
            fail(f"{slug}: tenant-registry domain mismatch (expected {lms}, got {registry_domain})")

        expected_aliases = sorted(tenant.get("aliases") or [])
        actual_aliases = sorted(registry_entry.get("alias_domains") or [])
        if expected_aliases == actual_aliases:
            ok(f"{slug}: tenant-registry alias domains match contract")
        else:
            fail(
                f"{slug}: tenant-registry alias mismatch "
                f"(expected {expected_aliases}, got {actual_aliases})"
            )

    # Caddy routing alignment
    # Base Caddyfile is environment-neutral; overlays inject actual hostnames.
    required_caddy_tokens = {
        "LMS": "http://{$LMS_HOST}",
        "Studio": "http://{$STUDIO_HOST}",
        "MFE": "http://{$MFE_HOST}",
    }
    for label, token in required_caddy_tokens.items():
        if token in caddy_text:
            ok(f"{slug}: Caddyfile keeps env-neutral {label} host token {token}")
        else:
            fail(f"{slug}: Caddyfile missing env-neutral {label} host token {token}")

    # Enterprise MFE runtime config alignment
    mfe_env_file = repo_root / tenant["mfe_env_file"]
    if not mfe_env_file.exists():
        fail(f"{slug}: MFE env file missing ({tenant['mfe_env_file']})")
        continue

    ok(f"{slug}: MFE env file exists ({tenant['mfe_env_file']})")
    mfe_text = mfe_env_file.read_text(encoding="utf-8")

    def extract(key: str) -> str | None:
        match = re.search(rf"\b{re.escape(key)}\s*:\s*'([^']+)'", mfe_text)
        return match.group(1) if match else None

    if mfe_env_file.name == "enterprise-mfe-env.js":
        expected_mfe = {
            "LMS_BASE_URL": "http://localhost",
            "STUDIO_BASE_URL": "http://studio.localhost",
            "LOGIN_URL": "http://localhost/login",
            "LOGOUT_URL": "http://localhost/logout",
            "REFRESH_ACCESS_TOKEN_ENDPOINT": "http://localhost/login_refresh",
            "ENTERPRISE_CATALOG_API_BASE_URL": "http://admin.localhost/api/enterprise-catalog",
            "ENTERPRISE_ACCESS_BASE_URL": "http://admin.localhost/api/enterprise-access",
            "LICENSE_MANAGER_URL": "http://admin.localhost/api/license-manager",
            "ENTERPRISE_SUBSIDY_BASE_URL": "http://admin.localhost/api/enterprise-subsidy",
        }
    else:
        expected_mfe = {
            "LMS_BASE_URL": f"https://{lms}",
            "STUDIO_BASE_URL": f"https://{studio}",
            "LOGIN_URL": f"https://{lms}/login",
            "LOGOUT_URL": f"https://{lms}/logout",
            "REFRESH_ACCESS_TOKEN_ENDPOINT": f"https://{lms}/login_refresh",
            "ENTERPRISE_CATALOG_API_BASE_URL": f"https://{admin}/api/enterprise-catalog",
            "ENTERPRISE_ACCESS_BASE_URL": f"https://{admin}/api/enterprise-access",
            "LICENSE_MANAGER_URL": f"https://{admin}/api/license-manager",
            "ENTERPRISE_SUBSIDY_BASE_URL": f"https://{admin}/api/enterprise-subsidy",
        }
    for key, expected in expected_mfe.items():
        actual = extract(key)
        if actual == expected:
            ok(f"{slug}: {key} matches contract")
        else:
            fail(f"{slug}: {key} mismatch (expected {expected}, got {actual})")

print(f"Summary: PASS={passed} FAIL={failed}")
if failed:
    raise SystemExit(1)
PY
