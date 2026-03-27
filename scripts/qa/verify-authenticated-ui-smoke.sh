#!/usr/bin/env bash
#
# verify-authenticated-ui-smoke.sh
#
# @covers AC-UIAUTH-001, AC-UIAUTH-002, AC-UIAUTH-003, AC-UIAUTH-004
#
# Source-level verification that authenticated UI smoke infrastructure is in place.
#
# Checks:
# - Smoke script exists and is executable
# - CI workflow exists and is properly configured
# - Visual regression test supports authenticated mode
# - Secrets documentation exists
#
# Usage:
#   ./scripts/qa/verify-authenticated-ui-smoke.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAIL_COUNT++)) || true
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
}

echo -e "${BLUE}=== Authenticated UI Smoke Verification ===${NC}"
echo ""

# ============================================================================
# AC-UIAUTH-001: Smoke script exists and is executable
# ============================================================================

echo -e "${BLUE}## AC-UIAUTH-001: Smoke Script${NC}"

SMOKE_SCRIPT="$REPO_ROOT/scripts/qa/smoke-authenticated.sh"

if [[ -f "$SMOKE_SCRIPT" ]]; then
  pass "Smoke script exists: scripts/qa/smoke-authenticated.sh"
else
  fail "Smoke script not found: scripts/qa/smoke-authenticated.sh"
fi

if [[ -x "$SMOKE_SCRIPT" ]]; then
  pass "Smoke script is executable"
else
  fail "Smoke script is not executable"
fi

# Check script covers required routes
if [[ -f "$SMOKE_SCRIPT" ]]; then
  ROUTES_FOUND=0

  if grep -q "learner-dashboard" "$SMOKE_SCRIPT"; then
    ROUTES_FOUND=$((ROUTES_FOUND + 1))
  fi

  if grep -q "learning" "$SMOKE_SCRIPT"; then
    ROUTES_FOUND=$((ROUTES_FOUND + 1))
  fi

  if grep -q "account" "$SMOKE_SCRIPT"; then
    ROUTES_FOUND=$((ROUTES_FOUND + 1))
  fi

  if [[ $ROUTES_FOUND -ge 3 ]]; then
    pass "Smoke script covers at least 3 authenticated routes (learner-dashboard, learning, account)"
  else
    fail "Smoke script covers fewer than 3 authenticated routes (found: $ROUTES_FOUND)"
  fi
fi

# Check script has @covers annotation
if [[ -f "$SMOKE_SCRIPT" ]]; then
  if grep -q "@covers AC-SMOKE-001" "$SMOKE_SCRIPT"; then
    pass "Smoke script has @covers AC-SMOKE-001 annotation"
  else
    warn "Smoke script missing @covers annotation"
  fi
fi

echo ""

# ============================================================================
# AC-UIAUTH-002: Visual regression test supports authenticated mode
# ============================================================================

echo -e "${BLUE}## AC-UIAUTH-002: Visual Regression Authenticated Support${NC}"

VISUAL_SCRIPT="$REPO_ROOT/scripts/qa/visual-regression-test.sh"

if [[ -f "$VISUAL_SCRIPT" ]]; then
  pass "Visual regression script exists: scripts/qa/visual-regression-test.sh"
else
  fail "Visual regression script not found"
fi

if [[ -f "$VISUAL_SCRIPT" ]]; then
  # Check for --authenticated flag support
  if grep -q "\-\-authenticated" "$VISUAL_SCRIPT"; then
    pass "Visual regression script supports --authenticated flag"
  else
    fail "Visual regression script does not support --authenticated flag"
  fi

  # Check for SSO credential handling
  if grep -q "SSO_USERNAME" "$VISUAL_SCRIPT" && grep -q "SSO_PASSWORD" "$VISUAL_SCRIPT"; then
    pass "Visual regression script references SSO credentials"
  else
    fail "Visual regression script does not reference SSO credentials"
  fi

  # Check for graceful fallback when credentials not provided
  if grep -q -i "skip\|fallback" "$VISUAL_SCRIPT"; then
    pass "Visual regression script has graceful fallback mechanism"
  else
    warn "Visual regression script may not have graceful fallback for missing credentials"
  fi
fi

echo ""

# ============================================================================
# AC-UIAUTH-003: CI workflow exists and is properly configured
# ============================================================================

echo -e "${BLUE}## AC-UIAUTH-003: CI Workflow${NC}"

CI_WORKFLOW="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"

if [[ -f "$CI_WORKFLOW" ]]; then
  pass "CI workflow exists: .github/workflows/smoke-authenticated.yml"
else
  fail "CI workflow not found: .github/workflows/smoke-authenticated.yml"
fi

if [[ -f "$CI_WORKFLOW" ]]; then
  # Check for workflow_dispatch trigger
  if grep -q "workflow_dispatch" "$CI_WORKFLOW"; then
    pass "CI workflow has workflow_dispatch trigger"
  else
    fail "CI workflow missing workflow_dispatch trigger"
  fi

  # Check for staging-first default scope
  if grep -q "default: 'staging'" "$CI_WORKFLOW" && grep -q "github.event.inputs.env_scope || 'staging'" "$CI_WORKFLOW"; then
    pass "CI workflow defaults env_scope to staging"
  else
    fail "CI workflow does not default env_scope to staging"
  fi

  # Check for staging target resolution
  if grep -q 'scope="${INPUT_ENV_SCOPE:-staging}"' "$CI_WORKFLOW" && grep -q 'default_target="https://staging.academyv2.mereka.io"' "$CI_WORKFLOW"; then
    pass "CI workflow resolves staging as the default authenticated smoke target"
  else
    fail "CI workflow does not resolve staging as the default authenticated smoke target"
  fi

  # Check for dedicated smoke secret wiring plus staging canary fallback
  if grep -q "SMOKE_SSO_USERNAME" "$CI_WORKFLOW" && grep -q "SMOKE_SSO_PASSWORD" "$CI_WORKFLOW" && \
     grep -q "SSO_CANARY_EMAIL_STAGING" "$CI_WORKFLOW" && grep -q "SSO_CANARY_PASSWORD_STAGING" "$CI_WORKFLOW"; then
    pass "CI workflow wires dedicated smoke secrets and staging canary fallback"
  else
    fail "CI workflow does not wire dedicated smoke secrets and staging canary fallback"
  fi

  # Check for resolved credential injection
  if grep -q 'steps.resolve-smoke.outputs.sso_username' "$CI_WORKFLOW" && \
     grep -q 'steps.resolve-smoke.outputs.sso_password' "$CI_WORKFLOW"; then
    pass "CI workflow injects resolved smoke credentials into downstream steps"
  else
    fail "CI workflow does not inject resolved smoke credentials into downstream steps"
  fi

  # Check for resolved scope propagation into visual regression
  if grep -q 'resolved_scope' "$CI_WORKFLOW" && grep -q 'steps.resolve-smoke.outputs.resolved_scope' "$CI_WORKFLOW"; then
    pass "CI workflow propagates the resolved env scope into visual regression"
  else
    fail "CI workflow does not propagate the resolved env scope into visual regression"
  fi

  # Check for Playwright installation
  if grep -q "playwright install" "$CI_WORKFLOW"; then
    pass "CI workflow installs Playwright browsers"
  else
    fail "CI workflow missing Playwright browser installation"
  fi

  # Check for artifact upload
  if grep -q "upload-artifact\|actions/upload-artifact" "$CI_WORKFLOW"; then
    pass "CI workflow uploads artifacts (screenshots/logs)"
  else
    warn "CI workflow does not upload artifacts"
  fi

  # Check for visual regression test invocation
  if grep -q "visual-regression-test.sh" "$CI_WORKFLOW"; then
    pass "CI workflow includes visual regression test"
  else
    warn "CI workflow does not include visual regression test"
  fi
fi

echo ""

# ============================================================================
# AC-UIAUTH-004: Secrets documentation exists
# ============================================================================

echo -e "${BLUE}## AC-UIAUTH-004: Secrets Documentation${NC}"

DOCS_CANDIDATES=(
  "$REPO_ROOT/docs/reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md"
)

DOCS_FOUND=false
DOCS_PATH=""

for doc in "${DOCS_CANDIDATES[@]}"; do
  if [[ -f "$doc" ]]; then
    DOCS_FOUND=true
    DOCS_PATH="$doc"
    break
  fi
done

if [[ "$DOCS_FOUND" == "true" ]]; then
  pass "Secrets documentation exists: $(basename "$DOCS_PATH")"

  # Check documentation covers required topics
  if grep -iq "github.*secret\|secret.*github" "$DOCS_PATH"; then
    pass "Documentation covers GitHub secrets storage"
  else
    warn "Documentation may not cover GitHub secrets storage"
  fi

  if grep -iq "rotat" "$DOCS_PATH"; then
    pass "Documentation covers credential rotation"
  else
    warn "Documentation may not cover credential rotation"
  fi

  if grep -iq "credential\|password" "$DOCS_PATH"; then
    pass "Documentation covers credential handling"
  else
    warn "Documentation may not cover credential handling"
  fi

  if grep -iq "test.*user\|smoke.*user\|test account" "$DOCS_PATH"; then
    pass "Documentation covers test user requirements"
  else
    warn "Documentation may not cover test user requirements"
  fi
else
  fail "Secrets documentation not found in docs/reference/operations/"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}## Summary${NC}"
echo ""
echo "Coverage:"
echo "  AC-UIAUTH-001: Smoke script infrastructure"
echo "  AC-UIAUTH-002: Visual regression authenticated support"
echo "  AC-UIAUTH-003: CI workflow configuration"
echo "  AC-UIAUTH-004: Secrets documentation"
echo ""
echo "Results:"
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}All authenticated UI smoke infrastructure checks passed${NC}"
  exit 0
else
  echo -e "${RED}Some checks failed${NC}"
  exit 1
fi
