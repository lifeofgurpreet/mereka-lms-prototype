#!/usr/bin/env bash
# Seeded-defect self-test for verify-canonical-entrypoints.sh.
#
# Creates synthetic fixture directories with:
#   - A valid canonical-entrypoints.yaml  → expects PASS
#   - A map with a missing workflow_id     → expects FAIL
#   - A map with a missing canonical path  → expects FAIL
#   - A map with an invalid status value   → expects FAIL
#   - A map where an alternative == canonical → expects FAIL
#
# Each defect scenario must exit non-zero from the verify script.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="${REPO_ROOT}/scripts/qa/verify-canonical-entrypoints.sh"

if [[ ! -x "$VERIFY" ]]; then
  echo "FATAL: verify script not found or not executable: $VERIFY" >&2
  exit 1
fi

tmpdir="$(mktemp -d -t verify-canonical-entrypoints.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

PASS=0
FAIL=0

run_expect_pass() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/tce.out 2>&1
  local rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "PASS ${label}"
    PASS=$((PASS + 1))
  else
    echo "FAIL ${label} (expected PASS, got exit ${rc})"
    cat /tmp/tce.out
    FAIL=$((FAIL + 1))
  fi
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/tce.out 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "PASS ${label}"
    PASS=$((PASS + 1))
  else
    echo "FAIL ${label} (expected FAIL, got PASS)"
    cat /tmp/tce.out
    FAIL=$((FAIL + 1))
  fi
}

write_canonical_file() {
  local content="$1"
  mkdir -p "${tmpdir}/scripts/governance"
  printf '%s\n' "$content" > "${tmpdir}/scripts/governance/canonical-entrypoints.yaml"
}

# Create stub canonical script targets used by the valid fixture
mkdir -p \
  "${tmpdir}/scripts/infra" \
  "${tmpdir}/scripts/release" \
  "${tmpdir}/scripts/qa" \
  "${tmpdir}/.github/workflows"

for stub in \
  scripts/infra/canonical-release.sh \
  scripts/infra/release-openedx-gitops.sh \
  scripts/infra/apply-kind-overlay.sh \
  scripts/release/migration-preflight.sh \
  scripts/qa/run-release-verification-gates.sh; do
  touch "${tmpdir}/${stub}"
done
touch "${tmpdir}/.github/workflows/build-tutor-images.yml"

# ── Scenario 1: Valid map — all 6 required workflow IDs, paths exist ─────────
write_canonical_file 'version: "1.0.0"
entrypoints:
  - workflow_id: release
    label: "Release"
    canonical_script: scripts/infra/canonical-release.sh
    owner: platform-team
    invocation: "bash scripts/infra/canonical-release.sh"
    proof_output: "stdout release summary"
    status: canonical

  - workflow_id: migrate
    label: "Migrate preflight"
    canonical_script: scripts/release/migration-preflight.sh
    owner: platform-team
    invocation: "bash scripts/release/migration-preflight.sh"
    proof_output: "stdout PASS/FAIL"
    status: canonical

  - workflow_id: promote
    label: "Promote"
    canonical_script: scripts/infra/release-openedx-gitops.sh
    owner: platform-team
    invocation: "bash scripts/infra/release-openedx-gitops.sh"
    proof_output: "stdout ArgoCD sync status"
    status: canonical

  - workflow_id: publish-image
    label: "Publish image"
    canonical_script: .github/workflows/build-tutor-images.yml
    owner: platform-team
    invocation: "gh workflow run build-tutor-images.yml"
    proof_output: "ghcr.io image published"
    status: canonical

  - workflow_id: deploy
    label: "Deploy"
    canonical_script: scripts/infra/apply-kind-overlay.sh
    owner: platform-team
    invocation: "bash scripts/infra/apply-kind-overlay.sh"
    proof_output: "kubectl apply output"
    status: canonical

  - workflow_id: runtime-validation
    label: "Runtime validation"
    canonical_script: scripts/qa/run-release-verification-gates.sh
    owner: platform-team
    invocation: "bash scripts/qa/run-release-verification-gates.sh"
    proof_output: "stdout PASS/FAIL gate summary"
    status: canonical
'
run_expect_pass "Scenario 1: valid map with all 6 workflow IDs"

# ── Scenario 2: Missing a required workflow_id (deploy omitted) ───────────────
write_canonical_file 'version: "1.0.0"
entrypoints:
  - workflow_id: release
    label: "Release"
    canonical_script: scripts/infra/canonical-release.sh
    owner: platform-team
    invocation: "bash scripts/infra/canonical-release.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: migrate
    label: "Migrate"
    canonical_script: scripts/release/migration-preflight.sh
    owner: platform-team
    invocation: "bash scripts/release/migration-preflight.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: promote
    label: "Promote"
    canonical_script: scripts/infra/release-openedx-gitops.sh
    owner: platform-team
    invocation: "bash"
    proof_output: "stdout"
    status: canonical

  - workflow_id: publish-image
    label: "Publish"
    canonical_script: .github/workflows/build-tutor-images.yml
    owner: platform-team
    invocation: "gh workflow run"
    proof_output: "image"
    status: canonical

  - workflow_id: runtime-validation
    label: "Runtime"
    canonical_script: scripts/qa/run-release-verification-gates.sh
    owner: platform-team
    invocation: "bash scripts/qa/run-release-verification-gates.sh"
    proof_output: "stdout"
    status: canonical
'
run_expect_fail "Scenario 2: missing workflow_id 'deploy'"

# ── Scenario 3: canonical_script path does not exist ─────────────────────────
write_canonical_file 'version: "1.0.0"
entrypoints:
  - workflow_id: release
    label: "Release"
    canonical_script: scripts/infra/NONEXISTENT-script.sh
    owner: platform-team
    invocation: "bash scripts/infra/NONEXISTENT-script.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: migrate
    label: "Migrate"
    canonical_script: scripts/release/migration-preflight.sh
    owner: platform-team
    invocation: "bash scripts/release/migration-preflight.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: promote
    label: "Promote"
    canonical_script: scripts/infra/release-openedx-gitops.sh
    owner: platform-team
    invocation: "bash"
    proof_output: "stdout"
    status: canonical

  - workflow_id: publish-image
    label: "Publish"
    canonical_script: .github/workflows/build-tutor-images.yml
    owner: platform-team
    invocation: "gh workflow run"
    proof_output: "image"
    status: canonical

  - workflow_id: deploy
    label: "Deploy"
    canonical_script: scripts/infra/apply-kind-overlay.sh
    owner: platform-team
    invocation: "bash scripts/infra/apply-kind-overlay.sh"
    proof_output: "kubectl apply"
    status: canonical

  - workflow_id: runtime-validation
    label: "Runtime"
    canonical_script: scripts/qa/run-release-verification-gates.sh
    owner: platform-team
    invocation: "bash scripts/qa/run-release-verification-gates.sh"
    proof_output: "stdout"
    status: canonical
'
run_expect_fail "Scenario 3: canonical_script path does not exist"

# ── Scenario 4: Invalid status value ─────────────────────────────────────────
write_canonical_file 'version: "1.0.0"
entrypoints:
  - workflow_id: release
    label: "Release"
    canonical_script: scripts/infra/canonical-release.sh
    owner: platform-team
    invocation: "bash scripts/infra/canonical-release.sh"
    proof_output: "stdout"
    status: INVALID_STATUS

  - workflow_id: migrate
    label: "Migrate"
    canonical_script: scripts/release/migration-preflight.sh
    owner: platform-team
    invocation: "bash scripts/release/migration-preflight.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: promote
    label: "Promote"
    canonical_script: scripts/infra/release-openedx-gitops.sh
    owner: platform-team
    invocation: "bash"
    proof_output: "stdout"
    status: canonical

  - workflow_id: publish-image
    label: "Publish"
    canonical_script: .github/workflows/build-tutor-images.yml
    owner: platform-team
    invocation: "gh workflow run"
    proof_output: "image"
    status: canonical

  - workflow_id: deploy
    label: "Deploy"
    canonical_script: scripts/infra/apply-kind-overlay.sh
    owner: platform-team
    invocation: "bash scripts/infra/apply-kind-overlay.sh"
    proof_output: "kubectl apply"
    status: canonical

  - workflow_id: runtime-validation
    label: "Runtime"
    canonical_script: scripts/qa/run-release-verification-gates.sh
    owner: platform-team
    invocation: "bash scripts/qa/run-release-verification-gates.sh"
    proof_output: "stdout"
    status: canonical
'
run_expect_fail "Scenario 4: invalid status value"

# ── Scenario 5: Alternative path == canonical_script ─────────────────────────
write_canonical_file 'version: "1.0.0"
entrypoints:
  - workflow_id: release
    label: "Release"
    canonical_script: scripts/infra/canonical-release.sh
    owner: platform-team
    invocation: "bash scripts/infra/canonical-release.sh"
    proof_output: "stdout"
    alternatives:
      - path: scripts/infra/canonical-release.sh
        reason: "Same as canonical — this is the defect we are detecting."
    status: canonical

  - workflow_id: migrate
    label: "Migrate"
    canonical_script: scripts/release/migration-preflight.sh
    owner: platform-team
    invocation: "bash scripts/release/migration-preflight.sh"
    proof_output: "stdout"
    status: canonical

  - workflow_id: promote
    label: "Promote"
    canonical_script: scripts/infra/release-openedx-gitops.sh
    owner: platform-team
    invocation: "bash"
    proof_output: "stdout"
    status: canonical

  - workflow_id: publish-image
    label: "Publish"
    canonical_script: .github/workflows/build-tutor-images.yml
    owner: platform-team
    invocation: "gh workflow run"
    proof_output: "image"
    status: canonical

  - workflow_id: deploy
    label: "Deploy"
    canonical_script: scripts/infra/apply-kind-overlay.sh
    owner: platform-team
    invocation: "bash scripts/infra/apply-kind-overlay.sh"
    proof_output: "kubectl apply"
    status: canonical

  - workflow_id: runtime-validation
    label: "Runtime"
    canonical_script: scripts/qa/run-release-verification-gates.sh
    owner: platform-team
    invocation: "bash scripts/qa/run-release-verification-gates.sh"
    proof_output: "stdout"
    status: canonical
'
run_expect_fail "Scenario 5: alternative path duplicates canonical_script"

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━ Seeded Test Results ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASS  ${PASS}"
echo "  FAIL  ${FAIL}"
echo ""
if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL — ${FAIL} scenario(s) did not behave as expected."
  exit 1
else
  echo "RESULT: PASS — all seeded defect scenarios behaved correctly."
  exit 0
fi
