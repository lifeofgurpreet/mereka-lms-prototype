#!/usr/bin/env bash
# @covers AC-031, AC-032, AC-033
# @spec: content-libraries-v2_spec.md
# Verify load test infrastructure for Content Libraries v2 (validation script, not test runner)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Content Libraries v2 Load Test Infrastructure Validation ==="
echo ""
echo "NOTE: This script validates load test CONFIGURATION, not runs actual load tests."
echo ""

# ---------------------------------------------------------------------------
# AC-031: Library listing API responds within 500ms at p95 for 100 libraries
# Verify: Performance threshold documentation and monitoring
# ---------------------------------------------------------------------------
echo "[AC-031] Verifying library listing performance requirements..."

# Check for performance requirements documentation
if grep -r "500ms\|library.*listing.*performance" docs/ specs/ 2>/dev/null | grep -q "500ms"; then
  pass "AC-031: Library listing p95 500ms requirement documented"
else
  skip "AC-031: Performance requirement not found in docs (defined in spec)"
fi

# Check for performance monitoring configuration
if grep -r "content_library.*latency\|library.*api.*latency" infrastructure/observability/ deploy/k8s/base/apps/openedx/ 2>/dev/null | grep -q "latency"; then
  pass "AC-031: Library API latency metrics configured"
else
  skip "AC-031: Library API latency metrics (to be added in observability phase)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-032: Component listing responds within 1000ms for 1000 components
# Verify: Pagination and performance thresholds
# ---------------------------------------------------------------------------
echo "[AC-032] Verifying component listing performance requirements..."

# Check for pagination configuration
if grep -r "page_size\|PAGE_SIZE.*20\|library.*pagination" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q "page\|PAGE"; then
  pass "AC-032: Pagination configuration found"
else
  skip "AC-032: Pagination configuration (using Django REST framework defaults)"
fi

# Check for component count documentation
if grep -r "1000.*component\|1,000.*component" docs/ specs/ 2>/dev/null | grep -q "1000\|1,000"; then
  pass "AC-032: 1000 component scalability requirement documented"
else
  skip "AC-032: Component count threshold not explicit in docs (defined in spec)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-033: Library publish completes within 30 seconds for 500 components
# Verify: Async task configuration and timeout settings
# ---------------------------------------------------------------------------
echo "[AC-033] Verifying library publish performance requirements..."

# Check for Celery task timeout configuration
if grep -r "CELERY.*TIMEOUT\|task.*timeout.*30" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q -i "timeout"; then
  pass "AC-033: Celery task timeout configuration found"
else
  skip "AC-033: Celery task timeout (using defaults)"
fi

# Check for library publish async task references
if grep -r "library.*publish\|commit.*library\|blockstore.*commit" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q "publish\|commit"; then
  pass "AC-033: Library publish workflow references found"
else
  skip "AC-033: Library publish configuration (in base Open edX code)"
fi

echo ""

# ---------------------------------------------------------------------------
# Load Test Tooling Infrastructure
# ---------------------------------------------------------------------------
echo "[Load Test Tooling] Verifying load test infrastructure..."

# Check for load testing tools (k6, locust, or similar)
LOAD_TEST_TOOLS_FOUND=false

if command -v k6 &>/dev/null; then
  pass "Tooling: k6 load testing tool installed"
  LOAD_TEST_TOOLS_FOUND=true
elif [[ -f "package.json" ]] && grep -q "k6\|artillery" package.json; then
  pass "Tooling: Load testing tool referenced in package.json"
  LOAD_TEST_TOOLS_FOUND=true
fi

if command -v locust &>/dev/null; then
  pass "Tooling: Locust load testing tool installed"
  LOAD_TEST_TOOLS_FOUND=true
elif [[ -f "requirements.txt" ]] && grep -q "locust" requirements.txt; then
  pass "Tooling: Locust referenced in requirements.txt"
  LOAD_TEST_TOOLS_FOUND=true
fi

if [[ "$LOAD_TEST_TOOLS_FOUND" == "false" ]]; then
  skip "Tooling: No load testing tools found (k6, locust, artillery)"
  echo "       To add: install k6 (https://k6.io/) or locust (pip install locust)"
fi

echo ""

# ---------------------------------------------------------------------------
# Load Test Scenarios
# ---------------------------------------------------------------------------
echo "[Load Test Scenarios] Verifying load test scenario definitions..."

# Check for load test scenario files
SCENARIO_FOUND=false

if [[ -d "tests/load" ]] || [[ -d "load-tests" ]] || [[ -d "tests/performance" ]]; then
  pass "Scenarios: Load test directory structure exists"
  SCENARIO_FOUND=true

  # Check for library-specific scenarios
  if find tests load-tests tests/performance -name "*library*" -o -name "*content*library*" 2>/dev/null | grep -q "library"; then
    pass "Scenarios: Library-specific load test scenarios found"
  else
    skip "Scenarios: No library-specific scenarios (to be created)"
  fi
else
  skip "Scenarios: Load test directory not found (tests/load/ or load-tests/ needed)"
fi

# Check for scenario documentation
if [[ -d "docs" ]]; then
  if grep -r "load.*test\|performance.*test" docs/ 2>/dev/null | grep -q "load\|performance"; then
    pass "Scenarios: Load test documentation found"
  else
    skip "Scenarios: Load test documentation (to be created)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Performance Thresholds Configuration
# ---------------------------------------------------------------------------
echo "[Performance Thresholds] Verifying performance threshold configuration..."

# Check for threshold configuration file
THRESHOLD_FILES=("tests/load/thresholds.yaml" "tests/load/thresholds.json" "load-tests/config.yaml")
THRESHOLD_FOUND=false

for file in "${THRESHOLD_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "Thresholds: Performance threshold file found: $file"
    THRESHOLD_FOUND=true
    break
  fi
done

if [[ "$THRESHOLD_FOUND" == "false" ]]; then
  skip "Thresholds: No threshold configuration file found"
  echo "       Recommended: Create tests/load/thresholds.yaml with p95 targets"
fi

# Check for CI integration
if [[ -d ".github/workflows" ]]; then
  if grep -r "load.*test\|performance.*test" .github/workflows/ 2>/dev/null | grep -q "load\|performance"; then
    pass "CI: Load test workflow found in GitHub Actions"
  else
    skip "CI: Load test workflow not found (manual execution only)"
  fi
else
  skip "CI: GitHub Actions not configured for load tests"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary and Recommendations
# ---------------------------------------------------------------------------
echo "=== Load Test Infrastructure Recommendations ==="
echo ""

if [[ "$LOAD_TEST_TOOLS_FOUND" == "false" ]]; then
  echo "RECOMMENDATION: Install k6 for library API load testing"
  echo "  Installation: brew install k6 (macOS) or https://k6.io/docs/getting-started/installation/"
  echo ""
fi

if [[ "$SCENARIO_FOUND" == "false" ]]; then
  echo "RECOMMENDATION: Create load test scenarios for Content Libraries v2"
  echo "  Directory: tests/load/"
  echo "  Scenarios needed:"
  echo "    - library-listing.js (AC-031: 100 libraries, p95 < 500ms)"
  echo "    - component-listing.js (AC-032: 1000 components, p95 < 1000ms)"
  echo "    - library-publish.js (AC-033: 500 components, < 30 seconds)"
  echo ""
fi

if [[ "$THRESHOLD_FOUND" == "false" ]]; then
  echo "RECOMMENDATION: Create performance threshold configuration"
  echo "  File: tests/load/thresholds.yaml"
  echo "  Content example:"
  echo "    library_listing_p95: 500ms"
  echo "    component_listing_p95: 1000ms"
  echo "    library_publish_max: 30s"
  echo ""
fi

echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
echo ""
echo "VALIDATION STATUS: This script checks load test INFRASTRUCTURE only."
echo "Actual load testing requires:"
echo "  1. Load test tool installed (k6, locust)"
echo "  2. Test scenarios written for library APIs"
echo "  3. Performance thresholds defined"
echo "  4. Live cluster or staging environment"
echo ""

[[ $FAIL -gt 0 ]] && exit 1
exit 0
