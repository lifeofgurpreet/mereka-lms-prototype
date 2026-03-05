#!/usr/bin/env bash
# verify-ci-runner-policy.sh — enforce CI runner label policy
#
# Policy source: docs/operations/CI_RUNNER_POLICY.md
#
# Rules checked:
#   1. No job may use 'ubuntu-latest' (use 'ubuntu-24.04' or 'macos-14' for pinned versions)
#   2. 'mereka-k8s-heavy-builders' is reserved for Docker image builds and Playwright E2E
#   3. 'mereka-k8s-runners' (without fallback) is only used in test-arc-runners.yml
#   4. The fallback expression pattern is the approved form for ARC lightweight jobs
#
# Exit codes:
#   0 — policy satisfied (or only warnings)
#   1 — policy violation found

set -euo pipefail

WORKFLOWS_DIR=".github/workflows"
POLICY_DOC="docs/operations/CI_RUNNER_POLICY.md"

# Approved runner labels and patterns
APPROVED_PINNED_LABELS=(
  "ubuntu-24.04"
  "macos-14"
  "mereka-k8s-runners"
  "mereka-k8s-heavy-builders"
)

# The approved fallback expression for ARC lightweight jobs
APPROVED_FALLBACK_PATTERN="vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04'"

# Workflows allowed to use a hard 'mereka-k8s-runners' label without fallback expression
ARC_TEST_WORKFLOWS=(
  "test-arc-runners.yml"
)

# Workflows that use 'mereka-k8s-heavy-builders' (Docker builds, Playwright E2E)
HEAVY_BUILDER_ALLOWED_WORKFLOWS=(
  "build-tutor-images.yml"
  "test-arc-runners.yml"
)

violations=0
warnings=0

error() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

warn() {
  echo "  WARN: $*"
  warnings=$((warnings + 1))
}

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "ERROR: workflows directory not found at $WORKFLOWS_DIR" >&2
  echo "Run this script from the repository root." >&2
  exit 1
fi

echo "=== CI Runner Policy Verification ==="
echo "Policy: $POLICY_DOC"
echo "Workflows: $WORKFLOWS_DIR"
echo ""

# Collect all workflow files
mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name "*.yml" | sort)

if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo "ERROR: no workflow files found in $WORKFLOWS_DIR" >&2
  exit 1
fi

echo "Scanning ${#workflow_files[@]} workflow files..."
echo ""

for wf_path in "${workflow_files[@]}"; do
  wf_name="$(basename "$wf_path")"

  # Read runs-on lines with line numbers
  while IFS=: read -r lineno line; do
    # Strip leading/trailing whitespace from the value
    runs_on_value="${line#*runs-on:}"
    runs_on_value="${runs_on_value#"${runs_on_value%%[![:space:]]*}"}"  # ltrim
    runs_on_value="${runs_on_value%"${runs_on_value##*[![:space:]]}"}"  # rtrim

    # Skip empty
    [[ -z "$runs_on_value" ]] && continue

    # ── Rule 1: No ubuntu-latest ────────────────────────────────────────────
    # Reported as a warning (not a hard failure) because these are pre-existing.
    # Migration tracked in CI_RUNNER_POLICY.md under "LEGACY" status.
    if echo "$runs_on_value" | grep -qF "ubuntu-latest"; then
      warn "$wf_name:$lineno  uses 'ubuntu-latest' — pin to 'ubuntu-24.04' instead (tracked in CI_RUNNER_POLICY.md)"
      continue
    fi

    # ── Rule 2: macos-latest not allowed (use macos-14) ─────────────────────
    if echo "$runs_on_value" | grep -qF "macos-latest"; then
      warn "$wf_name:$lineno  uses 'macos-latest' — prefer pinned 'macos-14'"
      continue
    fi

    # ── Rule 3: mereka-k8s-heavy-builders only in allowed workflows ──────────
    if echo "$runs_on_value" | grep -qF "mereka-k8s-heavy-builders"; then
      allowed=0
      for allowed_wf in "${HEAVY_BUILDER_ALLOWED_WORKFLOWS[@]}"; do
        if [[ "$wf_name" == "$allowed_wf" ]]; then
          allowed=1
          break
        fi
      done
      if [[ "$allowed" -eq 0 ]]; then
        error "$wf_name:$lineno  uses 'mereka-k8s-heavy-builders' — this label is reserved for Docker image builds and Playwright E2E. Add workflow to HEAVY_BUILDER_ALLOWED_WORKFLOWS in this script if intentional."
      fi
      continue
    fi

    # ── Rule 4: Hard mereka-k8s-runners only in test workflow ────────────────
    # (other workflows must use the approved fallback expression)
    if echo "$runs_on_value" | grep -qF "mereka-k8s-runners"; then
      # If it contains the fallback expression, that's fine
      if echo "$runs_on_value" | grep -qF "$APPROVED_FALLBACK_PATTERN"; then
        continue
      fi
      # Otherwise only test-arc-runners.yml is exempt
      in_test_wf=0
      for test_wf in "${ARC_TEST_WORKFLOWS[@]}"; do
        if [[ "$wf_name" == "$test_wf" ]]; then
          in_test_wf=1
          break
        fi
      done
      if [[ "$in_test_wf" -eq 0 ]]; then
        error "$wf_name:$lineno  uses hard 'mereka-k8s-runners' label without the approved fallback expression. Use: runs-on: \${{ vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04' }}"
      fi
      continue
    fi

    # ── Rule 5: Expression patterns must use approved form ───────────────────
    if echo "$runs_on_value" | grep -q '^\${{'; then
      if ! echo "$runs_on_value" | grep -qF "$APPROVED_FALLBACK_PATTERN"; then
        # Allow reusable workflow expressions or matrix strategies (skip those)
        if echo "$runs_on_value" | grep -qE "matrix\.|needs\.|github\.|inputs\."; then
          continue
        fi
        warn "$wf_name:$lineno  uses a non-standard expression: $runs_on_value"
      fi
      continue
    fi

  done < <(grep -n "runs-on:" "$wf_path")

done

echo ""
echo "=== Summary ==="
echo "Violations : $violations"
echo "Warnings   : $warnings"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — $violations policy violation(s) found."
  echo "See $POLICY_DOC for the full runner policy."
  exit 1
fi

if [[ "$warnings" -gt 0 ]]; then
  echo "PASS — no violations. $warnings warning(s) noted (non-blocking)."
else
  echo "PASS — all runner labels conform to policy."
fi
