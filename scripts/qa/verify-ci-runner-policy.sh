#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# verify-ci-runner-policy.sh — enforce ARC-first CI runner policy with explicit exceptions
set -euo pipefail

WORKFLOWS_DIR=".github/workflows"
POLICY_DOC="docs/policies/operations/CI_RUNNER_POLICY.md"
VERIFY_CI_RUNNER_POLICY_SCOPE="${VERIFY_CI_RUNNER_POLICY_SCOPE:-all}"
VERIFY_CI_RUNNER_POLICY_CHANGED_FILES="${VERIFY_CI_RUNNER_POLICY_CHANGED_FILES:-}"

# Workflows permitted to use GitHub-hosted macOS runners (Class D exceptions)
MACOS_HOSTED_EXCEPTIONS=(
  "build-ios-app.yml"
  "ios-testflight.yml"
)

# Workflows permitted to use GitHub-hosted Linux runners (temporary Class C exceptions)
LINUX_HOSTED_EXCEPTIONS=()

# Heavy build jobs — the actual image compile/scan work. These MUST run on
# ARC (mereka-k8s-heavy-builders) or route through the fastlane selector that
# falls back to heavy-builders. Any other job is allowed to use hosted runners
# since fastlane (PR #1518, #1524) intentionally moves lightweight orchestration
# onto ubuntu-latest to save ARC capacity.
HEAVY_BUILD_JOBS=(
  "build-openedx"
  "build-mfe"
  "scan-openedx-image"
  "scan-mfe-image"
)

# Expression-based `runs-on` values that route through a trusted fastlane
# selector output are allowed. We match against the raw label string.
# Selectors come from Biji-Biji-Initiative/bbi-infrastructure and fall back to
# ARC runners when fastlane is disabled, so the ARC-first guarantee holds.
FASTLANE_RUNNER_EXPRESSIONS=(
  'needs.select-build-lane.outputs.runner_label'
  'needs.select-ci-lane.outputs.runner_label'
  'needs.select-bootstrap-lane.outputs.runner_label'
  'needs.select-runner.outputs.runner_label'
  # Direct repo-variable routing for dedicated LMS fastlane lanes on
  # vmi3220759 (mereka-lms-vps-fastlane-{build,ci}). The expression
  # falls back to mereka-k8s-{heavy-builders,runners} when the var is
  # unset, so the ARC-first guarantee still holds.
  "vars.CI_FASTLANE_BUILD_LABEL || 'mereka-k8s-heavy-builders'"
  "vars.CI_FASTLANE_CI_LABEL || 'mereka-k8s-runners'"
)

# Workflows permitted to use mereka-k8s-heavy-builders (Class B)
HEAVY_BUILDER_ALLOWED=(
  "build-tutor-images.yml"
  "codeql.yml"
  "test-arc-runners.yml"
  "cross-browser-branding-smoke.yml"
  "frontend-branding-closure.yml"
  "mfe-live-dom-audit.yml"
  "npm-start-mfe-smoke.yml"
)

violations=0
checks=0

error() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

is_in_list() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$needle" == "$item" ]] && return 0
  done
  return 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

if [[ "$VERIFY_CI_RUNNER_POLICY_SCOPE" == "changed" ]]; then
  SHOULD_RUN=0
  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/*|\
      docs/policies/operations/CI_RUNNER_POLICY.md|\
      scripts/qa/verify-ci-runner-policy.sh)
        SHOULD_RUN=1
        break
        ;;
    esac
  done <<< "$VERIFY_CI_RUNNER_POLICY_CHANGED_FILES"

  if [[ "$SHOULD_RUN" -eq 0 ]]; then
    echo "Skipping CI runner policy verification; no workflow or runner-policy changes in PR diff."
    exit 0
  fi
fi

validate_runner_label() {
  local wf_name="$1"
  local job_name="$2"
  local raw_label="$3"
  local label
  label="$(trim "${raw_label//$'\r'/}")"

  # Strip the "[N]" label-index suffix to get the bare job name for allowlist
  # matching. The caller passes "job_name[1]" when a job has multiple labels.
  local bare_job_name="${job_name%\[*}"

  if [[ -z "$label" || "$label" == "null" ]]; then
    error "$wf_name:$job_name has empty runs-on label"
    return
  fi

  if [[ "$label" == *"USE_SELF_HOSTED_RUNNERS"* ]]; then
    error "$wf_name:$job_name uses deprecated fallback expression '$label'"
    return
  fi

  local is_heavy_build_job=false
  if is_in_list "$bare_job_name" "${HEAVY_BUILD_JOBS[@]}"; then
    is_heavy_build_job=true
  fi

  if [[ "$label" == *'${{'* ]]; then
    # Allow expression-based runs-on when it routes through a trusted fastlane
    # selector output (e.g., select-build-lane.outputs.runner_label). The
    # fastlane selector falls back to mereka-k8s-heavy-builders when disabled,
    # so the ARC-first guarantee is preserved for heavy build jobs.
    local expr
    for expr in "${FASTLANE_RUNNER_EXPRESSIONS[@]}"; do
      if [[ "$label" == *"$expr"* ]]; then
        pass
        return
      fi
    done
    error "$wf_name:$job_name uses expression-based runs-on '$label' (not a recognized fastlane selector)"
    return
  fi

  if [[ "$label" == *"ubuntu-"* ]]; then
    # Heavy build jobs may NOT run on github-hosted — they need 12GB+ RAM.
    if [[ "$is_heavy_build_job" == "true" ]]; then
      error "$wf_name:$job_name is a heavy build job and must not use GitHub-hosted runner '$label' (use mereka-k8s-heavy-builders or fastlane selector)"
      return
    fi
    # Fastlane (PR #1518, #1524) intentionally runs all other orchestration,
    # lint, prep, and selector jobs on ubuntu-latest to save ARC capacity.
    pass
    return
  fi

  if [[ "$label" == *"macos-"* ]]; then
    if is_in_list "$wf_name" "${MACOS_HOSTED_EXCEPTIONS[@]}"; then
      pass
    else
      error "$wf_name:$job_name uses GitHub-hosted macOS runner '$label' outside allowlist"
    fi
    return
  fi

  if [[ "$label" == "mereka-k8s-heavy-builders" ]]; then
    if is_in_list "$wf_name" "${HEAVY_BUILDER_ALLOWED[@]}"; then
      pass
    else
      error "$wf_name:$job_name uses 'mereka-k8s-heavy-builders' outside allowlist"
    fi
    return
  fi

  if [[ "$label" == "mereka-k8s-runners" ]]; then
    pass
    return
  fi

  error "$wf_name:$job_name uses unapproved runner label '$label'"
}

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required for workflow parsing." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for workflow parsing." >&2
  exit 1
fi

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "ERROR: workflows directory not found at $WORKFLOWS_DIR" >&2
  echo "Run this script from the repository root." >&2
  exit 1
fi

echo "=== CI Runner Policy Verification (ARC-first, allowlisted exceptions only) ==="
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
  jobs_json=""
  if ! jobs_json="$(yq -o=json '.jobs // {}' "$wf_path" 2>&1)"; then
    parse_error="$(head -n1 <<<"$jobs_json")"
    error "$wf_name could not be parsed by yq: ${parse_error}"
    continue
  fi

  job_rows=""
  if ! job_rows="$(jq -c 'to_entries[] | {job: .key, uses: (.value.uses // ""), runs_on: (.value["runs-on"] // null)}' <<<"$jobs_json" 2>&1)"; then
    parse_error="$(head -n1 <<<"$job_rows")"
    error "$wf_name has invalid jobs structure: ${parse_error}"
    continue
  fi

  while IFS= read -r job_row; do
    [[ -z "$job_row" ]] && continue

    job_name="$(jq -r '.job' <<<"$job_row")"
    uses_value="$(jq -r '.uses // ""' <<<"$job_row")"
    runs_on_type="$(jq -r '.runs_on | type' <<<"$job_row")"

    [[ -z "$job_name" ]] && continue

    if [[ "$runs_on_type" == "null" ]]; then
      if [[ -n "$uses_value" ]]; then
        # Reusable-workflow proxy job (runs-on belongs to called workflow).
        pass
      else
        error "$wf_name:$job_name missing runs-on"
      fi
      continue
    fi

    mapfile -t labels < <(jq -r 'if .runs_on | type == "array" then .runs_on[] else .runs_on end' <<<"$job_row")
    if [[ "${#labels[@]}" -eq 0 ]]; then
      error "$wf_name:$job_name has empty runs-on declaration"
      continue
    fi

    label_index=0
    for label in "${labels[@]}"; do
      label_index=$((label_index + 1))
      validate_runner_label "$wf_name" "${job_name}[${label_index}]" "$label"
    done
  done <<<"$job_rows"
done

echo ""
echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — $violations policy violation(s) found."
  echo "See $POLICY_DOC for the full runner policy."
  exit 1
fi

echo "PASS — all workflow jobs conform to ARC-first runner policy."
