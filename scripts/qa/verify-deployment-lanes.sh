#!/usr/bin/env bash
# @covers AC-001
# @spec: k8s-deployment_spec.md
# verify-deployment-lanes.sh
#
# Verifies the current deployment-lane truth for this repo:
# - local is the only app-owned live overlay
# - dev and staging are distinct environment truths on shared rke2-nonprod
# - prod exists as a parked GKE lane
# - non-local overlays in this repo are reference artifacts, not ArgoCD sources
#
# See: docs/reference/operations/DEPLOYMENT_LANES.md
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
echo "--- Overlay directories exist ---"

for lane in local rke2-nonprod staging production; do
  overlay_dir="$OVERLAYS_DIR/$lane"
  if [[ -d "$overlay_dir" ]]; then
    pass "overlay directory exists: deploy/k8s/overlays/$lane/"
  else
    fail "overlay directory MISSING: deploy/k8s/overlays/$lane/"
  fi
done

# ── 2. Each active overlay has kustomization.yaml ────────────────────────────
echo ""
echo "--- Overlay kustomization.yaml files exist ---"

for lane in local rke2-nonprod staging production; do
  kfile="$OVERLAYS_DIR/$lane/kustomization.yaml"
  if [[ -f "$kfile" ]]; then
    pass "kustomization.yaml exists: deploy/k8s/overlays/$lane/kustomization.yaml"
  else
    fail "kustomization.yaml MISSING: deploy/k8s/overlays/$lane/kustomization.yaml"
  fi
done

# ── 3. Active overlay kustomization.yaml files reference ../../base ───────────
echo ""
echo "--- Overlays reference ../../base ---"

for lane in local rke2-nonprod staging production; do
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

# ── 4. Non-local overlays are reference artifacts, not ArgoCD sources ────────
echo ""
echo "--- Non-local overlays are reference artifacts ---"

check_reference_overlay() {
  local lane="$1"
  local expected_source="$2"
  local kfile="$OVERLAYS_DIR/$lane/kustomization.yaml"
  if [[ ! -f "$kfile" ]]; then
    skip "cannot check reference overlay contract (missing): $lane"
    return
  fi
  if grep -Fq "NOT consumed by ArgoCD" "$kfile"; then
    pass "$lane overlay is marked as not consumed by ArgoCD"
  else
    fail "$lane overlay is missing the 'NOT consumed by ArgoCD' marker"
  fi
  if grep -Fq "$expected_source" "$kfile"; then
    pass "$lane overlay points operators at $expected_source"
  else
    fail "$lane overlay does not point to $expected_source"
  fi
}

check_reference_overlay rke2-nonprod "apps/mereka-lms/overlays/dev/"
check_reference_overlay staging "apps/mereka-lms/overlays/staging/"
check_reference_overlay production "apps/mereka-lms/overlays/prod/"

# ── 5. Topology markers reflect the real lane model ──────────────────────────
echo ""
echo "--- Topology markers reflect current truth ---"

if grep -Fq "Shares cluster with dev (rke2-nonprod)" "$OVERLAYS_DIR/staging/kustomization.yaml"; then
  pass "staging overlay documents shared rke2-nonprod cluster"
else
  fail "staging overlay is missing shared-cluster truth marker"
fi

if grep -Fq "GKE prod is scaled to zero replicas" "$OVERLAYS_DIR/production/kustomization.yaml"; then
  pass "production overlay documents parked zero-replica GKE state"
else
  fail "production overlay is missing parked-prod truth marker"
fi

if grep -Fq "rke2-nonprod overlay — bbi-infrastructure dev/staging cluster" "$OVERLAYS_DIR/rke2-nonprod/kustomization.yaml"; then
  pass "rke2-nonprod overlay documents shared dev/staging cluster role"
else
  fail "rke2-nonprod overlay is missing shared dev/staging truth marker"
fi

# ── 6. No active deploy/release scripts use app-repo non-local overlays ─────
echo ""
echo "--- No active scripts deploy non-local overlays from this repo ---"

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

# Scan scripts for non-local overlays from this repo as active deployment targets.
DEPLOY_NONLOCAL_HITS=0

while IFS= read -r -d '' script_file; do
  # Skip known read-only scripts
  script_name="$(basename "$script_file")"
  if echo "$script_name" | grep -qE "$EXCLUSION_PATTERN"; then
    continue
  fi

  # Flag patterns that indicate the script treats a non-local app-repo overlay as an active deploy target
  if grep -qE '(kubectl apply.*deploy/k8s/overlays/(rke2-nonprod|staging|production)|kustomize build.*deploy/k8s/overlays/(rke2-nonprod|staging|production))' \
       "$script_file" 2>/dev/null; then
    fail "script deploys a non-local app-repo overlay directly: $script_file"
    DEPLOY_NONLOCAL_HITS=$(( DEPLOY_NONLOCAL_HITS + 1 ))
  fi
done < <(find "$REPO_ROOT/scripts/infra" "$REPO_ROOT/scripts/qa" \
           -name "*.sh" -print0 2>/dev/null)

if [[ "$DEPLOY_NONLOCAL_HITS" -eq 0 ]]; then
  pass "no active scripts deploy non-local app-repo overlays directly"
fi

# ── 7. Reference overlays keep expected patch anchors ─────────────────────────
echo ""
echo "--- rke2-nonprod required patches ---"

REQUIRED_PATCHES=(
  "patches/externalsecrets-infisical.yaml"
  "patches/domain-env.yaml"
  "patches/enterprise-catalog-worker-nonprod.yaml"
)

for patch in "${REQUIRED_PATCHES[@]}"; do
  patch_file="$OVERLAYS_DIR/rke2-nonprod/$patch"
  if [[ -f "$patch_file" ]]; then
    pass "rke2-nonprod patch exists: $patch"
  else
    fail "rke2-nonprod patch MISSING: $patch"
  fi
done

# ── 8. Docs encode current lane truth ─────────────────────────────────────────
echo ""
echo "--- Documentation ---"

lanes_doc="$REPO_ROOT/docs/reference/operations/DEPLOYMENT_LANES.md"
if [[ -f "$lanes_doc" ]]; then
  pass "DEPLOYMENT_LANES.md exists: docs/reference/operations/DEPLOYMENT_LANES.md"
  if grep -Fq "ArgoCD does not deploy from \`deploy/k8s/overlays/*\`" "$lanes_doc" && \
     grep -Fq "Non-local deployment is realized in" "$lanes_doc"; then
    pass "DEPLOYMENT_LANES.md documents ArgoCD ownership boundary"
  else
    fail "DEPLOYMENT_LANES.md is missing the ArgoCD ownership boundary"
  fi
  if grep -Fq "shared \`rke2-nonprod\`" "$lanes_doc"; then
    pass "DEPLOYMENT_LANES.md documents shared rke2-nonprod truth"
  else
    fail "DEPLOYMENT_LANES.md is missing shared rke2-nonprod truth"
  fi
  if grep -Eq 'Parked / explicit promotion only|zero replicas' "$lanes_doc"; then
    pass "DEPLOYMENT_LANES.md documents parked prod truth"
  else
    fail "DEPLOYMENT_LANES.md is missing parked prod truth"
  fi
else
  fail "DEPLOYMENT_LANES.md MISSING: docs/reference/operations/DEPLOYMENT_LANES.md"
fi

deployment_doc="$REPO_ROOT/deploy/DEPLOYMENT.md"
if [[ -f "$deployment_doc" ]]; then
  pass "deploy/DEPLOYMENT.md exists"
  if grep -Fq "Dev and staging are realized in \`bbi-infrastructure\` on the shared \`rke2-nonprod\` cluster." "$deployment_doc"; then
    pass "deploy/DEPLOYMENT.md documents shared nonprod environment realization"
  else
    fail "deploy/DEPLOYMENT.md is missing shared nonprod environment realization"
  fi
else
  fail "deploy/DEPLOYMENT.md missing"
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
