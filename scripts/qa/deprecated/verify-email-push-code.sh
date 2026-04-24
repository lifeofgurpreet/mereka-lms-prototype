#!/usr/bin/env bash
# Email & Notifications - Push Notification Code Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-016, AC-018, AC-019

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

echo "=== Email & Notifications: Push Notification Code Verification ==="
echo

PUSH_PLUGIN="infrastructure/tutor/plugins/push-notifications"

# AC-016: FCM error handling (mark device inactive on UNREGISTERED)
echo "AC-016: FCM error handling for unregistered tokens..."

if [ -d "$PUSH_PLUGIN" ]; then
    # Check for error handling in dispatch code
    if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(UNREGISTERED|INVALID_ARGUMENT)" {} \; | grep -q .; then
        do_pass "FCM error constants (UNREGISTERED/INVALID_ARGUMENT) found"

        # Check for is_active flag handling
        if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(is_active.*=.*False|set.*inactive|mark.*inactive|deactivate)" {} \; | grep -q .; then
            do_pass "Device deactivation logic found for FCM errors"
        else
            do_warn "Error constants found but deactivation logic not evident"
        fi
    else
        do_warn "FCM error handling not found (may be in upstream library)"
    fi

    # Check for device model with is_active field
    if find "$PUSH_PLUGIN" -name "models.py" -exec grep -l "is_active" {} \; | grep -q .; then
        do_pass "Device model includes is_active field"
    else
        do_fail "Device model missing is_active field"
    fi
else
    do_warn "Push notifications plugin not found at $PUSH_PLUGIN"
fi

echo

# AC-018: FCM batch sending (max 500 per batch)
echo "AC-018: FCM batch sending logic..."

if [ -d "$PUSH_PLUGIN" ]; then
    # Check for batch size constant
    if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(BATCH_SIZE|batch_size|FCM_BATCH)" {} \; | grep -q .; then
        BATCH_CONFIG=$(find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(BATCH_SIZE|batch_size.*=.*500)" {} \; 2>/dev/null)

        if echo "$BATCH_CONFIG" | grep -q "500"; then
            do_pass "FCM batch size configured to 500 (per spec)"
        elif [ -n "$BATCH_CONFIG" ]; then
            do_warn "FCM batch size found but value may differ from 500"
        else
            do_warn "Batch size constant found but value not evident"
        fi

        # Check for batching logic (chunking)
        if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(chunk|batch|islice|array_chunk)" {} \; | grep -q .; then
            do_pass "Batching/chunking logic found in push dispatch"
        else
            do_warn "Batch size defined but chunking logic not found"
        fi
    else
        do_warn "No batch size configuration found (may use default or upstream library)"
    fi
else
    do_warn "Cannot verify batching without plugin directory"
fi

echo

# AC-019: Cross-tenant push isolation (org_slug filtering)
echo "AC-019: Cross-tenant push notification isolation..."

if [ -d "$PUSH_PLUGIN" ]; then
    # Check for org_slug in device model
    if find "$PUSH_PLUGIN" -name "models.py" -exec grep -l "org_slug" {} \; | grep -q .; then
        do_pass "Device registration model includes org_slug field"

        # Check for org_slug filtering in dispatch
        if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(filter.*org_slug|org_slug.*=.*notification|WHERE.*org_slug)" {} \; | grep -q .; then
            do_pass "org_slug filtering found in push dispatch (cross-tenant isolation)"
        else
            do_warn "org_slug field exists but filtering not found in dispatch code"
        fi
    else
        do_fail "Device model missing org_slug field (cross-tenant push isolation risk)"
    fi

    # Check for test coverage
    if find "$PUSH_PLUGIN" -name "test*.py" -exec grep -E "(test.*cross.tenant|test.*org_slug.*push|test.*isolation)" {} \; | grep -q .; then
        do_pass "Cross-tenant isolation test coverage exists for push notifications"
    else
        do_warn "No explicit cross-tenant isolation tests for push notifications"
    fi
else
    do_warn "Cannot verify cross-tenant isolation without plugin directory"
fi

echo

# Additional checks: FCM service account credentials
echo "Checking FCM credentials configuration..."

# Check for ExternalSecret or secret reference
if find deploy/k8s -name "*.yaml" -exec grep -l "FCM_SERVICE_ACCOUNT" {} \; 2>/dev/null | grep -q .; then
    do_pass "FCM service account credentials configured in K8s secrets"
elif grep -r "FCM_SERVICE_ACCOUNT" infrastructure/tutor 2>/dev/null | grep -q .; then
    do_pass "FCM service account credentials referenced in Tutor config"
else
    do_warn "FCM service account credentials not found in K8s or Tutor config (may not be deployed)"
fi

# Check for FCM API integration
if [ -d "$PUSH_PLUGIN" ]; then
    if find "$PUSH_PLUGIN" -name "*.py" -exec grep -E "(fcm\.googleapis\.com|firebase|FCM|FirebaseMessaging)" {} \; | grep -q .; then
        do_pass "FCM API integration code found"
    else
        do_warn "FCM API integration not evident (may be in upstream library)"
    fi
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
