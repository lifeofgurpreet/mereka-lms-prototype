#!/usr/bin/env bash
# verify-deployment-lanes.sh
#
# Verifies that the three active Kustomize overlay lanes are correctly structured
# and that the deprecated staging overlay is properly marked.
#
# See: docs/operations/DEPLOYMENT_LANES.md
#
# Usage:
#   ./scripts/qa/verify-deployment-lanes.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OVERLAYS_DIR="$REPO_ROOT/deploy/k8s/overlays"

PASS=0
FAIL=0
SKIP=0

pass() {
  echo "  PASS  $1"
  PASS=$(( PASS + 1 ))
}

fail() {
  echo "  FAIL  $1"
  FAIL=$(( FAIL + 1 ))
}

skip() {
  echo "  SKIP  $1"
  SKIP=$(( SKIP + 1 ))
}

echo "=== verify-deployment-lanes ==="
echo "Overlay root: $OVERLAYS_DIR"
echo ""

# ── 1. Active overlay directories exist ──────────────────────────────────────
echo "--- Active overlay directories ---"

for lane in local rke2-nonprod production; do
  overlay_dir="$OVERLAYS_DIR/$lane"
  if [[ -d "$overlay_dir" ]]; then
    pass "overlay directory exists: deploy/k8s/overlays/$lane/"
  else
    fail "overlay directory MISSING: deploy/k8s/overlays/$lane/"
  fi
done

# ── 2. Each active overlay has kustomization.yaml ────────────────────────────
echo ""
echo "--- Active overlay kustomization.yaml files ---"

for lane in local rke2-nonprod production; do
  kfile="$OVERLAYS_DIR/$lane/kustomization.yaml"
  if [[ -f "$kfile" ]]; then
    pass "kustomization.yaml exists: deploy/k8s/overlays/$lane/kustomization.yaml"
  else
    fail "kustomization.yaml MISSING: deploy/k8s/overlays/$lane/kustomization.yaml"
  fi
done

# ── 3. Active overlay kustomization.yaml files reference ../../base ───────────
echo ""
echo "--- Active overlays reference ../../base ---"

for lane in local rke2-nonprod production; do
  kfile="$OVERLAYS_DIR/$lane/kustomization.yaml"
  if [[ ! -f "$kfile" ]]; then
    skip "cannot check base ref (kustomization.yaml missing): $lane"
    continue
  fi
  if grep -q "../../base" "$kfile"; then
    pass "kustomization.yaml references ../../base: $lane"
  else
    fail "kustomization.yaml does NOT reference ../../base: $lane"
  fi
done

# ── 4. Staging overlay exists (historical artifact) ──────────────────────────
echo ""
echo "--- Deprecated staging overlay ---"

staging_dir="$OVERLAYS_DIR/staging"
staging_kfile="$staging_dir/kustomization.yaml"

if [[ -d "$staging_dir" ]]; then
  pass "staging overlay directory exists (historical artifact): deploy/k8s/overlays/staging/"
else
  fail "staging overlay directory missing — expected to be retained as historical artifact"
fi

# ── 5. Staging overlay has deprecation marker ─────────────────────────────────
if [[ -f "$staging_kfile" ]]; then
  if grep -qi "DEPRECATED" "$staging_kfile"; then
    pass "staging kustomization.yaml contains DEPRECATED marker"
  else
    fail "staging kustomization.yaml is MISSING a DEPRECATED marker (add '# DEPRECATED:' comment)"
  fi
else
  fail "staging kustomization.yaml not found — cannot verify deprecation marker"
fi

# ── 6. No active deploy/release scripts use staging as a deployment target ───
echo ""
echo "--- No active scripts deploy TO staging ---"

# Scripts that are known to legitimately reference the staging overlay for
# read-only contract checking or future-use CLI flags (not active deployment).
KNOWN_READ_ONLY=(
  "verify-gitops-image-overrides.sh"              # reads image tags for contract check
  "verify-release-dry-run-contract.sh"            # dry-run contract test
  "verify-staging-activation.sh"                  # checks activation prerequisites
  "audit-infra-mereka-lms-staging-references.sh"  # audit script
  "release-openedx-gitops.sh"                     # --target-env staging is a future flag, not currently active
  "verify-deployment-lanes.sh"                    # this script (contains the pattern string itself)
)

build_exclusion_pattern() {
  local pattern=""
  for name in "${KNOWN_READ_ONLY[@]}"; do
    pattern+="${pattern:+|}$name"
  done
  echo "$pattern"
}

EXCLUSION_PATTERN="$(build_exclusion_pattern)"

# Scan infra scripts for staging as an active deployment target.
# A "deployment" usage is one where the script writes to or deploys the staging overlay.
DEPLOY_STAGING_HITS=0

while IFS= read -r -d '' script_file; do
  # Skip known read-only scripts
  script_name="$(basename "$script_file")"
  if echo "$script_name" | grep -qE "$EXCLUSION_PATTERN"; then
    continue
  fi

  # Flag patterns that indicate the script treats staging as an active deploy target
  if grep -qE '(kubectl apply.*overlays/staging|kustomize build.*overlays/staging|--target-env staging|TARGET_ENV.*=.*staging)' \
       "$script_file" 2>/dev/null; then
    fail "script references staging as deployment target: $script_file"
    DEPLOY_STAGING_HITS=$(( DEPLOY_STAGING_HITS + 1 ))
  fi
done < <(find "$REPO_ROOT/scripts/infra" "$REPO_ROOT/scripts/qa" \
           -name "*.sh" -print0 2>/dev/null)

if [[ "$DEPLOY_STAGING_HITS" -eq 0 ]]; then
  pass "no active scripts deploy to staging overlay (excluding known read-only scripts)"
fi

# ── 7. rke2-nonprod has required patch files ──────────────────────────────────
echo ""
echo "--- rke2-nonprod required patches ---"

REQUIRED_PATCHES=(
  "patches/externalsecrets-infisical.yaml"
  "patches/domain-env.yaml"
  "patches/single-node-recreate-strategy.yaml"
)

for patch in "${REQUIRED_PATCHES[@]}"; do
  patch_file="$OVERLAYS_DIR/rke2-nonprod/$patch"
  if [[ -f "$patch_file" ]]; then
    pass "rke2-nonprod patch exists: $patch"
  else
    fail "rke2-nonprod patch MISSING: $patch"
  fi
done

# ── 8. DEPLOYMENT_LANES.md exists ─────────────────────────────────────────────
echo ""
echo "--- Documentation ---"

lanes_doc="$REPO_ROOT/docs/operations/DEPLOYMENT_LANES.md"
if [[ -f "$lanes_doc" ]]; then
  pass "DEPLOYMENT_LANES.md exists: docs/operations/DEPLOYMENT_LANES.md"
else
  fail "DEPLOYMENT_LANES.md MISSING: docs/operations/DEPLOYMENT_LANES.md"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL ($FAIL check(s) failed)"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
