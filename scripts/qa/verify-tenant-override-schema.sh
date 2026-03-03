#!/usr/bin/env bash
# Verify multisite tenant site_values schema and override hygiene.
# - Enforces required keys and allowed key set.
# - Validates org filter consistency.
# - Emits sparse-hygiene warnings for likely base-copy drift.
#
# Usage:
#   ./scripts/qa/verify-tenant-override-schema.sh
#   STRICT=1 ./scripts/qa/verify-tenant-override-schema.sh
#   ./scripts/qa/verify-tenant-override-schema.sh --file infrastructure/tutor/multisite-sites.yml
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STRICT="${STRICT:-1}"

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
    -h|--help)
      sed -n '1,16p' "$0"
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

python3 - "$STRICT" "${FILES[@]}" <<'PY'
import os
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except Exception as exc:
    print(f"FAIL: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(2)

strict = (sys.argv[1] == "1")
files = sys.argv[2:]
repo = Path.cwd()

required_keys = {
    "domain",
    "site_name",
    "platform_name",
    "LMS_ROOT_URL",
    "CMS_ROOT_URL",
    "MFE_BASE_URL",
    "THEME_NAME",
    "course_org_filter",
}

allowed_keys = required_keys | {
    "ENABLE_COMPREHENSIVE_THEMING",
    "logo_image",
    "logo_url",
    "favicon_path",
    "homepage_banner_enabled",
    "MFE_CONFIG",
    "DEFAULT_SITE_THEME",
    "ENTERPRISE_CUSTOMER_UUID",
}

identity_keys = {
    "domain",
    "site_name",
    "platform_name",
    "LMS_ROOT_URL",
    "CMS_ROOT_URL",
    "MFE_BASE_URL",
    "course_org_filter",
    "logo_image",
    "logo_url",
    "favicon_path",
}

passes: list[str] = []
warnings: list[str] = []
failures: list[str] = []


def rel(p: Path) -> str:
    try:
        return str(p.relative_to(repo))
    except ValueError:
        return str(p)


for raw in files:
    path = Path(raw if os.path.isabs(raw) else (repo / raw))
    label = rel(path)
    if not path.exists():
        warnings.append(f"{label}: missing file (skipped)")
        continue

    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    sites = payload.get("sites")
    if not isinstance(sites, list):
        failures.append(f"{label}: top-level 'sites' must be a list")
        continue
    if not sites:
        warnings.append(f"{label}: no site definitions")
        continue

    passes.append(f"{label}: parsed {len(sites)} site definitions")
    base_values = (sites[0] or {}).get("site_values") or {}

    for idx, site in enumerate(sites):
        site = site or {}
        domain = str(site.get("domain") or f"site[{idx}]")
        orgs = sorted(str(x).strip() for x in (site.get("orgs") or []) if str(x).strip())
        values = site.get("site_values")
        if not isinstance(values, dict):
            failures.append(f"{label}: {domain} missing site_values map")
            continue

        missing = sorted(k for k in required_keys if k not in values)
        if missing:
            failures.append(f"{label}: {domain} missing required keys: {missing}")

        unknown = sorted(k for k in values.keys() if k not in allowed_keys)
        if unknown:
            failures.append(f"{label}: {domain} has unknown site_values keys: {unknown}")

        org_filter = values.get("course_org_filter") or []
        if isinstance(org_filter, str):
            org_filter = [org_filter]
        if not isinstance(org_filter, list):
            failures.append(f"{label}: {domain} course_org_filter must be list|string")
            org_filter = []
        org_filter_norm = sorted(str(x).strip() for x in org_filter if str(x).strip())
        if orgs and org_filter_norm and org_filter_norm != orgs:
            failures.append(
                f"{label}: {domain} course_org_filter {org_filter_norm} must match orgs {orgs}"
            )

        # Sparse-hygiene warning: if a non-base site copies many non-identity values exactly,
        # call it out for eventual base+delta cleanup.
        if idx > 0 and isinstance(base_values, dict):
            copied_nonidentity = []
            for key, val in values.items():
                if key in identity_keys:
                    continue
                if key in base_values and base_values.get(key) == val:
                    copied_nonidentity.append(key)
            if len(copied_nonidentity) >= 2:
                warnings.append(
                    f"{label}: {domain} copies non-identity keys from base: {sorted(copied_nonidentity)}"
                )

if passes:
    print("PASS:")
    for line in passes:
        print(f"  - {line}")

if warnings:
    print("WARN:")
    for line in warnings:
        print(f"  - {line}")

if failures:
    print("FAIL:")
    for line in failures:
        print(f"  - {line}")

print("Summary:")
print(f"  pass_checks: {len(passes)}")
print(f"  warnings:    {len(warnings)}")
print(f"  failures:    {len(failures)}")
print(f"  strict:      {strict}")

if failures and strict:
    sys.exit(1)
sys.exit(0)
PY
