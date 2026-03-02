#!/usr/bin/env bash
# Read-only tenant config safety audit.
# Purpose:
# - Catch cross-tenant host collisions before bootstrap writes.
# - Enforce strict host ownership for LMS/CMS/MFE roots.
# - Confirm base-default + tenant-override posture is explicit.
#
# Usage:
#   ./scripts/qa/audit-tenant-config-safety.sh
#   STRICT=1 ./scripts/qa/audit-tenant-config-safety.sh
#   ./scripts/qa/audit-tenant-config-safety.sh --file infrastructure/tutor/multisite-sites.yml
#   OUTPUT_FORMAT=json ./scripts/qa/audit-tenant-config-safety.sh
#   ./scripts/qa/audit-tenant-config-safety.sh --allow-shared-host apps.preview.example.com
#   ALLOW_SHARED_HOSTS_FILE=infrastructure/tutor/multisite-shared-host-allowlist.txt ./scripts/qa/audit-tenant-config-safety.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STRICT="${STRICT:-1}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
ALLOW_SHARED_HOSTS="${ALLOW_SHARED_HOSTS:-}"
ALLOW_SHARED_HOSTS_FILE="${ALLOW_SHARED_HOSTS_FILE:-infrastructure/tutor/multisite-shared-host-allowlist.txt}"

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid $var_name='$value' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_bool_01 "STRICT" "$STRICT"

FILES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILES+=("$2")
      shift 2
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --allow-shared-host)
      if [[ -n "$ALLOW_SHARED_HOSTS" ]]; then
        ALLOW_SHARED_HOSTS+=","
      fi
      ALLOW_SHARED_HOSTS+="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,18p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${#FILES[@]}" -eq 0 ]]; then
  FILES=(
    "infrastructure/tutor/multisite-sites.yml"
    "infrastructure/tutor/multisite-sites.dev.yml"
    "infrastructure/tutor/multisite-sites.staging.yml"
  )
fi

python3 - "$STRICT" "$OUTPUT_FORMAT" "$ALLOW_SHARED_HOSTS" "$ALLOW_SHARED_HOSTS_FILE" "${FILES[@]}" <<'PY'
import os
import re
import json
import sys
from collections import defaultdict
from urllib.parse import urlparse

try:
    import yaml  # type: ignore
except Exception as exc:
    print(f"FAIL: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(2)

strict = (sys.argv[1] == "1")
output_format = (sys.argv[2] or "text").strip().lower()
allow_shared_hosts_csv = (sys.argv[3] or "").strip()
allow_shared_hosts_file = (sys.argv[4] or "").strip()
files = sys.argv[5:]
repo_root = os.getcwd()

if output_format not in ("text", "json"):
    print(f"FAIL: unsupported output format '{output_format}'", file=sys.stderr)
    sys.exit(2)

allow_shared_hosts = {h.strip().lower() for h in allow_shared_hosts_csv.split(",") if h.strip()}
if allow_shared_hosts_file and os.path.exists(allow_shared_hosts_file):
    with open(allow_shared_hosts_file, "r", encoding="utf-8") as f:
        for line in f:
            token = line.split("#", 1)[0].strip().lower()
            if token:
                allow_shared_hosts.add(token)

failures = []
warnings = []
passes = []
used_allowlist_hosts = set()
shared_cms_hosts = set()
shared_mfe_hosts = set()


def norm_host(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return ""
    if "://" not in value:
        parsed = urlparse(f"https://{value}")
    else:
        parsed = urlparse(value)
    return (parsed.netloc or parsed.path or "").strip().lower()


def short(path: str) -> str:
    if path.startswith(repo_root + "/"):
        return path[len(repo_root) + 1 :]
    return path


domain_rx = re.compile(
    r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$"
)

def add_failure(category: str, message: str) -> None:
    failures.append({"category": category, "message": message})


def is_non_enterprise_domain(domain: str) -> bool:
    domain = (domain or "").strip().lower()
    if not domain:
        return False
    return (
        domain.endswith(".mereka.dev")
        or ".staging." in domain
        or domain.startswith("preview.")
        or domain.startswith("staging.")
    )


def is_non_enterprise_host(host: str) -> bool:
    host = (host or "").strip().lower()
    if not host:
        return False
    return (
        host.endswith(".mereka.dev")
        or ".staging." in host
        or host.startswith("preview.")
        or host.startswith("staging.")
    )


if output_format == "text":
    print("== Tenant Config Safety Audit (read-only) ==")

for rel_path in files:
    path = rel_path if os.path.isabs(rel_path) else os.path.join(repo_root, rel_path)
    label = short(path)

    if not os.path.exists(path):
        warnings.append(f"{label}: missing file (skipped)")
        continue

    with open(path, "r", encoding="utf-8") as f:
        payload = yaml.safe_load(f) or {}

    sites = payload.get("sites") or []
    if not isinstance(sites, list):
        add_failure("schema", f"{label}: top-level 'sites' must be a list")
        continue

    if not sites:
        warnings.append(f"{label}: no site definitions")
        continue

    passes.append(f"{label}: parsed {len(sites)} site definitions")

    domain_map = defaultdict(list)
    lms_host_map = defaultdict(list)
    cms_host_map = defaultdict(list)
    mfe_host_map = defaultdict(list)

    for idx, site in enumerate(sites):
        site = site or {}
        domain = (site.get("domain") or "").strip().lower()
        name = (site.get("name") or domain or f"site[{idx}]").strip()
        values = site.get("site_values") or {}

        if not domain:
            add_failure("schema", f"{label}: site[{idx}] missing domain")
            continue
        if not domain_rx.match(domain):
            add_failure("schema", f"{label}: invalid domain format '{domain}'")

        domain_map[domain].append(name)

        lms_root = (values.get("LMS_ROOT_URL") or "").strip()
        cms_root = (values.get("CMS_ROOT_URL") or "").strip()
        mfe_base = (values.get("MFE_BASE_URL") or "").strip()
        theme_name = (values.get("THEME_NAME") or "").strip()
        logo_image = (values.get("logo_image") or "").strip()
        favicon_path = (values.get("favicon_path") or "").strip()

        if not lms_root:
            add_failure("schema", f"{label}: {domain} missing site_values.LMS_ROOT_URL")
        if not cms_root:
            add_failure("schema", f"{label}: {domain} missing site_values.CMS_ROOT_URL")
        if not mfe_base:
            add_failure("schema", f"{label}: {domain} missing site_values.MFE_BASE_URL")

        lms_host = norm_host(lms_root)
        cms_host = norm_host(cms_root)
        mfe_host = norm_host(mfe_base)

        if lms_host and lms_host != domain:
            add_failure(
                "host_ownership",
                f"{label}: {domain} LMS_ROOT_URL host '{lms_host}' must equal domain '{domain}'"
            )

        if lms_host:
            lms_host_map[lms_host].append(domain)
        if cms_host:
            cms_host_map[cms_host].append(domain)
        if mfe_host:
            mfe_host_map[mfe_host].append(domain)

        if not theme_name:
            warnings.append(f"{label}: {domain} missing THEME_NAME (will inherit platform default)")
        if not logo_image:
            warnings.append(f"{label}: {domain} missing logo_image (will inherit base branding)")
        if not favicon_path:
            warnings.append(f"{label}: {domain} missing favicon_path (will inherit base branding)")

    for dom, owners in sorted(domain_map.items()):
        owners = sorted(set(owners))
        if len(owners) > 1:
            add_failure("host_ownership", f"{label}: duplicate site domain '{dom}' used by {owners}")

    for host, domains in sorted(lms_host_map.items()):
        owners = sorted(set(domains))
        if len(owners) > 1:
            add_failure(
                "host_ownership",
                f"{label}: LMS host '{host}' shared across tenants {owners} (must be unique)"
            )

    for host, domains in sorted(cms_host_map.items()):
        owners = sorted(set(domains))
        if len(owners) > 1:
            shared_cms_hosts.add(host)
            if host in allow_shared_hosts:
                used_allowlist_hosts.add(host)
                if any(not is_non_enterprise_domain(d) for d in owners):
                    add_failure(
                        "host_ownership",
                        f"{label}: CMS host '{host}' allowlisted but used by enterprise domains {owners} "
                        "(allowlist is preview/dev/staging only)",
                    )
                    continue
                continue
            add_failure(
                "host_ownership",
                f"{label}: CMS host '{host}' shared across tenants {owners} (must be unique)"
            )

    for host, domains in sorted(mfe_host_map.items()):
        owners = sorted(set(domains))
        if len(owners) > 1:
            shared_mfe_hosts.add(host)
            if host in allow_shared_hosts:
                used_allowlist_hosts.add(host)
                if any(not is_non_enterprise_domain(d) for d in owners):
                    add_failure(
                        "host_ownership",
                        f"{label}: MFE host '{host}' allowlisted but used by enterprise domains {owners} "
                        "(allowlist is preview/dev/staging only)",
                    )
                    continue
                continue
            add_failure(
                "host_ownership",
                f"{label}: MFE host '{host}' shared across tenants {owners} (must be unique)"
            )

for host in sorted(allow_shared_hosts):
    if not is_non_enterprise_host(host):
        add_failure(
            "allowlist_policy",
            f"allowlist host '{host}' is not preview/dev/staging scoped",
        )
    if len(files) > 1:
        if host not in shared_cms_hosts and host not in shared_mfe_hosts:
            warnings.append(
                f"allowlist host '{host}' is currently unused by shared CMS/MFE ownership"
            )
        elif host not in used_allowlist_hosts:
            warnings.append(
                f"allowlist host '{host}' did not map to a shared CMS/MFE check path"
            )

if output_format == "json":
    payload = {
        "pass_checks": len(passes),
        "warnings_count": len(warnings),
        "failures_count": len(failures),
        "strict": strict,
        "allow_shared_hosts": sorted(allow_shared_hosts),
        "passes": passes,
        "warnings": warnings,
        "failures": failures,
        "failure_categories": sorted({f["category"] for f in failures}),
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
else:
    if passes:
        print("\nPASS:")
        for line in passes:
            print(f"  - {line}")

    if warnings:
        print("\nWARN:")
        for line in warnings:
            print(f"  - {line}")

    if failures:
        print("\nFAIL:")
        for item in failures:
            print(f"  - [{item['category']}] {item['message']}")

    print("\nSummary:")
    print(f"  Pass checks: {len(passes)}")
    print(f"  Warnings:    {len(warnings)}")
    print(f"  Failures:    {len(failures)}")
    print(f"  Strict mode: {strict}")
    print(f"  Allowlist:   {sorted(allow_shared_hosts)}")

if failures and strict:
    sys.exit(1)
sys.exit(0)
PY
