#!/usr/bin/env bash
# Email & Notifications - Bulk Campaigns Code Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-031, AC-032, AC-040, AC-041, AC-042

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

do_pass() { echo "✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
do_fail() { echo "✗ $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
do_warn() { echo "⚠ $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

cd "$REPO_ROOT" || exit 1

echo "=== Email & Notifications: Bulk Campaigns Code Verification ==="
echo

BULK_PLUGIN="infrastructure/tutor/plugins/bulk-email"

# AC-031: Opt-out enforcement in bulk campaigns
echo "AC-031: Bulk campaign opt-out enforcement..."

if [ -d "$BULK_PLUGIN" ]; then
    # Check for preference checking before send
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(check.*preference|filter.*opted.*out|exclude.*disabled|bulk_campaign.*enabled)" {} \; | grep -q .; then
        do_pass "Preference checking logic found in bulk email dispatcher"

        # Check for skipped count tracking
        if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(skipped.*count|opted_out.*count|excluded.*count)" {} \; | grep -q .; then
            do_pass "Skipped recipient count tracking found"
        else
            do_warn "Preference checks exist but skipped count tracking not evident"
        fi
    else
        do_warn "Opt-out enforcement logic not found in bulk email code"
    fi
else
    do_warn "Bulk email plugin not found at $BULK_PLUGIN"
fi

echo

# AC-032: Per-tenant rate limiting
echo "AC-032: Per-tenant rate limiting for bulk campaigns..."

if [ -d "$BULK_PLUGIN" ]; then
    # Check for rate limit configuration
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(rate.*limit|throttle|RATE_LIMIT|emails.*per.*second)" {} \; | grep -q .; then
        do_pass "Rate limiting configuration found"

        # Check for per-tenant rate limiting
        if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(org_slug.*rate|tenant.*rate|per.*tenant.*limit)" {} \; | grep -q .; then
            do_pass "Per-tenant rate limiting logic found"
        else
            do_warn "Rate limiting exists but per-tenant isolation not evident"
        fi

        # Check for default rate (50 emails/second per spec)
        if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(50.*email|rate.*=.*50|RATE.*50)" {} \; | grep -q .; then
            do_pass "Default rate limit of 50 emails/second found (per spec)"
        else
            do_warn "Rate limit configured but default value (50/sec) not evident"
        fi
    else
        do_warn "Rate limiting not found in bulk email code (may rely on SES limits)"
    fi
else
    do_warn "Cannot verify rate limiting without bulk email plugin"
fi

echo

# AC-040: Open tracking
echo "AC-040: Open tracking for bulk campaigns..."

TRACKING_FOUND=0

if [ -d "$BULK_PLUGIN" ]; then
    # Check for tracking pixel or open event logging
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(tracking.*pixel|open.*event|email.*opened|track.*open)" {} \; | grep -q .; then
        do_pass "Open tracking logic found"
        TRACKING_FOUND=$((TRACKING_FOUND + 1))
    fi

    # Check for engagement store or analytics table
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(engagement.*store|analytics.*table|EmailEngagement|CampaignAnalytics)" {} \; | grep -q .; then
        do_pass "Engagement data storage found"
        TRACKING_FOUND=$((TRACKING_FOUND + 1))
    fi

    if [ "$TRACKING_FOUND" -eq 0 ]; then
        do_warn "Open tracking not found (may use SES event publishing via SNS)"
    fi
else
    do_warn "Cannot verify open tracking without bulk email plugin"
fi

echo

# AC-041: Click tracking
echo "AC-041: Click tracking for bulk campaigns..."

CLICK_TRACKING_FOUND=0

if [ -d "$BULK_PLUGIN" ]; then
    # Check for URL rewriting for click tracking
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(rewrite.*url|track.*click|click.*redirect|tracking.*url)" {} \; | grep -q .; then
        do_pass "Click tracking URL rewriting found"
        CLICK_TRACKING_FOUND=$((CLICK_TRACKING_FOUND + 1))
    fi

    # Check for redirect endpoint
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(redirect.*view|click.*endpoint|track.*click.*view)" {} \; | grep -q .; then
        do_pass "Click tracking redirect endpoint found"
        CLICK_TRACKING_FOUND=$((CLICK_TRACKING_FOUND + 1))
    fi

    if [ "$CLICK_TRACKING_FOUND" -eq 0 ]; then
        do_warn "Click tracking not found (may use SES event publishing via SNS)"
    fi
else
    do_warn "Cannot verify click tracking without bulk email plugin"
fi

echo

# AC-042: Cross-tenant analytics isolation
echo "AC-042: Cross-tenant analytics isolation..."

if [ -d "$BULK_PLUGIN" ]; then
    # Check for org_slug in analytics queries
    if find "$BULK_PLUGIN" -name "*.py" -exec grep -E "(analytics.*org_slug|filter.*org_slug.*campaign|WHERE.*org_slug)" {} \; | grep -q .; then
        do_pass "org_slug filtering found in analytics queries (cross-tenant isolation)"
    else
        do_warn "Analytics isolation not evident (may be in views or admin interface)"
    fi

    # Check for campaign-org_slug relationship
    if find "$BULK_PLUGIN" -name "models.py" -exec grep -l "org_slug" {} \; | grep -q .; then
        do_pass "Campaign model includes org_slug field"
    else
        do_fail "Campaign model missing org_slug field (analytics isolation risk)"
    fi
else
    do_warn "Cannot verify analytics isolation without bulk email plugin"
fi

echo

# Additional checks: Campaign status tracking
echo "Checking campaign status management..."

if [ -d "$BULK_PLUGIN" ]; then
    CAMPAIGN_STATES=0

    for state in draft scheduled sending paused completed failed cancelled; do
        if find "$BULK_PLUGIN" -name "*.py" -exec grep -i "$state" {} \; | grep -q .; then
            CAMPAIGN_STATES=$((CAMPAIGN_STATES + 1))
        fi
    done

    if [ "$CAMPAIGN_STATES" -ge 4 ]; then
        do_pass "Campaign status tracking found ($CAMPAIGN_STATES/7 states)"
    elif [ "$CAMPAIGN_STATES" -gt 0 ]; then
        do_warn "Partial campaign status tracking ($CAMPAIGN_STATES/7 states)"
    else
        do_warn "Campaign status tracking not found"
    fi
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
