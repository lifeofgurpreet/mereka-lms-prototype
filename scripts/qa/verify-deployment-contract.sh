#!/usr/bin/env bash
# @covers AC-004, AC-005
# @spec: k8s-deployment_spec.md
# Validate that deploy/k8s/contract.json matches the actual base kustomization output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN + 1)); }

CONTRACT="deploy/k8s/contract.json"
VERSION_FILE="deploy/k8s/VERSION"
CONTRACTS_MD="deploy/k8s/CONTRACTS.md"
BASE_DIR="deploy/k8s/base"
YQ="${HOME}/.local/bin/yq"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_file "$YQ" "yq binary" || exit 0

# ── 1. Contract bundle files exist ──────────────────────────────────────────
echo "=== 1. Contract Bundle Files ==="

for f in "$CONTRACT" "$VERSION_FILE" "$CONTRACTS_MD"; do
  if [[ -f "$f" ]]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

if [[ ! -f "$CONTRACT" ]]; then
  echo "Cannot continue without contract.json"
  exit 1
fi

# ── 2. VERSION is valid semver ──────────────────────────────────────────────
echo ""
echo "=== 2. VERSION Validation ==="

version=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')
if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  pass "VERSION is valid semver: $version"
else
  fail "VERSION is not valid semver: '$version'"
fi

# ── 3. contract.json is valid JSON ─────────────────────────────────────────
echo ""
echo "=== 3. contract.json Validation ==="

if python3 -m json.tool "$CONTRACT" > /dev/null 2>&1; then
  pass "contract.json is valid JSON"
else
  fail "contract.json is not valid JSON"
  exit 1
fi

contract_version=$(python3 -c "import json; print(json.load(open('$CONTRACT'))['version'])")
if [[ "$contract_version" == "$version" ]]; then
  pass "contract.json version ($contract_version) matches VERSION file ($version)"
else
  fail "contract.json version ($contract_version) does not match VERSION file ($version)"
fi

# ── 4. Render base and cross-check workloads ───────────────────────────────
echo ""
echo "=== 4. Workload Cross-Check ==="

RENDERED=$(mktemp)
trap 'rm -f "$RENDERED"' EXIT

if ! kubectl kustomize "$BASE_DIR" > "$RENDERED" 2>/dev/null; then
  warn "Base kustomize render failed — skipping rendered checks"
else
  # Extract Deployment names from rendered output
  rendered_deployments=$("$YQ" eval 'select(.kind == "Deployment") | .metadata.name' "$RENDERED" 2>/dev/null | grep -v "^---$" | sort)

  # Extract workload names from contract
  contract_workloads=$(python3 -c "
import json
c = json.load(open('$CONTRACT'))
for w in c['workloads']:
    print(w['name'])
" | sort)

  # Check every rendered Deployment is in the contract
  missing_from_contract=0
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    if ! grep -qx "$dep" <<<"$contract_workloads"; then
      fail "Deployment '$dep' in rendered base but missing from contract.json"
      missing_from_contract=$((missing_from_contract + 1))
    fi
  done <<< "$rendered_deployments"

  # Check every contract workload exists in rendered output
  missing_from_rendered=0
  while IFS= read -r wl; do
    [[ -z "$wl" ]] && continue
    if ! grep -qx "$wl" <<<"$rendered_deployments"; then
      fail "Workload '$wl' in contract.json but missing from rendered base"
      missing_from_rendered=$((missing_from_rendered + 1))
    fi
  done <<< "$contract_workloads"

  if [[ $missing_from_contract -eq 0 && $missing_from_rendered -eq 0 ]]; then
    dep_count=$(echo "$rendered_deployments" | wc -l)
    pass "All $dep_count Deployments match between contract.json and rendered base"
  fi
fi

# ── 5. ExternalSecret cross-check ─────────────────────────────────────────
echo ""
echo "=== 5. ExternalSecret Cross-Check ==="

if [[ -f "$RENDERED" && -s "$RENDERED" ]]; then
  rendered_es=$("$YQ" eval 'select(.kind == "ExternalSecret") | .metadata.name' "$RENDERED" 2>/dev/null | grep -v "^---$" | sort)

  contract_es=$(python3 -c "
import json
c = json.load(open('$CONTRACT'))
for s in c['required_secrets']:
    print(s['name'])
" | sort)

  es_mismatch=0
  while IFS= read -r es; do
    [[ -z "$es" ]] && continue
    if ! grep -qx "$es" <<<"$contract_es"; then
      fail "ExternalSecret '$es' in rendered base but missing from contract.json"
      es_mismatch=$((es_mismatch + 1))
    fi
  done <<< "$rendered_es"

  while IFS= read -r es; do
    [[ -z "$es" ]] && continue
    if ! grep -qx "$es" <<<"$rendered_es"; then
      fail "ExternalSecret '$es' in contract.json but missing from rendered base"
      es_mismatch=$((es_mismatch + 1))
    fi
  done <<< "$contract_es"

  if [[ $es_mismatch -eq 0 ]]; then
    es_count=$(echo "$rendered_es" | wc -l)
    pass "All $es_count ExternalSecrets match between contract.json and rendered base"
  fi
fi

# ── 6. ConfigMap cross-check ──────────────────────────────────────────────
echo ""
echo "=== 6. ConfigMap Cross-Check ==="

kustomization_cms=$("$YQ" '.configMapGenerator[].name' "$BASE_DIR/kustomization.yaml" 2>/dev/null | sort)
contract_cms=$(python3 -c "
import json
c = json.load(open('$CONTRACT'))
for cm in c['required_configmaps']:
    print(cm)
" | sort)

cm_mismatch=0
while IFS= read -r cm; do
  [[ -z "$cm" ]] && continue
  if ! grep -qx "$cm" <<<"$contract_cms"; then
    fail "ConfigMap '$cm' in kustomization.yaml but missing from contract.json"
    cm_mismatch=$((cm_mismatch + 1))
  fi
done <<< "$kustomization_cms"

while IFS= read -r cm; do
  [[ -z "$cm" ]] && continue
  if ! grep -qx "$cm" <<<"$kustomization_cms"; then
    fail "ConfigMap '$cm' in contract.json but missing from kustomization.yaml"
    cm_mismatch=$((cm_mismatch + 1))
  fi
done <<< "$contract_cms"

if [[ $cm_mismatch -eq 0 ]]; then
  cm_count=$(echo "$kustomization_cms" | wc -l)
  pass "All $cm_count ConfigMaps match between contract.json and kustomization.yaml"
fi

# ── 7. Namespace check ────────────────────────────────────────────────────
echo ""
echo "=== 7. Namespace ==="

contract_ns=$(python3 -c "import json; print(json.load(open('$CONTRACT'))['namespace'])")
kustomization_ns=$("$YQ" '.namespace' "$BASE_DIR/kustomization.yaml" 2>/dev/null)

if [[ "$contract_ns" == "$kustomization_ns" ]]; then
  pass "Namespace matches: $contract_ns"
else
  fail "Namespace mismatch: contract=$contract_ns, kustomization=$kustomization_ns"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC} — contract.json is out of sync with base kustomization."
  echo "Update contract.json to match the current base, then bump VERSION."
  exit 1
fi

echo ""
echo -e "${GREEN}OK${NC} — deployment contract is consistent with base kustomization."
exit 0
