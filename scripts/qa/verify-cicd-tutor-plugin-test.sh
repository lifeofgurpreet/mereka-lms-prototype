#!/usr/bin/env bash
# @covers AC-035, AC-036, AC-037, AC-038, AC-039
# @spec: ci-cd-pipeline_spec.md
# Verify tutor-plugin-test.yml workflow for the promoted Tutor plugin/render contract
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

WORKFLOW=".github/workflows/tutor-plugin-test.yml"

check_contains() {
  local label="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$WORKFLOW"; then
    pass "$label"
  else
    fail "$label"
  fi
}

if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-035: Workflow file $WORKFLOW not found"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

echo "Checking $WORKFLOW for Tutor plugin/render contract..."
echo ""

# AC-035: workflow keeps plugin-source lint/compile contract
check_contains "AC-035: Workflow defines lint-plugins job" "lint-plugins:"
check_contains "AC-035: Workflow compiles plugin sources" "python3 -m compileall infrastructure/tutor/plugins"
check_contains "AC-035: Workflow runs ruff against plugin sources" "ruff check infrastructure/tutor/plugins/"
check_contains "AC-035: Workflow runs black against plugin sources" "black --check infrastructure/tutor/plugins/"

# AC-036: workflow enforces retired standalone shim contract
check_contains "AC-036: Workflow defines retired legacy shim job" "verify-retired-legacy-shim:"
check_contains "AC-036: Workflow checks shim is metadata-only" "Legacy compatibility shim for the retired standalone mfe_oauth_fix Tutor plugin."
check_contains "AC-036: Workflow blocks ENV_PATCHES in legacy shim" "Legacy shim must not emit ENV_PATCHES"
check_contains "AC-036: Workflow keeps standalone plugin disabled in config.example.yml" "Legacy standalone plugin must remain disabled in config.example.yml"

# AC-037: workflow installs Tutor and runs render preflight
check_contains "AC-037: Workflow defines render-contract-preflight job" "render-contract-preflight:"
check_contains "AC-037: Workflow creates CI Tutor venv" "python3 -m venv .ci-venv"
check_contains "AC-037: Workflow installs Tutor requirements" "pip install -r requirements-tutor.txt"
check_contains "AC-037: Workflow runs rendered Dockerfile preflight" "./scripts/ci/preflight-check.sh"
check_contains "AC-037: Workflow passes TUTOR_VENV into preflight" 'TUTOR_VENV: ${{ github.workspace }}/.ci-venv'

# AC-038: workflow trigger paths cover plugin/render contract owners
check_contains "AC-038: Workflow watches Tutor plugin sources" "'infrastructure/tutor/plugins/**'"
check_contains "AC-038: Workflow watches Tutor config example" "'infrastructure/tutor/config.example.yml'"
check_contains "AC-038: Workflow watches render preflight source" "'scripts/ci/preflight-check.sh'"
check_contains "AC-038: Workflow watches Tutor plugin mirror sync source" "'scripts/infra/sync-tutor-plugin-mirror.sh'"
check_contains "AC-038: Workflow watches Tutor config verifier source" "'scripts/infra/verify-tutor-config.sh'"

# AC-039: render preflight is gated behind lint + legacy shim verification
check_contains "AC-039: Render preflight depends on lint-plugins" "needs: [lint-plugins, verify-retired-legacy-shim]"
check_contains "AC-039: Legacy shim verification depends on lint-plugins" "needs: lint-plugins"

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
