#!/usr/bin/env bash
# verify-authority-routing.sh — Verify authority cutover
#
# Ensures that:
# 1. bin/lms-ops exists and is executable
# 2. All front_door concerns are wired in bin/lms-ops
# 3. bin/lms-ops delegates to the correct underlying scripts
# 4. No direct invocation of underlying scripts in CI workflows
#    for concerns that should go through lms-ops
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

collect_workflow_invocations() {
  local script_path="$1"
  (
    rg -n -g '*.yml' -g '*.yaml' -F "./${script_path}" "$WORKFLOWS_DIR" 2>/dev/null || true
    rg -n -g '*.yml' -g '*.yaml' -F "bash ${script_path}" "$WORKFLOWS_DIR" 2>/dev/null || true
  ) | sort -u
}

in_allowlist() {
  local value="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

normalize_repo_relative_path() {
  local path="$1"
  if [[ "$path" == "$REPO_ROOT/"* ]]; then
    echo "${path#"$REPO_ROOT"/}"
  else
    echo "$path"
  fi
}

echo "Authority Routing Verification"
echo "=============================="

# 1. bin/lms-ops exists and is executable
LMS_OPS="$REPO_ROOT/bin/lms-ops"
if [[ -x "$LMS_OPS" ]]; then
  pass "bin/lms-ops exists and is executable"
else
  fail "bin/lms-ops missing or not executable"
  echo ""
  echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
  exit 1
fi

# 2. All concerns wired in the dispatch
EXPECTED_CONCERNS="migrate proof release-gate smoke preflight topology"
for concern in $EXPECTED_CONCERNS; do
  if grep -q "^  ${concern})" "$LMS_OPS" 2>/dev/null; then
    pass "concern '$concern' wired in bin/lms-ops dispatch"
  else
    fail "concern '$concern' NOT found in bin/lms-ops dispatch"
  fi
done

# 3. bin/lms-ops delegates to underlying scripts (not reimplementing)
declare -A DELEGATIONS=(
  ["release-gate"]="release-gate.sh"
  ["smoke"]="smoke-after-migrate.sh"
  ["preflight"]="migration-preflight.sh"
  ["proof"]="emit-proof-envelope.sh"
)
for concern in "${!DELEGATIONS[@]}"; do
  expected_script="${DELEGATIONS[$concern]}"
  if grep -q "$expected_script" "$LMS_OPS" 2>/dev/null; then
    pass "bin/lms-ops '$concern' delegates to $expected_script"
  else
    fail "bin/lms-ops '$concern' does not delegate to $expected_script"
  fi
done

# 4. bin/lms-ops sources lane-normalize.sh
if grep -q "lane-normalize.sh" "$LMS_OPS" 2>/dev/null; then
  pass "bin/lms-ops sources lane-normalize.sh"
else
  fail "bin/lms-ops does not source lane-normalize.sh"
fi

# 5. Canonical entrypoints version >= 2.0.0 (authority cutover version)
ENTRYPOINTS="$REPO_ROOT/scripts/governance/canonical-entrypoints.yaml"
if [[ -f "$ENTRYPOINTS" ]]; then
  version="$(grep '^version:' "$ENTRYPOINTS" | head -1 | sed 's/.*: *//' | tr -d '"')"
  case "$version" in
    2.*)
      pass "canonical-entrypoints.yaml version $version (post-cutover)" ;;
    *)
      warn "canonical-entrypoints.yaml version $version (pre-cutover)" ;;
  esac
fi

# 6. front_door declared in canonical-entrypoints.yaml
if grep -q "^front_door:" "$ENTRYPOINTS" 2>/dev/null; then
  pass "front_door section declared in canonical-entrypoints.yaml"
  if grep -q "bin/lms-ops" "$ENTRYPOINTS" 2>/dev/null; then
    pass "front_door references bin/lms-ops"
  else
    fail "front_door does not reference bin/lms-ops"
  fi
else
  fail "front_door section missing from canonical-entrypoints.yaml"
fi

# 7. CI workflows must not bypass lms-ops for app-owned concerns.
if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  warn "workflow directory missing: $WORKFLOWS_DIR (skipping CI routing checks)"
else
  APP_OWNED_LEAF_SCRIPTS=(
    "scripts/release/migration-preflight.sh"
    "scripts/release/release-gate.sh"
    "scripts/release/smoke-after-migrate.sh"
    "scripts/release/smoke-by-service-wave.sh"
    "scripts/release/emit-proof-envelope.sh"
    "scripts/release/verify-zero-pending-migrations.sh"
    "scripts/qa/verify-topology-selectors.sh"
  )

  direct_calls=0
  for script_path in "${APP_OWNED_LEAF_SCRIPTS[@]}"; do
    hits="$(collect_workflow_invocations "$script_path")"
    if [[ -n "$hits" ]]; then
      direct_calls=$((direct_calls + 1))
      fail "workflow directly invokes app-owned leaf script: $script_path"
      while IFS= read -r hit_line; do
        [[ -n "$hit_line" ]] && echo "      $hit_line" >&2
      done <<<"$hits"
    fi
  done

  if [[ "$direct_calls" -eq 0 ]]; then
    pass "no workflow bypasses bin/lms-ops for app-owned concerns"
  fi

  # Transitional boundary debt: release-openedx-gitops.sh is env-owned and
  # should be retired from LMS workflows over time. While still present, lock
  # callers to a strict allowlist to prevent spread.
  ALLOWED_RELEASE_OPENEDX_GITOPS_CALLERS=(
    ".github/workflows/build-tutor-images.yml"
    ".github/workflows/release.yml"
    ".github/workflows/release-evidence.yml"
  )

  release_hits="$(collect_workflow_invocations "scripts/infra/release-openedx-gitops.sh")"
  if [[ -n "$release_hits" ]]; then
    release_files="$(printf '%s\n' "$release_hits" | awk -F: '{print $1}' | sort -u)"
    while IFS= read -r workflow_file; do
      [[ -z "$workflow_file" ]] && continue
      workflow_file_rel="$(normalize_repo_relative_path "$workflow_file")"
      if in_allowlist "$workflow_file_rel" "${ALLOWED_RELEASE_OPENEDX_GITOPS_CALLERS[@]}"; then
        pass "transitional env-owned caller allowlisted: $workflow_file_rel"
      else
        fail "unallowlisted workflow calls scripts/infra/release-openedx-gitops.sh: $workflow_file_rel"
      fi
    done <<<"$release_files"
    warn "release-openedx-gitops.sh remains in LMS workflow callers (boundary debt still active)"
  else
    pass "no workflow invokes scripts/infra/release-openedx-gitops.sh"
  fi

  lms_ops_hits="$(collect_workflow_invocations "bin/lms-ops")"
  if [[ -z "$lms_ops_hits" ]]; then
    fail "no workflow currently calls bin/lms-ops (front door not cut over in CI)"
  else
    pass "at least one workflow uses bin/lms-ops"
    lms_ops_files_raw="$(printf '%s\n' "$lms_ops_hits" | awk -F: '{print $1}' | sort -u)"
    lms_ops_files=""
    while IFS= read -r wf; do
      [[ -z "$wf" ]] && continue
      lms_ops_files+="${lms_ops_files:+$'\n'}$(normalize_repo_relative_path "$wf")"
    done <<<"$lms_ops_files_raw"

    REQUIRED_LMS_OPS_WORKFLOWS=(
      ".github/workflows/release-evidence.yml"
      ".github/workflows/build-tutor-images.yml"
    )
    for required_wf in "${REQUIRED_LMS_OPS_WORKFLOWS[@]}"; do
      if grep -Fxq "$required_wf" <<<"$lms_ops_files"; then
        pass "required workflow routes app proof via bin/lms-ops: $required_wf"
      else
        fail "required workflow missing bin/lms-ops call: $required_wf"
      fi
    done
  fi
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
[[ "$FAIL" -eq 0 ]] || exit 1
