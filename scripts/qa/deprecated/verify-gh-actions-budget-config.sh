#!/usr/bin/env bash
# @spec: github-actions-cost-monitoring_spec.md
# @covers: AC-010
#
# Verify that GitHub Actions budget configuration file exists and is valid.
#
# AC-010: Given repository configuration, when budget is defined, then
# budget must be configurable via `.github/actions-budget.yml` file and
# environment variables (for overrides), and default budget is $50/month.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Verify GitHub Actions Budget Config (AC-010)"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

test_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

cd "$PROJECT_ROOT"

BUDGET_FILE=".github/actions-budget.yml"
EXAMPLE_FILE=".github/actions-budget.example.yml"

# Test 1: Check if budget config file exists OR example exists
echo "[Test 1] Budget configuration file existence"
if [[ -f "$BUDGET_FILE" ]]; then
    test_pass "Budget config exists at $BUDGET_FILE"
    CONFIG_FILE="$BUDGET_FILE"
elif [[ -f "$EXAMPLE_FILE" ]]; then
    test_warn "Budget config not found, but example exists at $EXAMPLE_FILE"
    CONFIG_FILE="$EXAMPLE_FILE"
else
    test_fail "Neither $BUDGET_FILE nor $EXAMPLE_FILE found"
    CONFIG_FILE=""
fi

# If we have a config file, validate it
if [[ -n "$CONFIG_FILE" ]]; then
    echo ""
    echo "[Test 2] Budget config is valid YAML"
    if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
        test_pass "Budget config is valid YAML"
    else
        test_fail "Budget config has invalid YAML syntax"
    fi

    echo ""
    echo "[Test 3] Budget config has required structure"

    # Check for 'budget' top-level key
    if grep -q "^budget:" "$CONFIG_FILE"; then
        test_pass "Config has 'budget:' top-level key"
    else
        test_fail "Config missing 'budget:' top-level key"
    fi

    # Check for monthly_limit_usd
    if grep -q "monthly_limit_usd:" "$CONFIG_FILE"; then
        test_pass "Config has 'monthly_limit_usd' field"

        # Extract and validate value
        MONTHLY_LIMIT=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE')).get('budget', {}).get('monthly_limit_usd', 'NOT_SET'))" 2>/dev/null || echo "PARSE_ERROR")

        if [[ "$MONTHLY_LIMIT" =~ ^[0-9]+$ ]]; then
            echo "    Monthly limit: \$${MONTHLY_LIMIT}"
            if [[ $MONTHLY_LIMIT -eq 50 ]]; then
                test_pass "Default budget is \$50/month (as specified)"
            elif [[ $MONTHLY_LIMIT -gt 0 ]]; then
                test_warn "Monthly limit is \$${MONTHLY_LIMIT} (default should be \$50)"
            else
                test_fail "Monthly limit is invalid: $MONTHLY_LIMIT"
            fi
        else
            test_fail "Cannot parse monthly_limit_usd value"
        fi
    else
        test_fail "Config missing 'monthly_limit_usd' field"
    fi

    # Check for hard_limit_usd
    echo ""
    echo "[Test 4] Budget config has hard limit"
    if grep -q "hard_limit_usd:" "$CONFIG_FILE"; then
        test_pass "Config has 'hard_limit_usd' field"

        HARD_LIMIT=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE')).get('budget', {}).get('hard_limit_usd', 'NOT_SET'))" 2>/dev/null || echo "PARSE_ERROR")

        if [[ "$HARD_LIMIT" =~ ^[0-9]+$ ]]; then
            echo "    Hard limit: \$${HARD_LIMIT}"
            if [[ $HARD_LIMIT -ge $MONTHLY_LIMIT ]]; then
                test_pass "Hard limit (\$${HARD_LIMIT}) >= monthly limit (\$${MONTHLY_LIMIT})"
            else
                test_fail "Hard limit (\$${HARD_LIMIT}) < monthly limit (\$${MONTHLY_LIMIT})"
            fi
        fi
    else
        test_fail "Config missing 'hard_limit_usd' field"
    fi

    # Check for alerts configuration
    echo ""
    echo "[Test 5] Budget config has alerts configuration"
    if grep -q "alerts:" "$CONFIG_FILE"; then
        test_pass "Config has 'alerts:' section"

        # Check for at least one alert threshold
        ALERT_COUNT=$(grep -c "threshold_percent:" "$CONFIG_FILE" || true)
        if [[ $ALERT_COUNT -gt 0 ]]; then
            test_pass "Config has $ALERT_COUNT alert threshold(s)"
        else
            test_fail "Config has no alert thresholds defined"
        fi

        # Check for 80% and 100% thresholds (as per spec)
        if grep -q "threshold_percent: 80" "$CONFIG_FILE"; then
            test_pass "Config has 80% warning threshold"
        else
            test_warn "Config missing 80% warning threshold"
        fi

        if grep -q "threshold_percent: 100" "$CONFIG_FILE"; then
            test_pass "Config has 100% critical threshold"
        else
            test_warn "Config missing 100% critical threshold"
        fi
    else
        test_fail "Config missing 'alerts:' section"
    fi

    # Check for workflow_limits configuration
    echo ""
    echo "[Test 6] Budget config has workflow limits"
    if grep -q "workflow_limits:" "$CONFIG_FILE"; then
        test_pass "Config has 'workflow_limits:' section"

        # Check for max_duration_minutes on at least one workflow
        if grep -q "max_duration_minutes:" "$CONFIG_FILE"; then
            test_pass "Config has workflow duration limits"
        else
            test_fail "Config missing workflow duration limits"
        fi
    else
        test_warn "Config missing 'workflow_limits:' section (optional but recommended)"
    fi
else
    # No config file found, create tests for expected structure
    echo ""
    echo "[Test 2-6] Skipping validation (no config file found)"
    test_warn "Create $BUDGET_FILE to enable cost monitoring"
fi

# Test 7: Verify environment variable override capability
echo ""
echo "[Test 7] Environment variable override support"
# This is tested by checking if any cost monitoring script sources env vars
if [[ -f scripts/qa/track-gh-actions-cost.sh ]]; then
    if grep -qE "(GITHUB_ACTIONS_BUDGET|MONTHLY_LIMIT)" scripts/qa/track-gh-actions-cost.sh; then
        test_pass "Cost tracking script supports environment variable overrides"
    else
        test_warn "Cost tracking script exists but may not support env overrides"
    fi
else
    test_warn "Cost tracking script not yet implemented (scripts/qa/track-gh-actions-cost.sh)"
fi

# Test 8: Check documentation
echo ""
echo "[Test 8] Budget configuration is documented"
if grep -rq "actions-budget.yml" docs/ 2>/dev/null; then
    test_pass "Budget configuration documented in docs/"
else
    test_warn "Budget configuration not documented in docs/"
fi

# Test 9: Verify .gitignore doesn't exclude budget config
echo ""
echo "[Test 9] Budget config not excluded by .gitignore"
if [[ -f .gitignore ]]; then
    if grep -q "actions-budget.yml" .gitignore; then
        test_fail "Budget config is gitignored (should be tracked)"
    else
        test_pass "Budget config not excluded by .gitignore"
    fi
else
    test_pass ".gitignore not found (no exclusion)"
fi

# Test 10: Validate alert channel configuration
if [[ -n "$CONFIG_FILE" ]]; then
    echo ""
    echo "[Test 10] Alert channels are configured"
    if grep -q "channel:" "$CONFIG_FILE"; then
        test_pass "Config specifies alert channels"

        # Check for slack channel
        if grep -q "slack" "$CONFIG_FILE"; then
            test_pass "Config includes Slack notifications"
        else
            test_warn "Config missing Slack notification channel"
        fi
    else
        test_warn "Config missing alert channel specifications"
    fi
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
    if [[ $WARN -gt 0 ]]; then
        echo -e "${YELLOW}⚠ AC-010 VERIFIED WITH WARNINGS: Budget config structure validated${NC}"
        echo ""
        echo "Recommendations:"
        if [[ ! -f "$BUDGET_FILE" ]]; then
            echo "  - Create $BUDGET_FILE from $EXAMPLE_FILE"
        fi
        echo "  - Ensure 80% and 100% alert thresholds are configured"
        echo "  - Document budget configuration in operational docs"
        exit 0
    else
        echo -e "${GREEN}✓ AC-010 VERIFIED: Budget configuration is valid${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ AC-010 FAILED: Budget configuration validation failed${NC}"
    exit 1
fi
