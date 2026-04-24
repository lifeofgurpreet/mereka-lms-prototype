#!/usr/bin/env bash
# Verify release automation artefacts are present and well-formed.
#
# Checks:
#   1. docs/reference/operations/RELEASE_PROCESS.md exists
#   2. .github/workflows/release.yml exists and is triggered on tag push
#   3. scripts/infra/canonical-release.sh exists and is executable
#   4. scripts/infra/release-openedx-gitops.sh exists and is executable
#   5. scripts/infra/create-release.sh exists and is executable as the tag helper
#   4. Recent commits follow conventional commit format (informational)
#
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RELEASE_PROCESS_DOC="$REPO_ROOT/docs/reference/operations/RELEASE_PROCESS.md"
RELEASE_WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
CANONICAL_RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/canonical-release.sh"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"
CREATE_RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/create-release.sh"

RELEASE_INVOKE_CHECKER="$REPO_ROOT/scripts/qa/verify-release-workflow-invocation.sh"
RELEASE_DRY_RUN_CHECKER="$REPO_ROOT/scripts/qa/verify-release-dry-run-contract.sh"
RELEASE_PROMOTION_WIRING_CHECKER="$REPO_ROOT/scripts/qa/verify-release-promotion-wiring.sh"
PHASE2_SMOKE_EVIDENCE_CONTRACT_CHECKER="$REPO_ROOT/scripts/qa/verify-phase2-smoke-evidence-contract.sh"
BRANDING_EVIDENCE_A11Y_CONTRACT_CHECKER="$REPO_ROOT/scripts/qa/verify-branding-evidence-a11y-contract.sh"
BRANDING_EVIDENCE_SCREENSHOT_CONTRACT_CHECKER="$REPO_ROOT/scripts/qa/verify-branding-evidence-screenshot-contract.sh"
BUILD_WORKFLOW_CONTRACT="$REPO_ROOT/scripts/qa/verify-build-workflow-contract.sh"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"

violations=0

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; violations=1; }
warn() { echo "  WARN  $*"; }

echo "=== Release Automation Verification ==="
echo ""

# ---------------------------------------------------------------------------
# 1. RELEASE_PROCESS.md
# ---------------------------------------------------------------------------
echo "--- Release process document ---"

if [[ -f "${RELEASE_PROCESS_DOC}" ]]; then
  pass "docs/reference/operations/RELEASE_PROCESS.md exists"
else
  fail "docs/reference/operations/RELEASE_PROCESS.md is MISSING"
fi

# Spot-check key sections
for section in "Semantic Versioning" "Release Cadence" "Release Checklist" \
               "Rollback Procedure" "Hotfix Process" "Conventional Commit"; do
  if [[ -f "${RELEASE_PROCESS_DOC}" ]] && grep -qF "${section}" "${RELEASE_PROCESS_DOC}"; then
    pass "RELEASE_PROCESS.md contains '${section}'"
  else
    fail "RELEASE_PROCESS.md is missing section '${section}'"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# 2. release.yml workflow
# ---------------------------------------------------------------------------
echo "--- Release workflow ---"

if [[ -f "${RELEASE_WORKFLOW}" ]]; then
  pass ".github/workflows/release.yml exists"
else
  fail ".github/workflows/release.yml is MISSING"
fi

if [[ -f "${RELEASE_WORKFLOW}" ]]; then
  if grep -qE "tags:" "${RELEASE_WORKFLOW}"; then
    pass "release.yml triggers on tags"
  else
    fail "release.yml does not trigger on tag push"
  fi

  if grep -qE "'v\[0-9\]" "${RELEASE_WORKFLOW}" || grep -qE '"v\[0-9\]' "${RELEASE_WORKFLOW}"; then
    pass "release.yml tag pattern restricts to semver (v*)"
  else
    fail "release.yml missing semver tag filter pattern"
  fi

  if grep -q "gh release create" "${RELEASE_WORKFLOW}"; then
    pass "release.yml uses 'gh release create'"
  else
    fail "release.yml does not use 'gh release create'"
  fi

  if grep -q "contents: write" "${RELEASE_WORKFLOW}"; then
    pass "release.yml grants 'contents: write' permission"
  else
    fail "release.yml missing 'contents: write' permission for release creation"
  fi

  if grep -q "fetch-depth: 0" "${RELEASE_WORKFLOW}"; then
    pass "release.yml uses full git history (fetch-depth: 0)"
  else
    fail "release.yml missing fetch-depth: 0 (needed for git log changelog)"
  fi

  if grep -qE "promote-to-production|promote_to_production" "${RELEASE_WORKFLOW}"; then
    pass "release.yml has promote-to-production job"
  else
    fail "release.yml missing promote-to-production job (GitOps promotion not wired)"
  fi

  if grep -qE "environment:.*production" "${RELEASE_WORKFLOW}"; then
    pass "release.yml promotion job uses production environment (manual approval gate)"
  else
    fail "release.yml missing environment: production in promotion job"
  fi

  if grep -q "release-openedx-gitops.sh" "${RELEASE_WORKFLOW}"; then
    pass "release.yml calls release-openedx-gitops.sh for production promotion"
  else
    fail "release.yml does not call release-openedx-gitops.sh (promotion not wired)"
  fi

  if grep -q -- "--target-env" "${RELEASE_WORKFLOW}" && \
     grep -q "release-openedx-gitops.sh" "${RELEASE_WORKFLOW}"; then
    pass "release.yml passes --target-env to release orchestrator"
  else
    fail "release.yml missing --target-env in release orchestrator call"
  fi

  if grep -q -- "--require-digests" "${RELEASE_WORKFLOW}"; then
    pass "release.yml requires digest pinning for production promotion"
  else
    fail "release.yml missing --require-digests (production promotion must use immutable image pins)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 3. create-release.sh
# ---------------------------------------------------------------------------
echo "--- Canonical release scripts ---"

if [[ -f "${CANONICAL_RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/canonical-release.sh exists"
else
  fail "scripts/infra/canonical-release.sh is MISSING"
fi

if [[ -x "${CANONICAL_RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/canonical-release.sh is executable"
else
  fail "scripts/infra/canonical-release.sh is NOT executable"
fi

if [[ -f "${RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/release-openedx-gitops.sh exists"
else
  fail "scripts/infra/release-openedx-gitops.sh is MISSING"
fi

if [[ -x "${RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/release-openedx-gitops.sh is executable"
else
  fail "scripts/infra/release-openedx-gitops.sh is NOT executable"
fi

echo ""

echo "--- Tag helper script ---"

if [[ -f "${CREATE_RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/create-release.sh exists"
else
  fail "scripts/infra/create-release.sh is MISSING"
fi

if [[ -x "${CREATE_RELEASE_SCRIPT}" ]]; then
  pass "scripts/infra/create-release.sh is executable"
else
  fail "scripts/infra/create-release.sh is NOT executable (run: chmod +x ${CREATE_RELEASE_SCRIPT})"
fi

if [[ -f "${CREATE_RELEASE_SCRIPT}" ]]; then
  if grep -q "set -euo pipefail" "${CREATE_RELEASE_SCRIPT}"; then
    pass "create-release.sh has set -euo pipefail"
  else
    fail "create-release.sh missing 'set -euo pipefail'"
  fi

  if grep -qE '\^v\[0-9\]' "${CREATE_RELEASE_SCRIPT}"; then
    pass "create-release.sh validates semver format"
  else
    fail "create-release.sh missing semver validation"
  fi

  if grep -q "git tag -a" "${CREATE_RELEASE_SCRIPT}"; then
    pass "create-release.sh creates annotated tags"
  else
    fail "create-release.sh does not create annotated tags"
  fi

  if grep -q "git push origin" "${CREATE_RELEASE_SCRIPT}"; then
    pass "create-release.sh pushes tag to origin"
  else
    fail "create-release.sh does not push tag to origin"
  fi

  if grep -q "Rollback" "${CREATE_RELEASE_SCRIPT}"; then
    pass "create-release.sh prints rollback command"
  else
    fail "create-release.sh does not print rollback command"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Conventional commit check (informational, non-blocking)
# ---------------------------------------------------------------------------
echo "--- Conventional commit format (recent commits, informational) ---"

CONV_PATTERN='^(feat|fix|docs|refactor|chore|test|perf|ci)(\(.+\))?!?:'
RECENT_TOTAL=20
RECENT_COMMITS="$(git -C "${REPO_ROOT}" log --oneline -"${RECENT_TOTAL}" --pretty=format:'%s' 2>/dev/null || true)"
CONV_COUNT=0
NON_CONV_COUNT=0

while IFS= read -r subject; do
  [[ -z "${subject}" ]] && continue
  if grep -qE "${CONV_PATTERN}" <<<"${subject}"; then
    CONV_COUNT=$((CONV_COUNT + 1))
  else
    NON_CONV_COUNT=$((NON_CONV_COUNT + 1))
  fi
done <<< "${RECENT_COMMITS}"

if [[ $((CONV_COUNT + NON_CONV_COUNT)) -eq 0 ]]; then
  warn "Could not read recent commits (empty repo?)"
elif [[ "${NON_CONV_COUNT}" -eq 0 ]]; then
  pass "All ${CONV_COUNT} recent commits follow conventional commit format"
elif [[ "${CONV_COUNT}" -ge $((RECENT_TOTAL / 2)) ]]; then
  warn "${NON_CONV_COUNT}/${RECENT_TOTAL} recent commits do not follow conventional commits (informational)"
else
  warn "Fewer than half of recent ${RECENT_TOTAL} commits follow conventional commits (changelog quality may be low)"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. Existing release automation contract (from original verify-release-automation.sh)
# ---------------------------------------------------------------------------
echo "--- Release orchestrator contract ---"

if [[ -f "${RELEASE_SCRIPT}" ]]; then
  # Any workflow invoking release-openedx-gitops.sh must pass --target-env
  WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"
  while IFS= read -r workflow_file; do
    if grep -q '\./scripts/infra/release-openedx-gitops\.sh' "${workflow_file}" 2>/dev/null; then
      if ! grep -q -- '--target-env' "${workflow_file}" 2>/dev/null; then
        fail "Missing --target-env in workflow ${workflow_file#"$REPO_ROOT"/}"
      fi
    fi
  done < <(find "${WORKFLOWS_DIR}" -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

  if grep -q 'TARGET_ENV_SET' "${RELEASE_SCRIPT}" 2>/dev/null; then
    pass "release-openedx-gitops.sh has TARGET_ENV_SET guard"
  else
    fail "release-openedx-gitops.sh missing TARGET_ENV_SET guard"
  fi

  if grep -q 'CI mode requires explicit --target-env' "${RELEASE_SCRIPT}" 2>/dev/null; then
    pass "release-openedx-gitops.sh guards CI --target-env"
  else
    fail "release-openedx-gitops.sh missing CI explicit --target-env guard"
  fi

  if grep -q -- '--require-digests requires digests for every targeted image\.' "${RELEASE_SCRIPT}" 2>/dev/null \
    || grep -q 'CI production apply requires both --openedx-digest and --mfe-digest' "${RELEASE_SCRIPT}" 2>/dev/null \
    || grep -q 'CI production apply requires digests for every targeted image\.' "${RELEASE_SCRIPT}" 2>/dev/null; then
    pass "release-openedx-gitops.sh guards CI production digest"
  else
    fail "release-openedx-gitops.sh missing CI production digest safety gate"
  fi

  if grep -q "production apply forbids mutable tag" "${RELEASE_SCRIPT}" 2>/dev/null; then
    pass "release-openedx-gitops.sh forbids mutable tags for production apply"
  else
    fail "release-openedx-gitops.sh missing production mutable-tag guard"
  fi

  for flag in \
    '--openedx-digest' \
    '--mfe-digest' \
    '--require-digests' \
    '--purge-frontend-cache' \
    '--frontend-cache-env' \
    '--purge-frontend-cache-everything'; do
    if grep -q -- "${flag}" "${RELEASE_SCRIPT}" 2>/dev/null; then
      pass "release-openedx-gitops.sh supports ${flag}"
    else
      fail "release-openedx-gitops.sh missing ${flag} support"
    fi
  done
else
  warn "release-openedx-gitops.sh not found — skipping orchestrator checks"
fi

if [[ -f "${BUILD_WORKFLOW}" ]]; then
  RELEASE_BUNDLE_BLOCK="$(sed -n '/^  release-bundle:/,/^  update-gitops:/p' "${BUILD_WORKFLOW}")"

  if grep -q "target_environment:" "${BUILD_WORKFLOW}"; then
    pass "build-tutor-images.yml has target_environment input"
  else
    fail "build-tutor-images.yml missing target_environment input"
  fi

  if grep -q "target_environment must be explicitly selected before generating a release bundle" "${BUILD_WORKFLOW}" \
    || grep -q "inputs.target_environment != 'select-environment'" <<< "${RELEASE_BUNDLE_BLOCK}"; then
    pass "build-tutor-images.yml guards placeholder target_environment before release bundle generation"
  else
    fail "build-tutor-images.yml missing explicit target_environment guard before release bundle generation"
  fi
fi

for checker_file in "${BUILD_WORKFLOW_CONTRACT}" "${RELEASE_INVOKE_CHECKER}" \
                    "${RELEASE_DRY_RUN_CHECKER}" "${RELEASE_PROMOTION_WIRING_CHECKER}" \
                    "${PHASE2_SMOKE_EVIDENCE_CONTRACT_CHECKER}" \
                    "${BRANDING_EVIDENCE_A11Y_CONTRACT_CHECKER}" \
                    "${BRANDING_EVIDENCE_SCREENSHOT_CONTRACT_CHECKER}"; do
  checker_name="${checker_file#"$REPO_ROOT"/}"
  if [[ "$checker_name" == "scripts/qa/verify-release-dry-run-contract.sh" ]] \
    && [[ -f "$REPO_ROOT/.git" && ! -d "$REPO_ROOT/.git" ]]; then
    warn "${checker_name} skipped in git worktree mode (.git is a file)"
    continue
  fi
  if [[ -f "${checker_file}" ]]; then
    pass "${checker_name} exists"
    if bash "${checker_file}" >/tmp/mereka-release-checker.log 2>&1; then
      pass "${checker_name} contract passes"
    else
      fail "${checker_name} contract failed"
      sed 's/^/    /' /tmp/mereka-release-checker.log
    fi
  else
    fail "${checker_name} is MISSING"
  fi
done

rm -f /tmp/mereka-release-checker.log

echo ""

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
if [[ "${violations}" -ne 0 ]]; then
  echo "Release automation verification FAILED."
  exit 1
fi

echo "Release automation verification PASSED."
