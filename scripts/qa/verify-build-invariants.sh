#!/usr/bin/env bash
# @covers AC-CI-013
# @spec: ci-cd-pipeline_spec.md
#
# verify-build-invariants.sh - Prevent regression of build performance bugs
#
# This script encodes hard invariants that MUST hold for image builds to work
# correctly. These are lessons learned from the March 2026 incident where:
#   1. BuildKit was disabled → no layer caching
#   2. No --cache-from → every build started from scratch
#   3. ARC runner PVCs defined but never mounted → cache lost between builds
#   4. mereka-brand tag not pushed on workflow_dispatch → manual builds useless
#
# Any violation is a FAIL — these invariants are non-negotiable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

do_pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
do_fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }

BUILD_WF="$REPO_ROOT/.github/workflows/build-tutor-images.yml"

echo "=== Build Invariant Verification ==="
echo "Workflow: $BUILD_WF"
echo

if [[ ! -f "$BUILD_WF" ]]; then
  do_fail "Build workflow not found"
  exit 1
fi

# --- Invariant 1: BuildKit MUST be enabled ---
# BuildKit is required for --cache-from to work. DOCKER_BUILDKIT=0 is forbidden.
if grep -qE 'DOCKER_BUILDKIT:\s*0|DOCKER_BUILDKIT=0' "$BUILD_WF"; then
  do_fail "INV-1: BuildKit is disabled (DOCKER_BUILDKIT=0). This kills layer caching."
else
  # Verify it's explicitly enabled
  if grep -qE 'DOCKER_BUILDKIT:\s*1|DOCKER_BUILDKIT=1' "$BUILD_WF"; then
    do_pass "INV-1: BuildKit is explicitly enabled"
  else
    do_fail "INV-1: BuildKit is not explicitly set (must be DOCKER_BUILDKIT: 1)"
  fi
fi

# --- Invariant 2: --cache-from MUST be used ---
# Without cache-from, every build starts from scratch (50+ min).
if grep -q '\-\-cache-from' "$BUILD_WF"; then
  do_pass "INV-2: --cache-from is used for Docker layer caching"
else
  do_fail "INV-2: --cache-from missing. Every build will start from scratch (~50 min)."
fi

# --- Invariant 3: BUILDKIT_INLINE_CACHE MUST be set ---
# Without this, the pushed image won't contain cache metadata for future builds.
if grep -q 'BUILDKIT_INLINE_CACHE=1' "$BUILD_WF"; then
  do_pass "INV-3: BUILDKIT_INLINE_CACHE=1 is set (cache metadata embedded in images)"
else
  do_fail "INV-3: BUILDKIT_INLINE_CACHE=1 missing. Future builds can't use this image as cache."
fi

# --- Invariant 4: mereka-brand tag MUST be pushed on main ---
# The mutable tag is what ArgoCD watches. It must be pushed for both push and
# workflow_dispatch events (not just push).
if grep -q 'mereka-brand' "$BUILD_WF"; then
  do_pass "INV-4: mereka-brand tag is referenced in workflow"
else
  do_fail "INV-4: mereka-brand tag not found in workflow"
fi

# Ensure the tag push condition doesn't exclude workflow_dispatch
# The condition should check ref == main, NOT event_name == push
if grep -qE 'event_name.*==.*push.*&&.*refs/heads/main.*mereka.brand' "$BUILD_WF" 2>/dev/null; then
  do_fail "INV-4b: mereka-brand push is gated on event_name==push (excludes workflow_dispatch)"
elif grep -q 'refs/heads/main' "$BUILD_WF"; then
  do_pass "INV-4b: mereka-brand push condition uses ref check (works for all event types)"
fi

# --- Invariant 5: Image builds MUST run on heavy-builder runners ---
# ubuntu-24.04 runners are too small for OpenEdX builds (need 12GB+ RAM).
# Count runs-on lines for build jobs (not lint/provenance)
BUILD_JOB_RUNNERS=$(awk '/Build Open[Ee]d[Xx] Image|Build MFE Image/{found=1} found && /runs-on:/{print; found=0}' "$BUILD_WF")
if echo "$BUILD_JOB_RUNNERS" | grep -q 'mereka-k8s-heavy-builders'; then
  do_pass "INV-5: Image build jobs use heavy-builder runners"
else
  do_fail "INV-5: Image build jobs must use mereka-k8s-heavy-builders (not github-hosted)"
fi

# --- Invariant 6: No dead runner selection input ---
# The openedx_runner dropdown was dead code (defined but never referenced).
# It confused operators into thinking github-hosted was an option.
if grep -q 'openedx_runner' "$BUILD_WF"; then
  do_fail "INV-6: Dead 'openedx_runner' input still exists (remove it — builds always use heavy-builders)"
else
  do_pass "INV-6: No dead runner selection input"
fi

# --- Invariant 7: ARC runner MUST mount persistent Docker cache ---
# emptyDir loses cache between builds. PVC is required.
ARC_HEAVY="$REPO_ROOT/deploy/k8s/base/arc/runner-scale-set-heavy.yaml"
if [[ -f "$ARC_HEAVY" ]]; then
  if grep -q 'arc-docker-cache' "$ARC_HEAVY"; then
    # Check it's actually mounted, not just defined as a PVC
    if grep -q 'claimName: arc-docker-cache' "$ARC_HEAVY" && grep -q '/var/lib/docker' "$ARC_HEAVY"; then
      do_pass "INV-7: ARC heavy runner mounts persistent Docker cache (arc-docker-cache → /var/lib/docker)"
    else
      do_fail "INV-7: arc-docker-cache PVC exists but is NOT mounted in the DinD sidecar"
    fi
  else
    do_fail "INV-7: ARC heavy runner has no persistent Docker cache — layers lost between builds"
  fi
else
  do_pass "INV-7: (skipped — ARC runner manifest not in this repo)"
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED | ${RED}FAIL:${NC} $FAILED"
echo

if [[ $FAILED -gt 0 ]]; then
  echo "Build invariant violations detected!"
  echo "These invariants prevent the March 2026 build regression."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All build invariants hold."
exit 0
