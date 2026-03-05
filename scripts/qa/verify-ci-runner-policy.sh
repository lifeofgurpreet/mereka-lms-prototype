#!/usr/bin/env bash
# verify-ci-runner-policy.sh — enforce ARC-only CI runner policy
#
# Policy source: docs/operations/CI_RUNNER_POLICY.md
#
# Rules checked:
#   1. No 'ubuntu-latest' or 'ubuntu-24.04' except in permitted exceptions
#   2. No fallback expressions — all jobs must hard-code ARC runner labels
#   3. 'mereka-k8s-heavy-builders' only in allowed workflows
#   4. All other jobs must use 'mereka-k8s-runners'
#
# Exit codes:
#   0 — policy satisfied
#   1 — policy violation found

set -euo pipefail

WORKFLOWS_DIR=".github/workflows"
POLICY_DOC="docs/operations/CI_RUNNER_POLICY.md"

# Workflows permitted to use GitHub-hosted runners (Class C/D exceptions)
GITHUB_HOSTED_EXCEPTIONS=(
  "codeql.yml"
  "scorecard.yml"
  "dependency-review.yml"
  "build-ios-app.yml"
  "ios-testflight.yml"
)

# Workflows permitted to use mereka-k8s-heavy-builders (Class B)
HEAVY_BUILDER_ALLOWED=(
  "build-tutor-images.yml"
  "test-arc-runners.yml"
  "cross-browser-branding-smoke.yml"
  "frontend-branding-closure.yml"
  "mfe-live-dom-audit.yml"
  "npm-start-mfe-smoke.yml"
)

violations=0
warnings=0
checks=0

error() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

warn() {
  echo "  WARN: $*"
  warnings=$((warnings + 1))
}

pass() {
  checks=$((checks + 1))
}

is_in_list() {
  local needle="$1"; shift
  for item in "$@"; do
    [[ "$needle" == "$item" ]] && return 0
  done
  return 1
}

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "ERROR: workflows directory not found at $WORKFLOWS_DIR" >&2
  echo "Run this script from the repository root." >&2
  exit 1
fi

echo "=== CI Runner Policy Verification (ARC-only) ==="
echo "Policy: $POLICY_DOC"
echo ""

mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name "*.yml" | sort)

if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo "ERROR: no workflow files found in $WORKFLOWS_DIR" >&2
  exit 1
fi

echo "Scanning ${#workflow_files[@]} workflow files..."
echo ""

for wf_path in "${workflow_files[@]}"; do
  wf_name="$(basename "$wf_path")"

  while IFS=: read -r lineno line; do
    runs_on_value="${line#*runs-on:}"
    runs_on_value="${runs_on_value#"${runs_on_value%%[![:space:]]*}"}"
    runs_on_value="${runs_on_value%"${runs_on_value##*[![:space:]]}"}"

    [[ -z "$runs_on_value" ]] && continue

    # ── GitHub-hosted labels ──────────────────────────────────────────────
    if echo "$runs_on_value" | grep -qE 'ubuntu-|macos-'; then
      if is_in_list "$wf_name" "${GITHUB_HOSTED_EXCEPTIONS[@]}"; then
        pass
      else
        error "$wf_name:$lineno  uses GitHub-hosted runner '$runs_on_value' — must use ARC runner (mereka-k8s-runners or mereka-k8s-heavy-builders)"
      fi
      continue
    fi

    # ── Fallback expressions (DEPRECATED) ─────────────────────────────────
    if echo "$runs_on_value" | grep -qF "USE_SELF_HOSTED_RUNNERS"; then
      error "$wf_name:$lineno  uses deprecated fallback expression — replace with hard 'mereka-k8s-runners' label"
      continue
    fi

    # ── Heavy builders — only in allowed workflows ────────────────────────
    if echo "$runs_on_value" | grep -qF "mereka-k8s-heavy-builders"; then
      if is_in_list "$wf_name" "${HEAVY_BUILDER_ALLOWED[@]}"; then
        pass
      else
        error "$wf_name:$lineno  uses 'mereka-k8s-heavy-builders' — add to HEAVY_BUILDER_ALLOWED in this script if intentional"
      fi
      continue
    fi

    # ── ARC lightweight — correct ─────────────────────────────────────────
    if echo "$runs_on_value" | grep -qF "mereka-k8s-runners"; then
      pass
      continue
    fi

    # ── Expression patterns (matrix, needs, inputs) — skip ────────────────
    if echo "$runs_on_value" | grep -qE '^\$\{\{'; then
      if echo "$runs_on_value" | grep -qE "matrix\.|needs\.|github\.|inputs\."; then
        pass
        continue
      fi
      warn "$wf_name:$lineno  uses non-standard expression: $runs_on_value"
      continue
    fi

    # ── Unknown label ─────────────────────────────────────────────────────
    warn "$wf_name:$lineno  unrecognized runner label: $runs_on_value"

  done < <(grep -n "runs-on:" "$wf_path")
done

echo ""
echo "=== Summary ==="
echo "Checks     : $checks"
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
  echo "PASS — all runner labels conform to ARC-only policy."
fi
