#!/usr/bin/env bash
set -euo pipefail

# GitHub Actions Cost Verification Script
# Checks GitHub Actions usage against budget thresholds
# Exit codes: 0 = OK, 1 = Warning (>80%), 2 = Critical (>90%)

# Configuration
ORG="${GITHUB_ORG:-Biji-Biji-Initiative}"
WARN_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install with: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: gh CLI not authenticated. Run: gh auth login"
    exit 1
fi

echo "GitHub Actions Usage Report"
echo "==========================="

# Fetch billing data
BILLING_DATA=$(gh api "/orgs/${ORG}/settings/billing/actions" 2>/dev/null)

if [ -z "$BILLING_DATA" ]; then
    echo "Error: Unable to fetch billing data. Verify organization name and permissions."
    exit 1
fi

# Parse billing data
TOTAL_MINUTES=$(echo "$BILLING_DATA" | jq -r '.total_minutes_used // 0')
INCLUDED_MINUTES=$(echo "$BILLING_DATA" | jq -r '.included_minutes // 2000')
PAID_MINUTES=$(echo "$BILLING_DATA" | jq -r '.total_paid_minutes_used // 0')

# Minutes breakdown by OS
UBUNTU_MINUTES=$(echo "$BILLING_DATA" | jq -r '.minutes_used_breakdown.UBUNTU // 0')
MACOS_MINUTES=$(echo "$BILLING_DATA" | jq -r '.minutes_used_breakdown.MACOS // 0')
WINDOWS_MINUTES=$(echo "$BILLING_DATA" | jq -r '.minutes_used_breakdown.WINDOWS // 0')

# Calculate usage percentage
if [ "$INCLUDED_MINUTES" -eq 0 ]; then
    USAGE_PERCENT=0
else
    USAGE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_MINUTES / $INCLUDED_MINUTES) * 100}")
fi

# Print usage summary
echo "Total minutes used: ${TOTAL_MINUTES} / ${INCLUDED_MINUTES} (${USAGE_PERCENT}%)"
echo "Paid minutes: ${PAID_MINUTES}"

# Determine status
if (( $(echo "$USAGE_PERCENT >= $CRITICAL_THRESHOLD" | bc -l) )); then
    STATUS="${RED}CRITICAL${NC}"
    EXIT_CODE=2
elif (( $(echo "$USAGE_PERCENT >= $WARN_THRESHOLD" | bc -l) )); then
    STATUS="${YELLOW}WARNING${NC}"
    EXIT_CODE=1
else
    STATUS="${GREEN}OK${NC}"
    EXIT_CODE=0
fi

echo -e "Status: ${STATUS}"
echo ""

# Print breakdown by OS
echo "Breakdown by OS:"
echo "  Ubuntu: ${UBUNTU_MINUTES} minutes"
echo "  macOS: ${MACOS_MINUTES} minutes"
echo "  Windows: ${WINDOWS_MINUTES} minutes"
echo ""

# Print alerts based on thresholds
if [ "$EXIT_CODE" -eq 2 ]; then
    echo -e "${RED}⚠ CRITICAL: Usage >= ${CRITICAL_THRESHOLD}%${NC}"
    echo "Action required:"
    echo "  1. Disable non-critical scheduled workflows"
    echo "  2. Defer image builds until next billing cycle"
    echo "  3. Review workflow optimization recommendations in docs/reference/operations/GITHUB_ACTIONS_COST_MONITORING.md"
elif [ "$EXIT_CODE" -eq 1 ]; then
    echo -e "${YELLOW}⚠ Warning: Usage >= ${WARN_THRESHOLD}%${NC}"
    echo "Recommendations:"
    echo "  - Review workflow usage and identify optimization opportunities"
    echo "  - Consider enabling caching for dependencies"
    echo "  - Reduce scheduled workflow frequency"
    echo "  - See docs/reference/operations/GITHUB_ACTIONS_COST_MONITORING.md for details"
else
    echo -e "${GREEN}✓ Usage within budget${NC}"
fi

exit $EXIT_CODE
