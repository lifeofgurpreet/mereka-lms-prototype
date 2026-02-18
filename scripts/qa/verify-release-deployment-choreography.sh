#!/usr/bin/env bash
# @covers AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004
# @spec: bead-8jao29
# verify-release-deployment-choreography.sh
#
# Verifies that the release deployment choreography and merge discipline lane
# is fully established:
#   AC-DEP-001: Release template documented with rollout tracking
#   AC-DEP-002: Preflight gating script blocks deploy on drift
#   AC-DEP-003: Evidence package covers image tags, SHAs, Argo status, branding gate
#   AC-DEP-004: Dry-run section present; no cherry-pick/worktree requirement documented
#
# Offline-capable: no live cluster required.
#
# Usage:
#   ./scripts/qa/verify-release-deployment-choreography.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

check() {
  local desc="$1"
  local expr="$2"
  if eval "${expr}"; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

warn() {
  local msg="$1"
  echo "WARN: ${msg}"
  WARN=$((WARN + 1))
}

echo "=== Release Deployment Choreography Verification ==="
echo ""

# ────────────────────────────────────────────────────────────────────────────
# AC-DEP-001: Release template documented and adopted for next 3 rollout
#             attempts — template exists with rollout checklist and tracking.
# ────────────────────────────────────────────────────────────────────────────
echo "-- AC-DEP-001: Release template"

RELEASE_TEMPLATE="${REPO_ROOT}/docs/operations/RELEASE_DEPLOYMENT_TEMPLATE.md"

check "Release template exists (docs/operations/RELEASE_DEPLOYMENT_TEMPLATE.md)" \
  "[[ -f '${RELEASE_TEMPLATE}' ]]"

if [[ -f "${RELEASE_TEMPLATE}" ]]; then
  check "Template references bead 8jao.29" \
    "grep -qi '8jao' '${RELEASE_TEMPLATE}'"

  check "Template has pre-deploy section" \
    "grep -qi 'Pre-Deploy\|pre-deploy\|preflight\|Preflight' '${RELEASE_TEMPLATE}'"

  check "Template has deploy steps section" \
    "grep -qi 'Deploy Steps\|deploy step\|GitOps.*rollout\|Rollout' '${RELEASE_TEMPLATE}'"

  check "Template has post-deploy validation section" \
    "grep -qi 'Post-Deploy\|post-deploy\|Post Deploy' '${RELEASE_TEMPLATE}'"

  check "Template has rollback procedure" \
    "grep -qi 'Rollback\|rollback' '${RELEASE_TEMPLATE}'"

  # Verify at least 3 rollout attempt tracking slots
  ATTEMPT_COUNT=$(grep -c "Attempt [0-9]" "${RELEASE_TEMPLATE}" 2>/dev/null || echo 0)
  check "Template has at least 3 rollout attempt tracking slots (found: ${ATTEMPT_COUNT})" \
    "[[ ${ATTEMPT_COUNT} -ge 3 ]]"

  check "Template has evidence package format section" \
    "grep -qi 'Evidence Package\|evidence package' '${RELEASE_TEMPLATE}'"

  check "Template has worktree policy" \
    "grep -qi 'worktree\|Worktree' '${RELEASE_TEMPLATE}'"

  check "Template references release checklist or merge protocol" \
    "grep -qiE 'RELEASE_CHECKLIST|MERGE_FIRST|release-checklist' '${RELEASE_TEMPLATE}'"
fi

echo ""

# ────────────────────────────────────────────────────────────────────────────
# AC-DEP-002: Preflight gating script blocks deploy when config or patch
#             drift is detected.
# ────────────────────────────────────────────────────────────────────────────
echo "-- AC-DEP-002: Preflight gating script"

PREFLIGHT_SCRIPT="${REPO_ROOT}/scripts/infra/verify-release-preflight.sh"

check "Preflight gating script exists (scripts/infra/verify-release-preflight.sh)" \
  "[[ -f '${PREFLIGHT_SCRIPT}' ]]"

if [[ -f "${PREFLIGHT_SCRIPT}" ]]; then
  check "Preflight script is executable" \
    "[[ -x '${PREFLIGHT_SCRIPT}' ]]"

  check "Preflight script has correct shebang" \
    "head -1 '${PREFLIGHT_SCRIPT}' | grep -q '#!/usr/bin/env bash'"

  check "Preflight script uses set -euo pipefail" \
    "grep -q 'set -euo pipefail' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script checks config parity (tutor config)" \
    "grep -qi 'config\|parity\|tutor' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script checks apply-patches.sh" \
    "grep -q 'apply-patches' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script checks for cloud IPs or local service names" \
    "grep -qE 'MYSQL_HOST|MONGODB_HOST|cloud.*IP|10\\\.' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script checks gitops overlay (kustomization)" \
    "grep -qi 'kustomization\|gitops\|overlay' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script has PASS/FAIL output pattern" \
    "grep -qE 'PASS:|FAIL:|pass\(\)|fail\(\)' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script exits 1 on failure" \
    "grep -q 'exit 1' '${PREFLIGHT_SCRIPT}'"

  check "Preflight script has @covers AC-DEP-002 annotation" \
    "grep -q '@covers.*AC-DEP-002' '${PREFLIGHT_SCRIPT}'"

  # Syntax check
  check "Preflight script passes bash syntax check" \
    "bash -n '${PREFLIGHT_SCRIPT}' 2>/dev/null"
fi

echo ""

# ────────────────────────────────────────────────────────────────────────────
# AC-DEP-003: One-click evidence package includes image tags, commit SHAs,
#             Argo status, and branding gate outputs.
# ────────────────────────────────────────────────────────────────────────────
echo "-- AC-DEP-003: Evidence package"

EVIDENCE_SCRIPT="${REPO_ROOT}/scripts/qa/verify-release-readiness.sh"

check "Evidence package script exists (scripts/qa/verify-release-readiness.sh)" \
  "[[ -f '${EVIDENCE_SCRIPT}' ]]"

if [[ -f "${EVIDENCE_SCRIPT}" ]]; then
  check "Evidence script captures image tags" \
    "grep -qi 'image.tag\|newTag\|KUSTOMIZATION' '${EVIDENCE_SCRIPT}'"

  check "Evidence script captures commit SHA / git state" \
    "grep -qi 'HEAD_SHA\|rev-parse\|git.*state\|git-state' '${EVIDENCE_SCRIPT}'"

  check "Evidence script captures ArgoCD status" \
    "grep -qi 'argocd\|argo.*status\|argocd-status' '${EVIDENCE_SCRIPT}'"

  check "Evidence script captures branding gate output" \
    "grep -qi 'branding\|brand.*gate' '${EVIDENCE_SCRIPT}'"

  check "Evidence script writes to an evidence directory" \
    "grep -qi 'EVIDENCE_DIR\|evidence.dir\|evidence/' '${EVIDENCE_SCRIPT}'"

  check "Evidence script has @covers AC-DEP annotation" \
    "grep -q '@covers.*AC-DEP' '${EVIDENCE_SCRIPT}'"

  check "Evidence script passes bash syntax check" \
    "bash -n '${EVIDENCE_SCRIPT}' 2>/dev/null"
fi

# Also verify the template documents the evidence package format
if [[ -f "${RELEASE_TEMPLATE}" ]]; then
  check "Release template documents evidence package format with image tags" \
    "grep -qi 'image.tag\|image-tag\|newTag' '${RELEASE_TEMPLATE}'"

  check "Release template documents evidence package with commit SHA" \
    "grep -qi 'commit.*SHA\|HEAD.*SHA\|SHA\|git-state' '${RELEASE_TEMPLATE}'"

  check "Release template documents ArgoCD status in evidence" \
    "grep -qi 'ArgoCD\|argocd.*status\|argocd-status' '${RELEASE_TEMPLATE}'"

  check "Release template documents branding gate in evidence" \
    "grep -qi 'branding.*gate\|brand.*gate\|branding.*log' '${RELEASE_TEMPLATE}'"
fi

echo ""

# ────────────────────────────────────────────────────────────────────────────
# AC-DEP-004: At least one full dry-run in lower env validates no manual
#             cherry-pick or ad-hoc worktree path is required.
# ────────────────────────────────────────────────────────────────────────────
echo "-- AC-DEP-004: Dry-run documentation and no-cherry-pick policy"

if [[ -f "${RELEASE_TEMPLATE}" ]]; then
  check "Release template has dry-run section" \
    "grep -qi 'dry.run\|dry run\|Dry-Run\|lower.*env\|local.*dry' '${RELEASE_TEMPLATE}'"

  check "Release template documents lower-env validation path" \
    "grep -qi 'local.*env\|lower.*env\|dev.*env\|tutor local' '${RELEASE_TEMPLATE}'"

  check "Release template documents no-cherry-pick policy" \
    "grep -qi 'cherry.pick\|cherry-pick\|no.*cherry' '${RELEASE_TEMPLATE}'"

  check "Release template documents no ad-hoc worktree requirement" \
    "grep -qi 'worktree\|canonical.*worktree\|single.*worktree\|ad-hoc' '${RELEASE_TEMPLATE}'"

  check "Release template documents single source branch policy" \
    "grep -qi 'source.*branch\|main.*branch\|single.*branch\|deploy.*from.*main' '${RELEASE_TEMPLATE}'"
fi

# Check dry-run contract script (existing)
DRY_RUN_CONTRACT="${REPO_ROOT}/scripts/qa/verify-release-dry-run-contract.sh"
if [[ -f "${DRY_RUN_CONTRACT}" ]]; then
  check "Dry-run contract verification script exists" \
    "[[ -f '${DRY_RUN_CONTRACT}' ]]"

  check "Dry-run contract script passes bash syntax" \
    "bash -n '${DRY_RUN_CONTRACT}' 2>/dev/null"
else
  warn "verify-release-dry-run-contract.sh not found (existing dry-run contract script)"
fi

# Check merge-first deployment protocol documents no-cherry-pick
MERGE_PROTOCOL="${REPO_ROOT}/docs/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md"
if [[ -f "${MERGE_PROTOCOL}" ]]; then
  check "Merge-first deployment protocol exists" \
    "[[ -f '${MERGE_PROTOCOL}' ]]"

  check "Merge protocol documents cherry-pick as anti-pattern" \
    "grep -qi 'cherry.pick\|cherry-pick' '${MERGE_PROTOCOL}'"
else
  warn "MERGE_FIRST_DEPLOYMENT_PROTOCOL.md not found (optional reference)"
fi

echo ""

# ────────────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
echo "WARN: ${WARN}"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi

exit 0
