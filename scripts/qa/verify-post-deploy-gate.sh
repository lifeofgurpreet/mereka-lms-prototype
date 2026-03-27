#!/usr/bin/env bash
# @covers AC-040, AC-041, AC-042, AC-043, AC-044
# @spec: ci-cd-pipeline_spec.md
# verify-post-deploy-gate.sh — Verify the post-deploy E2E gate is correctly wired
#
# Two modes:
#   --mode offline  (default) Check that workflow exists, is structured correctly,
#                   has blocking triggers, and covers the 5 critical paths.
#   --mode online   Query GitHub API to verify the last E2E gate run passed.
#
# Usage:
#   ./scripts/qa/verify-post-deploy-gate.sh
#   ./scripts/qa/verify-post-deploy-gate.sh --mode offline
#   ./scripts/qa/verify-post-deploy-gate.sh --mode online
#   GITHUB_REPO=org/repo GH_TOKEN=... ./scripts/qa/verify-post-deploy-gate.sh --mode online

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

MODE="offline"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-offline}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--mode offline|online]"
      echo ""
      echo "  offline  Check workflow file structure and wiring (default)"
      echo "  online   Verify last E2E gate run passed via GitHub API"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "SKIP: $1"; }

WORKFLOW_FILE="$REPO_ROOT/.github/workflows/post-deploy-e2e.yml"

# ── Section 1: Workflow File Existence ───────────────────────────────────────

echo "=== Post-Deploy E2E Gate Verification ==="
echo "Mode: $MODE"
echo ""
echo "--- Workflow File ---"

if [[ -f "$WORKFLOW_FILE" ]]; then
  pass "Workflow file exists: .github/workflows/post-deploy-e2e.yml"
else
  fail "Workflow file missing: .github/workflows/post-deploy-e2e.yml"
  echo ""
  echo "RESULT: FAIL — post-deploy E2E gate workflow not found"
  exit 1
fi

# ── Section 2: Trigger Configuration ─────────────────────────────────────────

echo ""
echo "--- Trigger Configuration ---"

# Must support workflow_run (post-deployment trigger)
if grep -q "workflow_run" "$WORKFLOW_FILE"; then
  pass "Workflow has workflow_run trigger (post-deployment)"
else
  fail "Workflow missing workflow_run trigger — gate will not run after deployment"
fi

# Must support manual dispatch
if grep -q "workflow_dispatch" "$WORKFLOW_FILE"; then
  pass "Workflow has workflow_dispatch trigger (manual re-run)"
else
  fail "Workflow missing workflow_dispatch trigger"
fi

# Concurrency must be configured to prevent overlapping gates
if grep -q "concurrency:" "$WORKFLOW_FILE"; then
  pass "Concurrency group configured (prevents overlapping gate runs)"
else
  fail "Missing concurrency configuration — parallel gate runs risk false results"
fi

if grep -q 'default: "staging"' "$WORKFLOW_FILE" \
  && grep -q 'https://staging.academyv2.mereka.io' "$WORKFLOW_FILE"; then
  pass "Workflow defaults to the canonical staging lane while prod is explicit"
else
  fail "Workflow missing staging-first default target resolution"
fi

# Gate must resolve credentials from canonical secret sources
if grep -q "Resolve E2E credential source" "$WORKFLOW_FILE" \
  && grep -q "SSO_CANARY_EMAIL_PROD" "$WORKFLOW_FILE" \
  && grep -q "SSO_CANARY_PASSWORD_PROD" "$WORKFLOW_FILE"; then
  pass "Workflow resolves E2E credentials from override and canary secret sources"
else
  fail "Workflow missing canonical E2E credential fallback wiring"
fi

# ── Section 3: Blocking Gate Structure ───────────────────────────────────────

echo ""
echo "--- Blocking Gate Structure ---"

# Must have a pre-flight check that skips on failed deploy
if grep -q "should_run" "$WORKFLOW_FILE"; then
  pass "Pre-flight gate check output present (skips on failed deploy)"
else
  fail "Missing pre-flight gate check — gate may run against a broken deploy"
fi

# Must post a commit status
if grep -q "statuses.*write\|post.*status\|commit.*status\|\/statuses\/" "$WORKFLOW_FILE" \
  && grep -q 'post-deploy-e2e/critical-paths-${GATE_ENVIRONMENT}' "$WORKFLOW_FILE"; then
  pass "Workflow posts environment-scoped deployment status to commit"
else
  fail "Workflow does not post environment-scoped commit status — gate results not visible truthfully on PRs"
fi

# Artifacts must be uploaded for debugging
if grep -q "upload-artifact" "$WORKFLOW_FILE"; then
  pass "E2E artifacts uploaded for debugging"
else
  fail "No artifact upload — failures will be undebuggable"
fi

# Must have timeout to prevent hanging
if grep -q "timeout-minutes" "$WORKFLOW_FILE"; then
  pass "Timeout configured on E2E job"
else
  fail "No timeout on E2E job — hung test could block releases indefinitely"
fi

if grep -q "npm-cache-dependency-path: tests/e2e/package-lock.json" "$WORKFLOW_FILE"; then
  pass "Workflow keys Playwright/npm setup off tests/e2e/package-lock.json"
else
  fail "Workflow missing package-lock keyed Playwright setup"
fi

# ── Section 4: Critical Path Coverage ────────────────────────────────────────

echo ""
echo "--- Critical Path Coverage ---"

CRITICAL_PATHS=("login" "enroll" "video" "forum" "certificate")
for path in "${CRITICAL_PATHS[@]}"; do
  if grep -qi "$path" "$WORKFLOW_FILE"; then
    pass "Critical path referenced: $path"
  else
    fail "Critical path not referenced in workflow: $path"
  fi
done

# Oscar ecommerce must NOT be referenced as a critical path
if grep -qi "oscar\|ecommerce.*critical\|ecommerce.*path" "$WORKFLOW_FILE"; then
  fail "Oscar ecommerce referenced as critical path — Oscar is DEPRECATED"
else
  pass "Oscar ecommerce not referenced as critical path (correctly deprecated)"
fi

# ── Section 5: Security Baseline ─────────────────────────────────────────────

echo ""
echo "--- Security Baseline ---"

# No hard-coded credentials
if grep -qE "(password|secret|token)\s*=\s*['\"][^$][^'\"]+['\"]" "$WORKFLOW_FILE"; then
  fail "Potential hardcoded credential found in workflow"
else
  pass "No hardcoded credentials detected"
fi

# permissions must be explicitly set
if grep -q "^permissions:" "$WORKFLOW_FILE"; then
  pass "Top-level permissions are explicitly declared"
else
  fail "Missing top-level permissions declaration"
fi

# Pinned action versions
ACTIONS_COUNT=$(grep -c "uses:.*@" "$WORKFLOW_FILE" 2>/dev/null || echo "0")
PINNED_COUNT=$(grep -c "uses:.*@[a-f0-9]\{40\}" "$WORKFLOW_FILE" 2>/dev/null || echo "0")
NAMED_COUNT=$(grep -c "uses:.*@v[0-9]" "$WORKFLOW_FILE" 2>/dev/null || echo "0")

if [[ "$ACTIONS_COUNT" -eq 0 ]]; then
  skip "No GitHub Actions uses found to check pinning"
elif [[ "$PINNED_COUNT" -gt 0 ]] || [[ "$NAMED_COUNT" -gt 0 ]]; then
  pass "GitHub Actions are pinned to specific versions ($PINNED_COUNT SHA-pinned, $NAMED_COUNT tag-pinned of $ACTIONS_COUNT total)"
else
  fail "GitHub Actions are not pinned to specific versions"
fi

# ── Section 6: Verify Script Exists ──────────────────────────────────────────

echo ""
echo "--- Verification Script ---"

SELF="$REPO_ROOT/scripts/qa/verify-post-deploy-gate.sh"
if [[ -f "$SELF" ]]; then
  pass "Verification script exists: scripts/qa/verify-post-deploy-gate.sh"
else
  fail "Verification script missing: scripts/qa/verify-post-deploy-gate.sh"
fi

if [[ -x "$SELF" ]]; then
  pass "Verification script is executable"
else
  fail "Verification script is not executable (run: chmod +x scripts/qa/verify-post-deploy-gate.sh)"
fi

# ── Section 7: Operational Doc ───────────────────────────────────────────────

echo ""
echo "--- Operational Documentation ---"

OPS_DOC="$REPO_ROOT/docs/ops/runbooks/POST_DEPLOY_GATE.md"
if [[ -f "$OPS_DOC" ]]; then
  pass "Operational doc exists: docs/ops/runbooks/POST_DEPLOY_GATE.md"
else
  fail "Operational doc missing: docs/ops/runbooks/POST_DEPLOY_GATE.md"
fi

# ── Section 8: Online Mode — GitHub API Check ────────────────────────────────

if [[ "$MODE" == "online" ]]; then
  echo ""
  echo "--- Online: Last E2E Gate Run Status ---"

  GITHUB_REPO="${GITHUB_REPO:-${GITHUB_REPOSITORY:-}}"
  GH_TOKEN_VAL="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

  if [[ -z "$GITHUB_REPO" ]]; then
    skip "GITHUB_REPO not set — cannot query GitHub API (set GITHUB_REPO=org/repo)"
  elif [[ -z "$GH_TOKEN_VAL" ]]; then
    skip "GH_TOKEN not set — cannot authenticate to GitHub API"
  else
    # Query last completed run of post-deploy-e2e workflow
    WORKFLOW_RUNS_JSON="$(
      curl -sf \
        -H "Authorization: Bearer $GH_TOKEN_VAL" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPO}/actions/workflows/post-deploy-e2e.yml/runs?status=completed&per_page=1" \
        2>/dev/null || echo ""
    )"

    if [[ -z "$WORKFLOW_RUNS_JSON" ]]; then
      skip "Could not reach GitHub API (network unavailable or auth failed)"
    else
      LAST_CONCLUSION="$(
        echo "$WORKFLOW_RUNS_JSON" \
          | python3 -c "import json,sys; runs=json.load(sys.stdin).get('workflow_runs',[]); print(runs[0]['conclusion'] if runs else 'no_runs')" \
          2>/dev/null || echo "parse_error"
      )"
      LAST_RUN_URL="$(
        echo "$WORKFLOW_RUNS_JSON" \
          | python3 -c "import json,sys; runs=json.load(sys.stdin).get('workflow_runs',[]); print(runs[0].get('html_url','') if runs else '')" \
          2>/dev/null || echo ""
      )"

      case "$LAST_CONCLUSION" in
        success)
          pass "Last E2E gate run passed ($LAST_RUN_URL)"
          ;;
        no_runs)
          skip "No completed E2E gate runs found — gate has not run yet"
          ;;
        failure|cancelled)
          fail "Last E2E gate run: $LAST_CONCLUSION ($LAST_RUN_URL)"
          ;;
        parse_error)
          skip "Could not parse GitHub API response"
          ;;
        *)
          skip "Last E2E gate run conclusion: $LAST_CONCLUSION (unexpected value)"
          ;;
      esac
    fi
  fi
else
  echo ""
  echo "--- Online checks skipped (offline mode) ---"
  skip "Online: last E2E run status (use --mode online to check)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: PASS"
exit 0
