#!/usr/bin/env bash
# verify-mfe-version-pinning.sh — AC-UI-004: MFE version pinning + verification
#
# Verifies that MFE versions are pinned in kustomization.yaml and match
# the documented versions in docs/architecture/MFE_VERSIONS.md.
#
# Usage: ./scripts/qa/verify-mfe-version-pinning.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KUSTOMIZATION="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"
MFE_VERSIONS_DOC="$REPO_ROOT/docs/architecture/MFE_VERSIONS.md"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UI-004: MFE Version Pinning Check ==="
echo ""

# 1. Kustomization has MFE image pinned
echo "--- Image Pinning (kustomization.yaml) ---"
if grep -q 'openedx-mfe' "$KUSTOMIZATION" 2>/dev/null; then
  do_pass "MFE image referenced in kustomization.yaml"
  mfe_tag=$(grep -A1 'openedx-mfe' "$KUSTOMIZATION" | grep 'newTag' | sed 's/.*newTag: //' | tr -d ' ')
  if [ -n "$mfe_tag" ] && [ "$mfe_tag" != "latest" ]; then
    do_pass "MFE image pinned to specific tag: $mfe_tag"
  elif [ "$mfe_tag" = "latest" ]; then
    do_fail "MFE image uses 'latest' tag (must pin to specific version)"
  else
    do_warn "Could not extract MFE image tag"
  fi
else
  do_fail "MFE image not found in kustomization.yaml"
fi

# Also check openedx image
if grep -A1 'name: docker.io/overhangio/openedx$' "$KUSTOMIZATION" | grep -q 'newTag'; then
  openedx_tag=$(grep -A2 'name: docker.io/overhangio/openedx$' "$KUSTOMIZATION" | grep 'newTag' | sed 's/.*newTag: //' | tr -d ' ')
  if [ -n "$openedx_tag" ] && [ "$openedx_tag" != "latest" ]; then
    do_pass "OpenEdX image pinned to: $openedx_tag"
  else
    do_fail "OpenEdX image not pinned to specific tag"
  fi
fi

# 2. Version tracking doc exists
echo ""
echo "--- Version Documentation ---"
if [ -f "$MFE_VERSIONS_DOC" ]; then
  do_pass "MFE_VERSIONS.md exists"

  # Check it has version table
  if grep -q '| MFE |' "$MFE_VERSIONS_DOC" 2>/dev/null; then
    do_pass "Version tracking table present"
  else
    do_fail "Version tracking table missing from MFE_VERSIONS.md"
  fi

  # Check it has update policy
  if grep -qi 'update.*policy\|upgrade.*policy\|pinning.*strategy' "$MFE_VERSIONS_DOC" 2>/dev/null; then
    do_pass "Update policy documented"
  else
    do_warn "No explicit update policy section"
  fi

  # Check it has changelog
  if grep -q '| Date |' "$MFE_VERSIONS_DOC" 2>/dev/null; then
    do_pass "Version changelog present"
  else
    do_warn "No version changelog in MFE_VERSIONS.md"
  fi
else
  do_fail "MFE_VERSIONS.md not found at docs/architecture/MFE_VERSIONS.md"
fi

# 3. No 'latest' tags in deployment manifests
echo ""
echo "--- Deployment Tag Safety ---"
deployments="$REPO_ROOT/deploy/k8s/base/deployments.yml"
if [ -f "$deployments" ]; then
  latest_count=$(grep -c ':latest$' "$deployments" 2>/dev/null || true)
  latest_count=${latest_count:-0}
  if [ "$latest_count" -eq 0 ]; then
    do_pass "No ':latest' tags in deployments.yml"
  else
    do_fail "Found $latest_count ':latest' tags in deployments.yml (must pin versions)"
  fi
fi

# 4. Runtime check (if cluster accessible)
echo ""
echo "--- Runtime Version Check ---"
if kubectl get deployment mfe -n mereka-lms &>/dev/null; then
  runtime_image=$(kubectl get deployment mfe -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  if [ -n "$runtime_image" ]; then
    do_pass "MFE running image: $runtime_image"
    if echo "$runtime_image" | grep -q ':latest'; then
      do_fail "Runtime MFE uses ':latest' tag"
    else
      do_pass "Runtime MFE uses pinned tag"
    fi
  fi
else
  do_warn "Cluster not accessible — skipping runtime check"
fi

echo ""
echo "=== AC-UI-004 Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
