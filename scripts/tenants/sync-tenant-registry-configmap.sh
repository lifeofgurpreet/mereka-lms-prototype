#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-014, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
#
# Keep tenant-registry ConfigMap aligned with the canonical tenant contract.
#
# Canonical input:
#   infrastructure/tenants/tenant-contracts.yml
#
# Target:
#   deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml (data.tenants.yaml)
#
# Usage:
#   ./scripts/tenants/sync-tenant-registry-configmap.sh --check
#   ./scripts/tenants/sync-tenant-registry-configmap.sh --apply
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT_PATH="${REPO_ROOT}/infrastructure/tenants/tenant-contracts.yml"
REGISTRY_CONFIGMAP_PATH="${REPO_ROOT}/deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml"

MODE="check"

usage() {
  cat <<'USAGE'
Usage: scripts/tenants/sync-tenant-registry-configmap.sh [--check|--apply]

Options:
  --check   Verify registry ConfigMap matches canonical tenant contract (default)
  --apply   Rewrite tenants.yaml block in ConfigMap from canonical contract
  -h, --help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$CONTRACT_PATH" ]]; then
  echo "FAIL tenant contract missing: $CONTRACT_PATH" >&2
  exit 1
fi

if [[ ! -f "$REGISTRY_CONFIGMAP_PATH" ]]; then
  echo "FAIL tenant registry ConfigMap missing: $REGISTRY_CONFIGMAP_PATH" >&2
  exit 1
fi

python3 - "$MODE" "$CONTRACT_PATH" "$REGISTRY_CONFIGMAP_PATH" <<'PY'
from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path

import yaml

mode = sys.argv[1]
contract_path = Path(sys.argv[2])
configmap_path = Path(sys.argv[3])


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def normalize_aliases(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    aliases: list[str] = []
    for item in value:
        if isinstance(item, str) and item.strip():
            aliases.append(item.strip())
    return sorted(set(aliases))


def placeholder_uuid(org_code: str | None, slug: str) -> str:
    token_source = (org_code or slug).upper()
    token = re.sub(r"[^A-Z0-9]+", "", token_source)
    if not token:
        token = "TENANT"
    return f"PLACEHOLDER-{token}-UUID"


contract_payload = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
tenants = contract_payload.get("tenants")
if not isinstance(tenants, list) or not tenants:
    fail("tenant contract has no tenants")

raw_cm_text = configmap_path.read_text(encoding="utf-8")
cm_docs = list(yaml.safe_load_all(raw_cm_text))
configmap = next(
    (doc for doc in cm_docs if isinstance(doc, dict) and doc.get("kind") == "ConfigMap"),
    None,
)
if configmap is None:
    fail("tenant registry file has no ConfigMap document")

blob = (configmap.get("data") or {}).get("tenants.yaml", "")
if not isinstance(blob, str):
    fail("tenant registry data.tenants.yaml is not a string")

existing_rows = yaml.safe_load(blob) or []
if not isinstance(existing_rows, list):
    fail("tenant registry tenants.yaml must decode to a list")

existing_by_slug: dict[str, dict] = {}
for row in existing_rows:
    if not isinstance(row, dict):
        continue
    slug = row.get("slug")
    if isinstance(slug, str) and slug:
        existing_by_slug[slug] = row

expected_rows: list[dict] = []
seen_registry_slugs: set[str] = set()
for tenant in tenants:
    if not isinstance(tenant, dict):
        continue
    if not tenant.get("active", True):
        continue

    slug = str(tenant.get("slug", "")).strip()
    registry_slug = str(tenant.get("registry_slug") or slug).strip()
    name = str(tenant.get("name", "")).strip()
    domains = tenant.get("domains") if isinstance(tenant.get("domains"), dict) else {}
    domain = str(domains.get("lms", "")).strip()
    aliases = normalize_aliases(tenant.get("aliases"))
    org_code = tenant.get("org_code")
    existing_entry = existing_by_slug.get(registry_slug, {})
    existing_uuid = ""
    if isinstance(existing_entry, dict):
        existing_uuid = str(existing_entry.get("enterprise_customer_uuid") or "").strip()

    if not slug:
        fail("tenant contract contains entry with empty slug")
    if not registry_slug:
        fail(f"{slug}: registry slug is empty")
    if registry_slug in seen_registry_slugs:
        fail(f"{slug}: duplicate registry_slug '{registry_slug}' in tenant contract")
    seen_registry_slugs.add(registry_slug)
    if not name:
        fail(f"{slug}: missing tenant name")
    if not domain:
        fail(f"{slug}: missing domains.lms")

    enterprise_uuid = existing_uuid or placeholder_uuid(
        str(org_code) if isinstance(org_code, str) else None,
        registry_slug,
    )

    expected_rows.append(
        {
            "slug": registry_slug,
            "name": name,
            "domain": domain,
            "enterprise_customer_uuid": enterprise_uuid,
            "active": True,
            "alias_domains": aliases,
        }
    )

expected_blob = yaml.safe_dump(
    expected_rows,
    sort_keys=False,
    default_flow_style=False,
).strip()
expected_block = "\n".join(f"    {line}" if line else "" for line in expected_blob.splitlines()) + "\n"

marker = "  tenants.yaml: |"
if marker not in raw_cm_text:
    fail("tenant registry ConfigMap missing 'tenants.yaml: |' marker")
prefix, _sep, _tail = raw_cm_text.partition(marker)
rendered_cm_text = prefix + marker + "\n" + expected_block

current_normalized = yaml.safe_dump(existing_rows, sort_keys=True, default_flow_style=False)
expected_normalized = yaml.safe_dump(expected_rows, sort_keys=True, default_flow_style=False)

if current_normalized == expected_normalized:
    print("PASS tenant registry ConfigMap is aligned with canonical tenant contract")
    raise SystemExit(0)

print("FAIL tenant registry ConfigMap drift detected vs tenant contract")
for line in difflib.unified_diff(
    current_normalized.splitlines(),
    expected_normalized.splitlines(),
    fromfile="current-tenants.yaml",
    tofile="expected-tenants.yaml",
    lineterm="",
):
    print(line)

if mode == "check":
    print("HINT run: ./scripts/tenants/sync-tenant-registry-configmap.sh --apply")
    raise SystemExit(1)

configmap_path.write_text(rendered_cm_text, encoding="utf-8")
print(f"APPLY updated tenant registry ConfigMap: {configmap_path}")
PY
