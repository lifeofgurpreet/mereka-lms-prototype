#!/usr/bin/env bash
# verify-domain-authority-chain.sh — Ensures the domain authority chain is
# intact: tenant-registry.yaml is the canonical host-intent source,
# contract.json references it correctly, and the domain-authority-classification
# file is structurally valid.
#
# This is a static repo check — no running cluster required.
#
# Usage: ./scripts/qa/verify-domain-authority-chain.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/lib.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT" == "1" ]]; then
    FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} (strict) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

# Key files
TENANT_REGISTRY="$REPO_ROOT/deploy/k8s/tenancy/tenant-registry.yaml"
CONTRACT_JSON="$REPO_ROOT/deploy/k8s/contract.json"
DOMAIN_CLASSIFICATION="$REPO_ROOT/docs/reference/generated/domain-authority-classification.yaml"

printf "${BLUE}=== Domain Authority Chain Gate ===${NC}\n\n"

# ── 1. Canonical source exists and has required structure ─────────────────
printf "${BLUE}── 1. Tenant registry is canonical host-intent source ──${NC}\n"

if [[ -f "$TENANT_REGISTRY" ]]; then
  do_pass "tenant-registry.yaml exists"

  # Verify required top-level keys
  for key in version tenants environments domains; do
    if python3 -c "
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
if '$key' not in data:
    sys.exit(1)
" "$TENANT_REGISTRY" 2>/dev/null; then
      do_pass "tenant-registry.yaml has top-level key: $key"
    else
      do_fail "tenant-registry.yaml missing top-level key: $key"
    fi
  done

  # Extract version from registry
  REGISTRY_VERSION=$(python3 -c "
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
print(data.get('version', ''))
" "$TENANT_REGISTRY" 2>/dev/null || echo "")

  if [[ -n "$REGISTRY_VERSION" ]]; then
    do_pass "tenant-registry.yaml version: $REGISTRY_VERSION"
  else
    do_fail "tenant-registry.yaml has no version field"
  fi
else
  do_fail "tenant-registry.yaml not found: $TENANT_REGISTRY"
  REGISTRY_VERSION=""
fi

# ── 2. contract.json domain_registry.version matches registry ─────────────
printf "\n${BLUE}── 2. contract.json domain_registry version alignment ──${NC}\n"

if [[ -f "$CONTRACT_JSON" ]]; then
  do_pass "contract.json exists"

  CONTRACT_DOMAIN_VERSION=$(python3 -c "
import sys, json
data = json.load(open(sys.argv[1]))
dr = data.get('domain_registry', {})
print(dr.get('version', ''))
" "$CONTRACT_JSON" 2>/dev/null || echo "")

  if [[ -z "$CONTRACT_DOMAIN_VERSION" ]]; then
    do_warn "contract.json has no domain_registry.version (field may not exist yet)"
  elif [[ "$CONTRACT_DOMAIN_VERSION" == "$REGISTRY_VERSION" ]]; then
    do_pass "contract.json domain_registry.version ($CONTRACT_DOMAIN_VERSION) matches tenant-registry ($REGISTRY_VERSION)"
  else
    do_fail "contract.json domain_registry.version ($CONTRACT_DOMAIN_VERSION) != tenant-registry ($REGISTRY_VERSION)"
  fi
else
  do_fail "contract.json not found: $CONTRACT_JSON"
fi

# ── 3. Domain counts in contract.json match actual registry counts ────────
printf "\n${BLUE}── 3. Domain count alignment ──${NC}\n"

if [[ -f "$CONTRACT_JSON" && -f "$TENANT_REGISTRY" ]]; then
  while IFS=$'\t' read -r status msg; do
    case "$status" in
      PASS) do_pass "$msg" ;;
      FAIL) do_fail "$msg" ;;
      WARN) do_warn "$msg" ;;
    esac
  done < <(python3 - "$CONTRACT_JSON" "$TENANT_REGISTRY" <<'PY'
import sys
import json
import yaml

contract = json.load(open(sys.argv[1]))
registry = yaml.safe_load(open(sys.argv[2]))

dr = contract.get("domain_registry", {})
summary = dr.get("summary", {})

if not summary:
    print("WARN\tcontract.json has no domain_registry.summary (field may not exist yet)")
    sys.exit(0)

domains = registry.get("domains", [])
actual_total = len(domains)
actual_active = sum(1 for d in domains if d.get("status") == "active")

contract_total = summary.get("total_domains")
contract_active = summary.get("active_domains")

if contract_total is not None:
    if contract_total == actual_total:
        print(f"PASS\tcontract.json total_domains ({contract_total}) matches registry ({actual_total})")
    else:
        print(f"FAIL\tcontract.json total_domains ({contract_total}) != registry ({actual_total})")
else:
    print("WARN\tcontract.json domain_registry.summary.total_domains not set")

if contract_active is not None:
    if contract_active == actual_active:
        print(f"PASS\tcontract.json active_domains ({contract_active}) matches registry ({actual_active})")
    else:
        print(f"FAIL\tcontract.json active_domains ({contract_active}) != registry ({actual_active})")
else:
    print("WARN\tcontract.json domain_registry.summary.active_domains not set")
PY
  )
else
  if [[ ! -f "$CONTRACT_JSON" ]]; then
    do_fail "cannot check domain counts: contract.json missing"
  fi
  if [[ ! -f "$TENANT_REGISTRY" ]]; then
    do_fail "cannot check domain counts: tenant-registry.yaml missing"
  fi
fi

# ── 4. Domain authority classification file structure ─────────────────────
printf "\n${BLUE}── 4. Domain authority classification structure ──${NC}\n"

if [[ -f "$DOMAIN_CLASSIFICATION" ]]; then
  do_pass "domain-authority-classification.yaml exists"

  while IFS=$'\t' read -r status msg; do
    case "$status" in
      PASS) do_pass "$msg" ;;
      FAIL) do_fail "$msg" ;;
      WARN) do_warn "$msg" ;;
    esac
  done < <(python3 - "$DOMAIN_CLASSIFICATION" <<'PY'
import sys
import yaml

data = yaml.safe_load(open(sys.argv[1]))
if not isinstance(data, dict):
    print("FAIL\tdomain-authority-classification.yaml is not a YAML mapping")
    sys.exit(0)

# Check required top-level key
if "surfaces" in data:
    print("PASS\tdomain-authority-classification.yaml has key: surfaces")
else:
    print("FAIL\tdomain-authority-classification.yaml missing key: surfaces")
    sys.exit(0)

surfaces = data.get("surfaces", [])
if isinstance(surfaces, list) and len(surfaces) > 0:
    print(f"PASS\tdomain-authority-classification.yaml has {len(surfaces)} surface entries")
    # Check each surface has required fields
    classifications = set()
    for s in surfaces:
        if not isinstance(s, dict):
            print(f"FAIL\tsurface entry is not a mapping: {s}")
            continue
        if "path" not in s:
            print(f"FAIL\tsurface entry missing 'path' field")
        if "classification" not in s:
            print(f"FAIL\tsurface entry missing 'classification' field")
        else:
            classifications.add(s["classification"])
    if classifications:
        print(f"PASS\tclassifications found: {', '.join(sorted(classifications))}")
else:
    print("WARN\tdomain-authority-classification.yaml has no surface entries")
PY
  )
else
  do_warn "domain-authority-classification.yaml not found (may not exist yet): $DOMAIN_CLASSIFICATION"
fi

# ── 5. Historical files should not contain live hostnames ─────────────────
printf "\n${BLUE}── 5. Historical files must not contain live hostnames ──${NC}\n"

if [[ -f "$DOMAIN_CLASSIFICATION" && -f "$TENANT_REGISTRY" ]]; then
  while IFS=$'\t' read -r status msg; do
    case "$status" in
      PASS) do_pass "$msg" ;;
      FAIL) do_fail "$msg" ;;
      WARN) do_warn "$msg" ;;
    esac
  done < <(python3 - "$DOMAIN_CLASSIFICATION" "$TENANT_REGISTRY" "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

import yaml

classification = yaml.safe_load(open(sys.argv[1]))
registry = yaml.safe_load(open(sys.argv[2]))
repo_root = Path(sys.argv[3])

# Collect all active hostnames from registry
active_domains = set()
for d in registry.get("domains", []):
    if d.get("status") == "active":
        active_domains.add(d["domain"])

if not active_domains:
    print("WARN\tno active domains found in registry — skipping historical check")
    sys.exit(0)

surfaces = classification.get("surfaces", [])
historical_files = [s for s in surfaces if isinstance(s, dict) and s.get("classification") == "historical"]

if not historical_files:
    print("PASS\tno files classified as 'historical' — nothing to check")
    sys.exit(0)

found_any = False
for hf in historical_files:
    path = repo_root / hf["path"]
    if not path.exists():
        continue
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    for domain in active_domains:
        if domain in content:
            print(f"WARN\thistorical file {hf['path']} contains live hostname: {domain}")
            found_any = True

if not found_any:
    print("PASS\tno historical files contain live active hostnames")
PY
  )
else
  if [[ ! -f "$DOMAIN_CLASSIFICATION" ]]; then
    do_warn "cannot check historical files: domain-authority-classification.yaml missing"
  fi
  if [[ ! -f "$TENANT_REGISTRY" ]]; then
    do_fail "cannot check historical files: tenant-registry.yaml missing"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}=== Domain Authority Chain: ${PASS} PASS / ${FAIL} FAIL / ${WARN} WARN ===${NC}"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "\n${RED}GATE FAILED${NC} — $FAIL check(s) failed."
  exit 1
fi

echo -e "\n${GREEN}GATE PASSED${NC}"
exit 0
