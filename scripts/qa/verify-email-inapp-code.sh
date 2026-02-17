#!/usr/bin/env bash
# Email & Notifications - In-App Notifications Code Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-012, AC-014

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

do_pass() { echo "✓ $1"; ((PASS_COUNT++)); }
do_fail() { echo "✗ $1"; ((FAIL_COUNT++)); }
do_warn() { echo "⚠ $1"; ((WARN_COUNT++)); }

cd "$REPO_ROOT" || exit 1

echo "=== Email & Notifications: In-App Code Verification ==="
echo

# AC-012: Expired notification filtering
echo "AC-012: Expired notification filtering logic..."

INAPP_PLUGIN="infrastructure/tutor/plugins/notifications-inapp"

if [ -d "$INAPP_PLUGIN" ]; then
    # Check for expires_at field in model
    if find "$INAPP_PLUGIN" -name "*.py" -exec grep -l "expires_at" {} \; | grep -q .; then
        do_pass "Notification model includes expires_at field"

        # Check for expiration filtering in views/queries
        if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(expires_at.*<.*now|now.*>.*expires_at|exclude.*expires_at|filter.*expires_at.*gte)" {} \; | grep -q .; then
            do_pass "Expiration filtering logic found in queries"
        else
            do_warn "expires_at field exists but filtering logic not found in views"
        fi
    else
        do_fail "Notification model missing expires_at field"
    fi

    # Check for purge task (Celery periodic task)
    if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(periodic_task|celery.*task)" {} \; | grep -q .; then
        if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(purge.*expired|delete.*expires_at|remove.*old.*notification)" {} \; | grep -q .; then
            do_pass "Periodic purge task for expired notifications found"
        else
            do_warn "Celery tasks found but purge logic not evident"
        fi
    else
        do_warn "No periodic task found for purging expired notifications (may be manual)"
    fi
else
    do_warn "In-app notifications plugin not found at $INAPP_PLUGIN"
fi

echo

# AC-014: Cross-tenant isolation in notification queries
echo "AC-014: Cross-tenant isolation (org_slug filtering)..."

if [ -d "$INAPP_PLUGIN" ]; then
    # Check for org_slug field in model
    if find "$INAPP_PLUGIN" -name "*.py" -exec grep -l "org_slug" {} \; | grep -q .; then
        do_pass "Notification model includes org_slug field"

        # Check for org_slug filtering in views
        ISOLATION_CHECKS=0

        if find "$INAPP_PLUGIN" -name "views.py" -exec grep -E "(filter.*org_slug|org_slug.*=.*request)" {} \; | grep -q .; then
            do_pass "org_slug filtering found in views (cross-tenant isolation)"
            ((ISOLATION_CHECKS++))
        fi

        # Check for org_slug in query filters
        if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(queryset.*filter.*org_slug|\.objects\.filter.*org_slug)" {} \; | grep -q .; then
            do_pass "org_slug used in queryset filters"
            ((ISOLATION_CHECKS++))
        fi

        if [ "$ISOLATION_CHECKS" -eq 0 ]; then
            do_warn "org_slug field exists but filtering not found in views (may be in middleware)"
        fi
    else
        do_fail "Notification model missing org_slug field (cross-tenant isolation risk)"
    fi

    # Check for test coverage of cross-tenant isolation
    if find "$INAPP_PLUGIN" -name "test*.py" -exec grep -E "(test.*cross.tenant|test.*org_slug.*leak|test.*isolation)" {} \; | grep -q .; then
        do_pass "Cross-tenant isolation test coverage exists"
    else
        do_warn "No explicit cross-tenant isolation tests found"
    fi
else
    do_warn "In-app notifications plugin not found for isolation checks"
fi

echo

# Additional checks: API endpoints
echo "Checking in-app notification API endpoints..."

if [ -d "$INAPP_PLUGIN" ]; then
    # Check for REST API views
    if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(class.*ViewSet|class.*APIView|@api_view)" {} \; | grep -q .; then
        do_pass "REST API views found for in-app notifications"

        # Check for pagination
        if find "$INAPP_PLUGIN" -name "*.py" -exec grep -E "(pagination_class|PageNumberPagination|CursorPagination)" {} \; | grep -q .; then
            do_pass "Pagination configured for notification list API"
        else
            do_warn "Pagination not evident in API views (performance concern)"
        fi
    else
        do_warn "No REST API views found (may be in upstream or different location)"
    fi
else
    do_warn "Cannot verify API endpoints without plugin directory"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
