#!/usr/bin/env bash
# @covers AC-CI-013
# @spec: ci-cd-pipeline_spec.md
#
# verify-build-invariants.sh - Prevent regression of build performance bugs
#
# This script encodes hard invariants that MUST hold for image builds to work
# correctly. These are lessons learned from the March 2026 incident where:
#   1. BuildKit was disabled → no layer caching
#   2. No reusable cache sources → every build started from scratch
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
ENTERPRISE_WF="$REPO_ROOT/.github/workflows/build-enterprise-mfe.yml"
OPENEDX_BLOCK="$(awk '/^  build-openedx:/{flag=1} /^  build-mfe:/{flag=0} flag' "$BUILD_WF")"
MFE_BLOCK="$(awk '/^  build-mfe:/{flag=1} /^  slsa-provenance:/{flag=0} flag' "$BUILD_WF")"
ENTERPRISE_ADMIN_UPDATE_BLOCK="$(awk '/^  update-dev-admin-portal:/{flag=1} /^  learner-portal:/{flag=0} flag' "$ENTERPRISE_WF" 2>/dev/null || true)"
ENTERPRISE_LEARNER_UPDATE_BLOCK="$(awk '/^  update-dev-learner-portal:/{flag=1} flag' "$ENTERPRISE_WF" 2>/dev/null || true)"

echo "=== Build Invariant Verification ==="
echo "Workflow: $BUILD_WF"
echo "Enterprise Workflow: $ENTERPRISE_WF"
echo

if [[ ! -f "$BUILD_WF" ]]; then
  do_fail "Build workflow not found"
  exit 1
fi

if [[ ! -f "$ENTERPRISE_WF" ]]; then
  do_fail "Enterprise build workflow not found"
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

# --- Invariant 2: Each Tutor image job MUST use the right buildx driver ---
# OpenEdX still depends on a loadable local-daemon image after the build, so it
# stays on the docker driver until Tutor no longer exports output=type=docker.
# MFE can use docker-container safely and gets first-class GHA cache reuse there.
if grep -q "driver: docker$" <<<"$OPENEDX_BLOCK"; then
  do_pass "INV-2a: OpenEdX build uses docker driver for reliable local image export"
else
  do_fail "INV-2a: OpenEdX build must use docker driver while Tutor still depends on local-daemon export"
fi

if grep -q "driver: docker-container$" <<<"$MFE_BLOCK"; then
  do_pass "INV-2b: MFE build uses docker-container driver for first-class GHA cache"
else
  do_fail "INV-2b: MFE build must use docker-container driver for first-class GHA cache"
fi

# --- Invariant 3: Must NOT use deprecated --cache-to-registry flag ---
# We rely on buildx-native cache exporters, not the old tutor-specific registry flag.
if grep -q '\-\-cache-to-registry' "$BUILD_WF"; then
  do_fail "INV-3: Deprecated --cache-to-registry flag found. Use buildx-native cache exporters instead."
else
  do_pass "INV-3: No deprecated --cache-to-registry flag"
fi

# --- Invariant 4: GHA cache read/write MUST stay scoped to the MFE build ---
# The MFE build benefits from BuildKit's persistent GHA cache path. OpenEdX
# currently must not use it because the docker-container export path regressed.
if grep -q -- '--cache-from=type=gha' <<<"$MFE_BLOCK" && grep -q -- '--cache-to=type=gha,mode=max' <<<"$MFE_BLOCK"; then
  do_pass "INV-4a: MFE build has GHA cache read/write flags"
else
  do_fail "INV-4a: MFE build is missing GHA cache read/write flags"
fi

if grep -q -- '--cache-from=type=gha' <<<"$OPENEDX_BLOCK" || grep -q -- '--cache-to=type=gha,mode=max' <<<"$OPENEDX_BLOCK"; then
  do_fail "INV-4b: OpenEdX build must not use GHA cache exporters while local-daemon export is required"
else
  do_pass "INV-4b: OpenEdX build correctly avoids GHA cache exporters"
fi

# --- Invariant 5: Registry cache reuse MUST be wired for both image builds ---
# Inline cache metadata in the last pushed image is the durable secondary warm path.
if grep -q -- '--cache-from=type=registry' <<<"$OPENEDX_BLOCK"; then
  do_pass "INV-5a: OpenEdX build has registry cache reuse wired"
else
  do_fail "INV-5a: OpenEdX build is missing registry cache reuse"
fi

if grep -q -- '--cache-from=type=registry' <<<"$MFE_BLOCK"; then
  do_pass "INV-5b: MFE build has registry cache reuse wired"
else
  do_fail "INV-5b: MFE build is missing registry cache reuse"
fi

# --- Invariant 6: mereka-brand tag MUST be pushed on main ---
# The mutable tag is what ArgoCD watches. It must be pushed for both push and
# workflow_dispatch events (not just push).
if grep -q 'mereka-brand' "$BUILD_WF"; then
  do_pass "INV-6: mereka-brand tag is referenced in workflow"
else
  do_fail "INV-6: mereka-brand tag not found in workflow"
fi

# Ensure the tag push condition doesn't exclude workflow_dispatch
# The condition should check ref == main, NOT event_name == push
if grep -qE 'event_name.*==.*push.*&&.*refs/heads/main.*mereka.brand' "$BUILD_WF" 2>/dev/null; then
  do_fail "INV-6b: mereka-brand push is gated on event_name==push (excludes workflow_dispatch)"
elif grep -q 'refs/heads/main' "$BUILD_WF"; then
  do_pass "INV-6b: mereka-brand push condition uses ref check (works for all event types)"
fi

# --- Invariant 7: Image builds MUST run on heavy-builder runners ---
# ubuntu-24.04 runners are too small for OpenEdX builds (need 12GB+ RAM).
# Count runs-on lines for build jobs (not lint/provenance)
BUILD_JOB_RUNNERS=$(awk '/Build Open[Ee]d[Xx] Image|Build MFE Image/{found=1} found && /runs-on:/{print; found=0}' "$BUILD_WF")
if echo "$BUILD_JOB_RUNNERS" | grep -q 'mereka-k8s-heavy-builders'; then
  do_pass "INV-7: Image build jobs use heavy-builder runners"
else
  do_fail "INV-7: Image build jobs must use mereka-k8s-heavy-builders (not github-hosted)"
fi

# --- Invariant 8: No dead runner selection input ---
# The openedx_runner dropdown was dead code (defined but never referenced).
# It confused operators into thinking github-hosted was an option.
if grep -q 'openedx_runner' "$BUILD_WF"; then
  do_fail "INV-8: Dead 'openedx_runner' input still exists (remove it — builds always use heavy-builders)"
else
  do_pass "INV-8: No dead runner selection input"
fi

# --- Invariant 9: ARC runner MUST mount persistent Docker cache ---
# emptyDir loses cache between builds. PVC is required.
ARC_HEAVY="$REPO_ROOT/deploy/k8s/base/arc/runner-scale-set-heavy.yaml"
if [[ -f "$ARC_HEAVY" ]]; then
  if grep -q 'arc-docker-cache' "$ARC_HEAVY"; then
    # Check it's actually mounted, not just defined as a PVC
    if grep -q 'claimName: arc-docker-cache' "$ARC_HEAVY" && grep -q '/var/lib/docker' "$ARC_HEAVY"; then
      do_pass "INV-9: ARC heavy runner mounts persistent Docker cache (arc-docker-cache → /var/lib/docker)"
    else
      do_fail "INV-9: arc-docker-cache PVC exists but is NOT mounted in the DinD sidecar"
    fi
  else
    do_fail "INV-9: ARC heavy runner has no persistent Docker cache — layers lost between builds"
  fi
else
  do_pass "INV-9: (skipped — ARC runner manifest not in this repo)"
fi

# --- Invariant 10: ExternalSecrets MUST use v1 apiVersion ---
# v1beta1 causes apiVersion mismatch with bbi-infrastructure vendored copy,
# making kustomize overlay patches silently fail (March 2026 ExternalSecret incident).
ES_FILE="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$ES_FILE" ]]; then
  if grep -q 'external-secrets.io/v1beta1' "$ES_FILE"; then
    do_fail "INV-10: ExternalSecrets use deprecated v1beta1 apiVersion (must use v1)"
  else
    do_pass "INV-10: ExternalSecrets use v1 apiVersion"
  fi
fi

# --- Invariant 11: Enterprise MFE builds MUST promote dev GitOps pins ---
# The enterprise portals are consumed from bbi-infrastructure overlay pins, not
# directly from the build output. A successful main build without an update-dev
# step leaves dev green on stale portal images.
if grep -q '^  update-dev-admin-portal:$' "$ENTERPRISE_WF" && grep -q '^  update-dev-learner-portal:$' "$ENTERPRISE_WF"; then
  do_pass "INV-11a: Enterprise workflow defines update-dev jobs for both portals"
else
  do_fail "INV-11a: Enterprise workflow must define update-dev jobs for admin and learner portals"
fi

if grep -q 'reusable-update-dev-tag.yml' <<<"$ENTERPRISE_ADMIN_UPDATE_BLOCK" \
  && grep -q 'reusable-update-dev-tag.yml' <<<"$ENTERPRISE_LEARNER_UPDATE_BLOCK"; then
  do_pass "INV-11b: Enterprise update-dev jobs use the reusable GitOps tag updater"
else
  do_fail "INV-11b: Enterprise update-dev jobs must use reusable-update-dev-tag.yml"
fi

if grep -q 'apps/mereka-lms/overlays/profiles/dev/kustomization.yaml' <<<"$ENTERPRISE_ADMIN_UPDATE_BLOCK" \
  && grep -q 'apps/mereka-lms/overlays/profiles/dev/kustomization.yaml' <<<"$ENTERPRISE_LEARNER_UPDATE_BLOCK"; then
  do_pass "INV-11c: Enterprise update-dev jobs target the dev profile overlay"
else
  do_fail "INV-11c: Enterprise update-dev jobs must write back to apps/mereka-lms/overlays/profiles/dev/kustomization.yaml"
fi

if grep -q 'enterprise-admin-portal' <<<"$ENTERPRISE_ADMIN_UPDATE_BLOCK" \
  && grep -q 'enterprise-learner-portal' <<<"$ENTERPRISE_LEARNER_UPDATE_BLOCK"; then
  do_pass "INV-11d: Enterprise update-dev jobs target the correct portal image names"
else
  do_fail "INV-11d: Enterprise update-dev jobs must target the admin and learner portal image names explicitly"
fi

if grep -q 'update-dev-admin-portal' <<<"$ENTERPRISE_LEARNER_UPDATE_BLOCK"; then
  do_pass "INV-11e: Enterprise learner update waits for admin update to avoid GitOps push races"
else
  do_fail "INV-11e: Enterprise learner update must depend on update-dev-admin-portal to serialize GitOps writes"
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
