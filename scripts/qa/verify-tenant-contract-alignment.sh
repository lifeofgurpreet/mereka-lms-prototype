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
experience_contract_path = repo_root / "config/tenant-experience-contract.yaml"
multisite_path = repo_root / "infrastructure/tutor/multisite-sites.yml"
multisite_dev_path = repo_root / "infrastructure/tutor/multisite-sites.dev.yml"
registry_path = repo_root / "deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml"
caddy_path = repo_root / "deploy/k8s/base/apps/caddy/Caddyfile"
tenant_resolution_path = repo_root / "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js"

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
    (experience_contract_path, "tenant experience contract"),
    (multisite_path, "multisite-sites.yml"),
    (multisite_dev_path, "multisite-sites.dev.yml"),
    (registry_path, "tenant registry configmap"),
    (caddy_path, "Caddyfile"),
    (tenant_resolution_path, "tenant runtime resolver"),
]:
    require_file(required, label)

if failed:
    print(f"Summary: PASS={passed} FAIL={failed}")
    raise SystemExit(1)

contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))
experience_contract = yaml.safe_load(experience_contract_path.read_text(encoding="utf-8"))
multisite = yaml.safe_load(multisite_path.read_text(encoding="utf-8"))
multisite_dev = yaml.safe_load(multisite_dev_path.read_text(encoding="utf-8"))
registry_docs = list(yaml.safe_load_all(registry_path.read_text(encoding="utf-8")))
caddy_text = caddy_path.read_text(encoding="utf-8")
tenant_resolution_text = tenant_resolution_path.read_text(encoding="utf-8")

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
sites_dev = multisite_dev.get("sites") or []
site_by_domain_dev = {site.get("domain"): site for site in sites_dev if isinstance(site, dict)}

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


print("=== Tenant Experience Contract Verification ===")

def find_contract_tenant(slug: str):
    for tenant in active_tenants:
        if tenant.get("slug") == slug:
            return tenant
        if tenant.get("registry_slug") == slug:
            return tenant
    return None


def expect_contains(haystack: str, needle: str, label: str) -> None:
    if needle in haystack:
        ok(label)
    else:
        fail(f"{label} (missing {needle!r})")


def expect_authn_subtitle(haystack: str, expected_subtitle: str, brand: str, label: str) -> None:
    if expected_subtitle in haystack:
        ok(label)
        return
    template_subtitle = expected_subtitle.replace(brand, "${brand}")
    if template_subtitle in haystack:
        ok(f"{label} (template form)")
        return
    fail(f"{label} (missing {expected_subtitle!r} or template {template_subtitle!r})")


experience_tenants = experience_contract.get("tenants", []) if isinstance(experience_contract, dict) else []
if not experience_tenants:
    fail("tenant experience contract has no tenants")

for tenant in experience_tenants:
    slug = tenant["slug"]
    variant_symbol = tenant["variant_symbol"]
    site_name = tenant["site_name"]
    expected_brand = tenant.get("expected_brand", site_name)
    expected_authn = tenant["expected_authn"]
    runtime_tenant = find_contract_tenant(slug)

    print(f"--- experience tenant: {slug} ---")

    if runtime_tenant is not None:
        ok(f"{slug}: experience contract links to tenant contract entry")
    else:
        fail(f"{slug}: missing linked tenant contract entry")

    expect_contains(tenant_resolution_text, f"const {variant_symbol} = {{", f"{slug}: runtime variant symbol exists")
    expect_contains(tenant_resolution_text, f"slug: '{tenant['contract_slug']}'", f"{slug}: runtime variant slug matches")
    expect_contains(tenant_resolution_text, f"brand: '{expected_brand}'", f"{slug}: runtime brand matches")
    expect_contains(tenant_resolution_text, f"logoUrl: '{tenant['logo_asset']}'", f"{slug}: runtime logo asset matches")
    expect_contains(tenant_resolution_text, f"mobileLogoUrl: '{tenant['mobile_logo_asset']}'", f"{slug}: runtime mobile logo asset matches")
    expect_contains(tenant_resolution_text, f"themeBrandUrl: '{tenant['theme_bundle']}'", f"{slug}: runtime theme bundle matches")
    expect_contains(tenant_resolution_text, f"themeBrandLightUrl: '{tenant['theme_bundle_light']}'", f"{slug}: runtime light theme bundle matches")
    expect_contains(tenant_resolution_text, f"eyebrow: '{expected_authn['eyebrow']}'", f"{slug}: authn eyebrow matches")
    expect_contains(tenant_resolution_text, f"title: '{expected_authn['title']}'", f"{slug}: authn title matches")
    expect_authn_subtitle(tenant_resolution_text, expected_authn["subtitle"], expected_brand, f"{slug}: authn subtitle matches")
    expect_contains(tenant_resolution_text, f"trustNote: '{expected_authn['trust_note']}'", f"{slug}: authn trust note matches")

    smoke_id = tenant.get("smoke_account_key")
    if smoke_id:
        expect_contains(
            (repo_root / "config/smoke-account-registry.yaml").read_text(encoding="utf-8"),
            f"canonical_id: {smoke_id}",
            f"{slug}: smoke account binding exists",
        )

    for env_entry in tenant.get("environments", []):
        env = env_entry["env"]
        lms_host = env_entry["lms_host"]
        apps_host = env_entry["apps_host"]
        studio_host = env_entry["studio_host"]
        authn_base_url = env_entry["authn_base_url"]
        site_map = site_by_domain if env == "production" else site_by_domain_dev if env == "dev" else {}
        site = site_map.get(lms_host)

        if not site:
            fail(f"{slug}/{env}: multisite source missing {lms_host}")
            continue

        ok(f"{slug}/{env}: multisite source includes {lms_host}")
        values = site.get("site_values") or {}
        expected_values = {
            "site_name": site_name,
            "LMS_ROOT_URL": f"https://{lms_host}",
            "CMS_ROOT_URL": f"https://{studio_host}",
            "MFE_BASE_URL": f"https://{apps_host}",
        }
        for key, expected in expected_values.items():
            actual = values.get(key)
            if actual == expected:
                ok(f"{slug}/{env}: {key} matches experience contract")
            else:
                fail(f"{slug}/{env}: {key} mismatch (expected {expected}, got {actual})")

        if authn_base_url == f"https://{apps_host}/authn":
            ok(f"{slug}/{env}: authn_base_url derived from apps host")
        else:
            fail(f"{slug}/{env}: authn_base_url mismatch (expected https://{apps_host}/authn, got {authn_base_url})")

        expect_contains(tenant_resolution_text, f"'{lms_host}': {variant_symbol}", f"{slug}/{env}: runtime host binding exists")

print(f"Summary: PASS={passed} FAIL={failed}")
if failed:
    raise SystemExit(1)
PY
