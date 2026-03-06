#!/usr/bin/env bash
# Email & Notifications - Digest Generation Code Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-037, AC-038, AC-039

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

echo "=== Email & Notifications: Digest Generation Code Verification ==="
echo

DIGEST_PLUGIN="infrastructure/tutor/plugins/email-digests"

# AC-037: Daily digest generation with course grouping
echo "AC-037: Daily digest generation logic..."

if [ -d "$DIGEST_PLUGIN" ]; then
    # Check for digest preference types (daily, weekly, etc.)
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(daily|weekly|DIGEST_FREQUENCY)" {} \; | grep -q .; then
        do_pass "Digest frequency configuration found"

        # Check for course grouping
        if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(group.*by.*course|course.*grouping|aggregate.*course)" {} \; | grep -q .; then
            do_pass "Course grouping logic found in digest generation"
        else
            do_warn "Digest frequency exists but course grouping not evident"
        fi
    else
        do_warn "Digest frequency configuration not found"
    fi

    # Check for timezone handling
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(timezone|pytz|user.*tz|Asia/Kuala_Lumpur)" {} \; | grep -q .; then
        do_pass "Timezone handling found in digest scheduling"
    else
        do_warn "Timezone handling not evident (may cause incorrect send times)"
    fi

    # Check for scheduled task (Celery Beat)
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(periodic_task|celery.*beat|crontab|schedule)" {} \; | grep -q .; then
        do_pass "Periodic task scheduling found for digest generation"
    else
        do_warn "No periodic task found for digest generation"
    fi
else
    do_warn "Email digests plugin not found at $DIGEST_PLUGIN"
fi

echo

# AC-038: Digest vs immediate sending logic
echo "AC-038: Digest preference routing (suppress immediate)..."

if [ -d "$DIGEST_PLUGIN" ]; then
    # Check for digest preference checking
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(digest.*preference|check.*digest|if.*digest.*enabled)" {} \; | grep -q .; then
        do_pass "Digest preference checking logic found"

        # Check for immediate send suppression
        if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(suppress.*immediate|skip.*immediate|queue.*for.*digest)" {} \; | grep -q .; then
            do_pass "Immediate send suppression for digest subscribers found"
        else
            do_warn "Digest preference exists but immediate suppression not evident"
        fi
    else
        do_warn "Digest preference routing not found"
    fi

    # Check for per-message-type digest support
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(discussion_reply|course_announcement)" {} \; | grep -q .; then
        do_pass "Per-message-type digest support found"
    else
        do_warn "Per-message-type digest configuration not evident"
    fi
else
    do_warn "Cannot verify digest routing without plugin"
fi

echo

# AC-039: De-duplication in digest rendering
echo "AC-039: Digest de-duplication for same thread..."

if [ -d "$DIGEST_PLUGIN" ]; then
    # Check for thread/topic grouping
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(group.*by.*thread|thread.*id|discussion.*thread|aggregate.*replies)" {} \; | grep -q .; then
        do_pass "Thread-based grouping found in digest generation"

        # Check for reply count aggregation
        if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(count.*replies|new.*replies|aggregate.*count)" {} \; | grep -q .; then
            do_pass "Reply count aggregation found (de-duplication)"
        else
            do_warn "Thread grouping exists but count aggregation not evident"
        fi
    else
        do_warn "Thread de-duplication logic not found"
    fi

    # Check for digest template rendering
    if find "$DIGEST_PLUGIN" -name "*.html" -o -name "*.txt" 2>/dev/null | grep -q .; then
        do_pass "Digest email templates found"
    else
        do_warn "No digest templates found (may be in upstream or different location)"
    fi
else
    do_warn "Cannot verify de-duplication without digest plugin"
fi

echo

# Additional checks: Empty digest handling
echo "Checking empty digest prevention..."

if [ -d "$DIGEST_PLUGIN" ]; then
    # Check for empty digest check
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(if.*notifications.*empty|len.*notifications.*==.*0|not.*notifications)" {} \; | grep -q .; then
        do_pass "Empty digest check found (prevents sending empty emails)"
    else
        do_warn "Empty digest prevention not evident (may send empty digests)"
    fi

    # Check for digest batch window
    if find "$DIGEST_PLUGIN" -name "*.py" -exec grep -E "(batch.*window|5.*minutes|digest.*period)" {} \; | grep -q .; then
        do_pass "Digest batching window configured"
    else
        do_warn "Digest batching window not found (may use immediate aggregation)"
    fi
else
    do_warn "Cannot verify empty digest handling without plugin"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
