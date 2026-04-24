#!/usr/bin/env bash
# verify-overlay-ownership.sh — Verify overlay ownership boundaries
#
# Ensures that:
# 1. Non-local overlays carry deprecation notices
# 2. lane-identity.yaml declares overlay ownership correctly
# 3. contract.json declares overlay boundary
# 4. No CI workflows deploy from deprecated overlays
#
# Context: ArgoCD consumes overlays from bbi-infrastructure, not mereka-lms.
# The LMS repo's rke2-nonprod, staging, and production overlays are legacy
# and scheduled for removal in Wave 9.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "Overlay Ownership Verification"
echo "==============================="

OVERLAY_DIR="$REPO_ROOT/deploy/k8s/overlays"

# Deprecated overlays — these are NOT consumed by ArgoCD.
DEPRECATED_OVERLAYS="rke2-nonprod staging production"

# 1. Local overlay must exist (app-owned, for local dev)
if [[ -d "$OVERLAY_DIR/local" ]]; then
  pass "local overlay exists (app-owned)"
else
  fail "local overlay missing"
fi

# 2. Deprecated overlays must carry deprecation notice
for overlay in $DEPRECATED_OVERLAYS; do
  kustomization="$OVERLAY_DIR/$overlay/kustomization.yaml"
  if [[ -f "$kustomization" ]]; then
    if grep -qi "DEPRECATED\|LEGACY\|NOT consumed by ArgoCD\|boundary.debt" "$kustomization" 2>/dev/null; then
      pass "$overlay/kustomization.yaml carries deprecation notice"
    else
      fail "$overlay/kustomization.yaml missing deprecation notice"
    fi
  else
    warn "$overlay overlay directory missing (already removed?)"
  fi
done

# 3. lane-identity.yaml declares overlay_owner
LANE_IDENTITY="$REPO_ROOT/config/lane-identity.yaml"
if [[ -f "$LANE_IDENTITY" ]]; then
  if grep -q "overlay_owner" "$LANE_IDENTITY" 2>/dev/null; then
    pass "lane-identity.yaml declares overlay_owner"
  else
    warn "lane-identity.yaml missing overlay_owner field"
  fi
else
  fail "lane-identity.yaml missing"
fi

# 4. contract.json declares boundary ownership
CONTRACT="$REPO_ROOT/deploy/k8s/contract.json"
if [[ -f "$CONTRACT" ]]; then
  if python3 -c "
import json, sys
c = json.load(open('$CONTRACT'))
gi = c.get('gitops_identity', {})
if 'overlay_ownership' in gi or 'boundary_note' in gi:
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    pass "contract.json declares overlay boundary"
  else
    warn "contract.json missing overlay_ownership in gitops_identity"
  fi
else
  fail "contract.json missing"
fi

# 5. No CI workflows deploy from deprecated overlays
CI_DIR="$REPO_ROOT/.github/workflows"
if [[ -d "$CI_DIR" ]]; then
  violations=0
  for overlay in $DEPRECATED_OVERLAYS; do
    if grep -rn "kustomize build.*overlays/$overlay\|kubectl apply.*overlays/$overlay" "$CI_DIR" --include="*.yml" --include="*.yaml" 2>/dev/null; then
      fail "CI workflow deploys from deprecated overlay: $overlay"
      violations=$((violations + 1))
    fi
  done
  if [[ "$violations" -eq 0 ]]; then
    pass "no CI workflows deploy from deprecated overlays"
  fi
else
  warn ".github/workflows directory not found"
fi

# 6. README.md in overlays directory explains ownership
OVERLAY_README="$OVERLAY_DIR/README.md"
if [[ -f "$OVERLAY_README" ]]; then
  if grep -qi "bbi-infrastructure\|boundary\|deprecated\|ArgoCD" "$OVERLAY_README" 2>/dev/null; then
    pass "overlays/README.md explains ownership boundary"
  else
    warn "overlays/README.md exists but doesn't explain boundary"
  fi
else
  warn "overlays/README.md missing"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
[[ "$FAIL" -eq 0 ]] || exit 1
