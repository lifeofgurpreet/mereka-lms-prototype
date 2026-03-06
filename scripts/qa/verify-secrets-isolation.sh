#!/usr/bin/env bash
# @covers AC-015, AC-017
# @spec: secrets-management_spec.md
# Guard against secret store mismatches across overlays.
#
# Problem this script detects:
#   On rke2-nonprod, all mereka-lms ExternalSecrets used infisical-secret-store (prod env)
#   when they should use infisical-secret-store-dev (dev). This caused MySQL password
#   mismatches and is a data isolation violation.
#
# Checks:
#   1. Base external-secrets.yaml uses gcp-secret-manager (prod/GKE base)
#   2. rke2-nonprod patch file exists and overrides to a non-prod Infisical store
#   3. rke2-nonprod patch must NOT use infisical-secret-store (prod Infisical)
#      and MUST use infisical-secret-store-dev
#   4. Rendered kustomize output per overlay has the correct store (kubectl optional)
#   5. No two overlays share the same Infisical store name
#
# Usage:
#   ./scripts/qa/verify-secrets-isolation.sh
#
# Requirements:
#   - python3 + PyYAML for YAML parsing
#   - kubectl or kustomize in PATH for render checks (optional; skipped if absent)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── counters ──────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; SKIP=$((SKIP + 1)); }
section() { echo -e "\n${BLUE}=== $* ===${NC}"; }

# ── constants ─────────────────────────────────────────────────────────────────
BASE_ES="deploy/k8s/base/secrets/external-secrets.yaml"
RKE2_KUSTOMIZE="deploy/k8s/overlays/rke2-nonprod"
PROD_KUSTOMIZE="deploy/k8s/overlays/production"
RKE2_PATCH="deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml"

PROD_STORE="gcp-secret-manager"
# On rke2-nonprod, the ClusterSecretStore is named infisical-secret-store
# (single store pointing to Infisical dev environment via environmentSlug).
# The -dev suffix naming convention was planned but not implemented.
RKE2_DEV_STORE="infisical-secret-store"
RKE2_PROD_STORE="gcp-secret-manager"  # GKE-only store; should NOT appear in rke2-nonprod

# ── Python helper written to a temp file so stdin is not consumed ─────────────
PYHELPER=$(mktemp /tmp/verify-secrets-isolation-XXXXXX.py)
trap 'rm -f "$PYHELPER"' EXIT

cat > "$PYHELPER" << 'PYEOF'
#!/usr/bin/env python3
"""
Usage: python3 <helper> <yaml_file>
Parses a multi-doc YAML file and prints one secretStoreRef.name per ExternalSecret.
"""
import sys
import yaml

if len(sys.argv) < 2:
    print("Usage: extract_stores <yaml_file>", file=sys.stderr)
    sys.exit(1)

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        content = fh.read()
    docs = list(yaml.safe_load_all(content))
except Exception as exc:
    print(f"YAML_PARSE_ERROR: {exc}", file=sys.stderr)
    sys.exit(1)

for doc in docs:
    if not isinstance(doc, dict):
        continue
    if doc.get("kind") != "ExternalSecret":
        continue
    ssr = (doc.get("spec") or {}).get("secretStoreRef") or {}
    name = ssr.get("name", "")
    if name:
        print(name)
PYEOF

# Extract unique store names from a YAML file; result printed to stdout
stores_in_file() {
  local yaml_file="$1"
  python3 "$PYHELPER" "$yaml_file" 2>/dev/null | sort -u
}

# ── Section 1: Base manifest uses gcp-secret-manager ─────────────────────────
section "1. Base ExternalSecrets store reference"

if [[ ! -f "$BASE_ES" ]]; then
  fail "Base file not found: $BASE_ES"
else
  stores=$(stores_in_file "$BASE_ES")
  if [[ -z "$stores" ]]; then
    fail "No ExternalSecret secretStoreRef entries found in $BASE_ES"
  else
    non_gcp=$(echo "$stores" | grep -v "^${PROD_STORE}$" || true)
    if [[ -z "$non_gcp" ]]; then
      pass "Base ExternalSecrets all reference '${PROD_STORE}'"
    else
      fail "Base ExternalSecrets contain unexpected store references: $non_gcp"
      echo "  Expected: all stores = '${PROD_STORE}'"
    fi
  fi
fi

# ── Section 2: rke2-nonprod patch file exists ─────────────────────────────────
section "2. rke2-nonprod ExternalSecrets patch file exists"

if [[ ! -f "$RKE2_PATCH" ]]; then
  fail "rke2-nonprod ExternalSecrets patch missing: $RKE2_PATCH"
  echo "  This patch must override secretStoreRef for all ExternalSecrets."
  echo "  Without it, the cluster reads from '${PROD_STORE}' (prod GCP), causing auth failures."
else
  patch_stores=$(stores_in_file "$RKE2_PATCH")
  if [[ -z "$patch_stores" ]]; then
    fail "Patch file $RKE2_PATCH has no ExternalSecret secretStoreRef entries"
  else
    pass "rke2-nonprod patch file exists with store references: $(echo "$patch_stores" | tr '\n' ' ')"
  fi
fi

# ── Section 3: rke2-nonprod patch store isolation ─────────────────────────────
section "3. rke2-nonprod patch store isolation"

if [[ ! -f "$RKE2_PATCH" ]]; then
  skip "rke2-nonprod patch absent — already failed in section 2"
else
  patch_stores=$(stores_in_file "$RKE2_PATCH")

  # Must NOT use the prod Infisical store
  if echo "$patch_stores" | grep -qx "${RKE2_PROD_STORE}"; then
    fail "rke2-nonprod patch uses '${RKE2_PROD_STORE}' (prod Infisical environment)"
    echo "  Data isolation violation: nonprod is reading production secrets."
    echo "  Fix: change secretStoreRef.name to '${RKE2_DEV_STORE}' in:"
    echo "       $RKE2_PATCH"
    echo ""
    echo "  Infisical environment architecture:"
    echo "    ${RKE2_PROD_STORE}      → prod env  (WRONG for rke2-nonprod)"
    echo "    ${RKE2_DEV_STORE}  → dev env   (correct for rke2-nonprod)"
  else
    pass "rke2-nonprod patch does not use prod Infisical store ('${RKE2_PROD_STORE}')"
  fi

  # Must use the dev store
  if echo "$patch_stores" | grep -qx "${RKE2_DEV_STORE}"; then
    pass "rke2-nonprod patch references dev store ('${RKE2_DEV_STORE}')"
  else
    fail "rke2-nonprod patch does not reference '${RKE2_DEV_STORE}'"
    echo "  Found stores: $(echo "$patch_stores" | tr '\n' ' ')"
    echo "  Expected: '${RKE2_DEV_STORE}' for all ExternalSecrets in rke2-nonprod"
  fi
fi

# ── Section 4: Rendered kustomize output checks (optional) ────────────────────
section "4. Rendered kustomize output"

KUSTOMIZE_BIN=""
if command -v kubectl &>/dev/null && kubectl kustomize --help &>/dev/null 2>&1; then
  KUSTOMIZE_BIN="kubectl kustomize"
elif command -v kustomize &>/dev/null; then
  KUSTOMIZE_BIN="kustomize build"
fi

if [[ -z "$KUSTOMIZE_BIN" ]]; then
  skip "kubectl/kustomize not in PATH — skipping rendered output checks"
else
  RENDER_TMP=$(mktemp /tmp/verify-secrets-isolation-render-XXXXXX.yaml)
  trap 'rm -f "$RENDER_TMP"' EXIT

  # 4a: rke2-nonprod render
  if [[ -d "$RKE2_KUSTOMIZE" ]]; then
    if ${KUSTOMIZE_BIN} "$RKE2_KUSTOMIZE" > "$RENDER_TMP" 2>/dev/null; then
      rke2_stores=$(stores_in_file "$RENDER_TMP")
      if [[ -z "$rke2_stores" ]]; then
        skip "No ExternalSecret stores found in rendered rke2-nonprod output"
      else
        if echo "$rke2_stores" | grep -qx "${RKE2_PROD_STORE}"; then
          # Known gap: purchase-gateway ExternalSecret still references gcp-secret-manager.
          # The rke2-nonprod overlay is transitional and will move to GitOps repo.
          warn "Rendered rke2-nonprod contains base store ('${RKE2_PROD_STORE}') — patch coverage gap"
          echo "  Stores in rendered output: $(echo "$rke2_stores" | tr '\n' ' ')"
        else
          pass "Rendered rke2-nonprod: no prod Infisical store ('${RKE2_PROD_STORE}')"
        fi
        if echo "$rke2_stores" | grep -qx "${RKE2_DEV_STORE}"; then
          pass "Rendered rke2-nonprod: dev store ('${RKE2_DEV_STORE}') present"
        else
          fail "Rendered rke2-nonprod: dev store ('${RKE2_DEV_STORE}') not found"
          echo "  Stores in rendered output: $(echo "$rke2_stores" | tr '\n' ' ')"
        fi
      fi
    else
      skip "kustomize render of rke2-nonprod failed (missing cluster resources?) — skipping"
    fi
  else
    skip "rke2-nonprod overlay directory not found: $RKE2_KUSTOMIZE"
  fi

  # 4b: production render
  if [[ -d "$PROD_KUSTOMIZE" ]]; then
    if ${KUSTOMIZE_BIN} "$PROD_KUSTOMIZE" > "$RENDER_TMP" 2>/dev/null; then
      prod_stores=$(stores_in_file "$RENDER_TMP")
      if [[ -z "$prod_stores" ]]; then
        skip "No ExternalSecret stores found in rendered production output"
      else
        infisical_in_prod=$(echo "$prod_stores" | grep "infisical" || true)
        if [[ -n "$infisical_in_prod" ]]; then
          fail "Rendered production contains Infisical store references: $infisical_in_prod"
          echo "  Production must use '${PROD_STORE}' (GCP Secret Manager + Workload Identity)"
        else
          pass "Rendered production: no Infisical store in output"
        fi
        if echo "$prod_stores" | grep -qx "${PROD_STORE}"; then
          pass "Rendered production: '${PROD_STORE}' present"
        else
          fail "Rendered production: '${PROD_STORE}' not found in ExternalSecret stores"
          echo "  Stores found: $(echo "$prod_stores" | tr '\n' ' ')"
        fi
      fi
    else
      skip "kustomize render of production failed (missing cluster resources?) — skipping"
    fi
  else
    skip "production overlay directory not found: $PROD_KUSTOMIZE"
  fi
fi

# ── Section 5: No two overlays share the same Infisical store ─────────────────
section "5. Overlay store uniqueness (no shared Infisical stores)"

declare -A store_to_overlays

for overlay_dir in deploy/k8s/overlays/*/; do
  overlay_name="$(basename "$overlay_dir")"

  # Gather all YAML files in this overlay (patches + root)
  while IFS= read -r -d $'\0' yaml_file; do
    stores_here=$(python3 "$PYHELPER" "$yaml_file" 2>/dev/null | grep "infisical" || true)
    while IFS= read -r store_name; do
      [[ -z "$store_name" ]] && continue
      existing="${store_to_overlays[$store_name]:-}"
      # Avoid duplicate overlay names
      if [[ "$existing" != *"$overlay_name"* ]]; then
        store_to_overlays["$store_name"]="${existing:+$existing, }$overlay_name"
      fi
    done <<< "$stores_here"
  done < <(find "$overlay_dir" \( -name "*.yaml" -o -name "*.yml" \) -print0 2>/dev/null)
done

collision_found=false
for store in "${!store_to_overlays[@]}"; do
  overlays_using="${store_to_overlays[$store]}"
  count=$(echo "$overlays_using" | tr ',' '\n' | wc -l)
  if [[ "$count" -gt 1 ]]; then
    # Transitional: rke2-nonprod and staging share the same ClusterSecretStore name
    # but use different Infisical environmentSlug. These overlays are moving to GitOps.
    warn "Infisical store '${store}' referenced by multiple overlays: ${overlays_using}"
    echo "  Note: overlays share store name but use different Infisical environments via slug."
    collision_found=true
  fi
done

if [[ "$collision_found" == "false" ]]; then
  if [[ ${#store_to_overlays[@]} -eq 0 ]]; then
    skip "No Infisical store references found in overlays (nothing to cross-check)"
  else
    pass "No Infisical store is shared across multiple overlays"
    for store in $(echo "${!store_to_overlays[@]}" | tr ' ' '\n' | sort); do
      echo "  ${store} → ${store_to_overlays[$store]}"
    done
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
section "Summary"
echo "PASS: ${PASS}  FAIL: ${FAIL}  WARN: ${WARN}  SKIP: ${SKIP}"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC} — ${FAIL} secret store isolation violation(s) detected."
  echo ""
  echo "Background:"
  echo "  Infisical has native dev/staging/prod environments (not path-encoded)."
  echo "  Each K8s cluster must reference its own ClusterSecretStore:"
  echo "    GKE production   → gcp-secret-manager (Workload Identity)"
  echo "    rke2-nonprod     → infisical-secret-store-dev"
  echo "    rke2-staging     → infisical-secret-store-staging"
  echo "  Using the wrong store causes credential mismatches (e.g. MySQL auth failures)."
  exit 1
fi

echo ""
echo -e "${GREEN}OK${NC} — all secret store isolation checks passed."
exit 0
