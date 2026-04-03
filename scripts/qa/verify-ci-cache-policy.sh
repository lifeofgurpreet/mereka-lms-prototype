#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_absent() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

NODE_ACTION="$REPO_ROOT/.github/actions/setup-playwright/action.yml"
PYTHON_ACTION="$REPO_ROOT/.github/actions/setup-python-playwright/action.yml"
SMOKE_UNAUTHENTICATED="$REPO_ROOT/.github/workflows/smoke-unauthenticated.yml"
SMOKE_AUTHENTICATED="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"
OPERATIONS_GATES="$REPO_ROOT/.github/workflows/operations-gates-runtime.yml"
POST_DEPLOY_E2E="$REPO_ROOT/.github/workflows/post-deploy-e2e.yml"
E2E_TESTS="$REPO_ROOT/.github/workflows/e2e-tests.yml"
OPENEDX_BUILD="$REPO_ROOT/scripts/infra/build-openedx-image.sh"
MFE_BUILD="$REPO_ROOT/scripts/infra/build-mfe-image.sh"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"

echo -e "${BLUE}=== CI Cache Policy Verification ===${NC}"
echo

echo -e "${BLUE}## Shared Playwright actions${NC}"
check_contains "$NODE_ACTION" "path: ~/.cache/ms-playwright" "setup-playwright caches Playwright browsers"
check_contains "$NODE_ACTION" "npx playwright install chromium" "setup-playwright repairs Chromium on cache miss"
check_contains "$NODE_ACTION" "npm-cache-dependency-path" "setup-playwright supports npm dependency cache keys"

check_contains "$PYTHON_ACTION" "uses: ./.github/actions/setup-python-env" "setup-python-playwright reuses setup-python-env"
check_contains "$PYTHON_ACTION" "path: ~/.cache/ms-playwright" "setup-python-playwright caches Playwright browsers"
check_contains "$PYTHON_ACTION" 'python -m playwright install "${args[@]}"' "setup-python-playwright repairs Chromium on cache miss"
check_contains "$PYTHON_ACTION" "install-system-deps" "setup-python-playwright supports system dependency installation"
echo

echo -e "${BLUE}## Browser workflow bootstrap paths${NC}"
check_contains "$SMOKE_UNAUTHENTICATED" "uses: ./.github/actions/setup-playwright" "smoke-unauthenticated uses shared Node Playwright action"
check_contains "$SMOKE_UNAUTHENTICATED" "npm-cache-dependency-path: tests/e2e/package-lock.json" "smoke-unauthenticated keys npm cache from tests/e2e lockfile"
check_absent "$SMOKE_UNAUTHENTICATED" "npx playwright install --with-deps chromium" "smoke-unauthenticated does not install browsers inline"

check_contains "$SMOKE_AUTHENTICATED" "uses: ./.github/actions/setup-playwright" "smoke-authenticated smoke job uses shared Node Playwright action"
check_contains "$SMOKE_AUTHENTICATED" "uses: ./.github/actions/setup-python-playwright" "smoke-authenticated sso-canary job uses shared Python Playwright action"
check_absent "$SMOKE_AUTHENTICATED" "python -m playwright install chromium" "smoke-authenticated does not install Python Playwright browsers inline"
check_absent "$SMOKE_AUTHENTICATED" "path: ~/.cache/ms-playwright" "smoke-authenticated does not duplicate Playwright cache wiring inline"

check_contains "$OPERATIONS_GATES" "uses: ./.github/actions/setup-python-playwright" "operations-gates-runtime uses shared Python Playwright action"
check_contains "$OPERATIONS_GATES" "install-system-deps: 'true'" "operations-gates-runtime requests system deps through the shared Python Playwright action"
check_absent "$OPERATIONS_GATES" "python -m playwright install --with-deps chromium" "operations-gates-runtime does not install browsers inline"

check_contains "$POST_DEPLOY_E2E" "uses: ./.github/actions/setup-playwright" "post-deploy-e2e uses shared Node Playwright action"
check_contains "$E2E_TESTS" "uses: ./.github/actions/setup-playwright" "e2e-tests uses shared Node Playwright action"
echo

echo -e "${BLUE}## Image build cache policy${NC}"
check_contains "$OPENEDX_BUILD" '--cache-from "type=gha"' "build-openedx-image uses GHA cache restore"
check_contains "$OPENEDX_BUILD" '--cache-to "type=gha,mode=max"' "build-openedx-image uses GHA cache write-back"
check_contains "$OPENEDX_BUILD" '--cache-from "type=registry,ref=${CACHE_REF}"' "build-openedx-image uses registry cache fallback"
check_contains "$OPENEDX_BUILD" "--build-arg BUILDKIT_INLINE_CACHE=1" "build-openedx-image exports inline cache metadata"

check_contains "$MFE_BUILD" '--cache-from "type=gha"' "build-mfe-image uses GHA cache restore"
check_contains "$MFE_BUILD" '--cache-to "type=gha,mode=max"' "build-mfe-image uses GHA cache write-back"
check_contains "$MFE_BUILD" '--cache-from "type=registry,ref=${CACHE_REF}"' "build-mfe-image uses registry cache fallback"
check_contains "$MFE_BUILD" "--build-arg BUILDKIT_INLINE_CACHE=1" "build-mfe-image exports inline cache metadata"

check_contains "$BUILD_WORKFLOW" "uses: docker/setup-buildx-action" "build-tutor-images uses buildx"
check_contains "$BUILD_WORKFLOW" "./scripts/infra/build-openedx-image.sh" "build-tutor-images routes OpenEdX through the cache-aware helper"
check_contains "$BUILD_WORKFLOW" "./scripts/infra/build-mfe-image.sh" "build-tutor-images routes MFE through the cache-aware helper"
echo

echo -e "${BLUE}## Summary${NC}"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

echo "CI cache policy checks passed."
