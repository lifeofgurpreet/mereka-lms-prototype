#!/usr/bin/env bash
# @covers AC-DEP-002
# @spec: bead-8jao29
# verify-release-preflight.sh — Pre-deploy gating script
#
# Blocks deploy when config drift, patch drift, or gitops ref drift is detected.
# All checks are offline (source-time); no live cluster access required.
#
# Usage:
#   ./scripts/infra/verify-release-preflight.sh [--env prod|dev]
#
# Exit codes:
#   0 — all gates pass (PASS or WARN only)
#   1 — one or more gates failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV="${1:-}"
if [[ "$ENV" == "--env" ]]; then
  ENV="${2:-prod}"
  shift 2 2>/dev/null || true
else
  ENV="${ENV:-prod}"
fi

PASS=0
FAIL=0
WARN=0
RESULTS=()

pass() {
  local msg="$1"
  PASS=$((PASS + 1))
  RESULTS+=("PASS: $msg")
  echo "PASS: $msg"
}

fail() {
  local msg="$1"
  FAIL=$((FAIL + 1))
  RESULTS+=("FAIL: $msg")
  echo "FAIL: $msg"
}

warn() {
  local msg="$1"
  WARN=$((WARN + 1))
  RESULTS+=("WARN: $msg")
  echo "WARN: $msg"
}

echo "=== Release Preflight Gate ==="
echo "Environment: ${ENV} | Repo: ${REPO_ROOT}"
echo ""

# ── Gate 1: Config parity ─────────────────────────────────────────────────
echo "-- Gate 1: Config parity"

CONFIG_EXAMPLE="${REPO_ROOT}/infrastructure/tutor/config.example.yml"
if [[ -f "${CONFIG_EXAMPLE}" ]]; then
  pass "Config template exists: infrastructure/tutor/config.example.yml"
else
  fail "Config template missing: infrastructure/tutor/config.example.yml"
fi

# Check that tutor_env/config.yml is gitignored (should not be committed)
GITIGNORE="${REPO_ROOT}/.gitignore"
if [[ -f "${GITIGNORE}" ]]; then
  TUTOR_ENV_IGNORED=$(grep -c "tutor_env/" "${GITIGNORE}" 2>/dev/null || echo 0)
  if [[ "${TUTOR_ENV_IGNORED}" -gt 0 ]]; then
    pass "tutor_env/ is gitignored (secrets not committed)"
  else
    fail "tutor_env/ is NOT gitignored — config.yml may contain secrets"
  fi
else
  warn ".gitignore not found"
fi

# Check no cloud IPs leaked into any committed config file
COMMITTED_CLOUD_IPS_RAW=$(git -C "${REPO_ROOT}" grep -l "MYSQL_HOST.*10\.\|MONGODB_HOST.*10\.\|REDIS_HOST.*10\." \
  -- '*.yml' '*.yaml' '*.py' 2>/dev/null | grep -v tutor_env/ || true)
COMMITTED_CLOUD_IPS=$(echo "${COMMITTED_CLOUD_IPS_RAW}" | grep -c . || echo 0)
COMMITTED_CLOUD_IPS="${COMMITTED_CLOUD_IPS//[[:space:]]/}"
if [[ "${COMMITTED_CLOUD_IPS}" -eq 0 ]]; then
  pass "No committed files reference cloud IPs for MYSQL/MONGODB/REDIS hosts"
else
  fail "Cloud IPs found in committed config files (${COMMITTED_CLOUD_IPS} files) — run tutor-config-save.sh"
fi

echo ""

# ── Gate 2: apply-patches.sh drift ────────────────────────────────────────
echo "-- Gate 2: apply-patches.sh drift"

APPLY_PATCHES="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"
if [[ -x "${APPLY_PATCHES}" ]]; then
  pass "apply-patches.sh exists and is executable"
else
  fail "apply-patches.sh missing or not executable: ${APPLY_PATCHES}"
fi

VERIFY_CONFIG="${REPO_ROOT}/scripts/infra/verify-tutor-config.sh"
if [[ -f "${VERIFY_CONFIG}" ]]; then
  pass "verify-tutor-config.sh exists"
else
  warn "verify-tutor-config.sh not found (optional verification script)"
fi

# Check patch script has not drifted from committed state
if git -C "${REPO_ROOT}" diff --name-only HEAD -- infrastructure/tutor/apply-patches.sh 2>/dev/null | grep -q .; then
  fail "apply-patches.sh has uncommitted changes — commit or stash before deploy"
else
  pass "apply-patches.sh is clean (no uncommitted changes)"
fi

# Check patch script covers key required patches
REQUIRED_PATCHES=(
  "mysql_native_password"
  "NODE_OPTIONS"
  "MONGODB_USE_SSL"
)
for patch in "${REQUIRED_PATCHES[@]}"; do
  if grep -q "${patch}" "${APPLY_PATCHES}" 2>/dev/null; then
    pass "apply-patches.sh contains required patch: ${patch}"
  else
    warn "apply-patches.sh may be missing patch token: ${patch}"
  fi
done

echo ""

# ── Gate 3: GitOps ref sync ────────────────────────────────────────────────
echo "-- Gate 3: GitOps ref sync"

PROD_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
if [[ -f "${PROD_KUSTOMIZATION}" ]]; then
  pass "Production kustomization.yaml exists"

  # Verify no 'latest' tag in production overlay
  LATEST_COUNT=0
  if grep -q "newTag:.*latest" "${PROD_KUSTOMIZATION}" 2>/dev/null; then
    LATEST_COUNT=$(grep -c "newTag:.*latest" "${PROD_KUSTOMIZATION}" 2>/dev/null || echo 1)
    LATEST_COUNT="${LATEST_COUNT//[[:space:]]/}"
  fi
  if [[ "${LATEST_COUNT}" -eq 0 ]]; then
    pass "No mutable 'latest' tags in production kustomization"
  else
    fail "Production kustomization contains 'latest' tag (${LATEST_COUNT} occurrences) — pin to immutable tag"
  fi

  # Verify image names use canonical registry
  ARTIFACT_REGISTRY="ghcr.io/biji-biji-initiative/mereka-lms"
  CANONICAL_COUNT=$(grep -c "${ARTIFACT_REGISTRY}" "${PROD_KUSTOMIZATION}" 2>/dev/null || echo 0)
  if [[ "${CANONICAL_COUNT}" -gt 0 ]]; then
    pass "Production kustomization references Artifact Registry (${CANONICAL_COUNT} entries)"
  else
    warn "Production kustomization may not reference Artifact Registry — verify image names"
  fi
else
  fail "Production kustomization.yaml missing: deploy/k8s/overlays/production/kustomization.yaml"
fi

# Check for uncommitted changes to deploy manifests
DEPLOY_DIRTY=$(git -C "${REPO_ROOT}" diff --name-only HEAD -- deploy/k8s/ 2>/dev/null | wc -l || echo 0)
if [[ "${DEPLOY_DIRTY}" -eq 0 ]]; then
  pass "deploy/k8s/ has no uncommitted changes"
else
  warn "deploy/k8s/ has ${DEPLOY_DIRTY} uncommitted file(s) — ensure they are intentional"
fi

echo ""

# ── Gate 4: Overlay consistency ───────────────────────────────────────────
echo "-- Gate 4: Overlay consistency"

VERIFY_OVERRIDES="${REPO_ROOT}/scripts/qa/verify-gitops-image-overrides.sh"
if [[ -x "${VERIFY_OVERRIDES}" ]]; then
  # Auto mode checks local infra checkout when present (cross-repo drift guard),
  # otherwise it skips infra checks gracefully.
  OVERRIDE_OUT=$("${VERIFY_OVERRIDES}" 2>&1) && RC=0 || RC=$?
  if [[ "${RC}" -eq 0 ]]; then
    pass "GitOps image override contract satisfied"
  elif [[ "${CI:-}" == "true" ]]; then
    # Cross-repo drift is a real failure even in CI. If the infra repo was not
    # available, verify-gitops-image-overrides.sh --skip-infra would have passed.
    # If we get here, infra was checked and drift was found.
    fail "GitOps image override drift (cross-repo): $(echo "${OVERRIDE_OUT}" | head -3)"
  else
    fail "GitOps image override contract violated: $(echo "${OVERRIDE_OUT}" | head -5)"
  fi
else
  warn "verify-gitops-image-overrides.sh not found or not executable"
fi

# Check base kustomization exists
BASE_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"
if [[ -f "${BASE_KUSTOMIZATION}" ]]; then
  pass "Base kustomization.yaml exists"
else
  fail "Base kustomization.yaml missing: deploy/k8s/base/kustomization.yaml"
fi

# Check staging overlay exists (parity)
STAGING_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/staging/kustomization.yaml"
if [[ -f "${STAGING_KUSTOMIZATION}" ]]; then
  pass "Staging kustomization.yaml exists"
else
  warn "Staging kustomization.yaml missing (optional if staging env is disabled)"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────
echo "=== Preflight Summary ==="
for result in "${RESULTS[@]}"; do
  echo "  ${result}"
done
echo ""
echo "Gates: PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"

if [[ "${FAIL}" -gt 0 ]]; then
  echo ""
  echo "RESULT: BLOCKED — ${FAIL} preflight gate(s) failed. Fix issues before deploying."
  exit 1
fi

echo ""
echo "RESULT: CLEAR — all preflight gates passed. Proceed with deploy."
exit 0
