#!/usr/bin/env bash
# @covers AC-SUPRT-001, AC-SUPRT-002
# @spec: analytics-pipeline_spec.md

set -euo pipefail

RUNBOOK_PATH="docs/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md"
PASS=0
FAIL=0

echo "=== Superset Deployment Runbook Verification ==="
echo ""

# AC-SUPRT-002: Runbook exists
if [[ -f "$RUNBOOK_PATH" ]]; then
    echo "✓ PASS: Runbook exists at $RUNBOOK_PATH"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Runbook not found at $RUNBOOK_PATH"
    FAIL=$((FAIL + 1))
    exit 1
fi

# AC-SUPRT-001: Required sections exist

# 1. Authentication Integration
if grep -q "^## Authentication Integration" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Authentication Integration section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Authentication Integration section missing"
    FAIL=$((FAIL + 1))
fi

# Check for OAuth2 subsection
if grep -q "OAuth2 via Open edX LMS" "$RUNBOOK_PATH"; then
    echo "✓ PASS: OAuth2 integration documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: OAuth2 integration not documented"
    FAIL=$((FAIL + 1))
fi

# 2. Dashboard Templates
if grep -q "^## Dashboard Templates" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Dashboard Templates section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Dashboard Templates section missing"
    FAIL=$((FAIL + 1))
fi

# Check for pre-built dashboards
DASHBOARD_COUNT=$(grep -c "^#### [0-9]\. .* Dashboard" "$RUNBOOK_PATH" || true)
if [[ "$DASHBOARD_COUNT" -ge 3 ]]; then
    echo "✓ PASS: At least 3 pre-built dashboards documented ($DASHBOARD_COUNT found)"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Expected at least 3 pre-built dashboards, found $DASHBOARD_COUNT"
    FAIL=$((FAIL + 1))
fi

# 3. Access Control
if grep -q "^## Access Control" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Access Control section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Access Control section missing"
    FAIL=$((FAIL + 1))
fi

# Check for RBAC
if grep -q "Role-Based Access Control" "$RUNBOOK_PATH"; then
    echo "✓ PASS: RBAC documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: RBAC not documented"
    FAIL=$((FAIL + 1))
fi

# Check for row-level security
if grep -q -i "row-level security\|row level security" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Row-level security documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Row-level security not documented"
    FAIL=$((FAIL + 1))
fi

# 4. Dashboard Embedding
if grep -q "^## Dashboard Embedding" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Dashboard Embedding section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Dashboard Embedding section missing"
    FAIL=$((FAIL + 1))
fi

# Check for embedding methods
if grep -q "Embedded SDK\|embedded-sdk" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Superset Embedded SDK documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Superset Embedded SDK not documented"
    FAIL=$((FAIL + 1))
fi

if grep -q "iframe\|Iframe" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Iframe embedding method documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Iframe embedding method not documented"
    FAIL=$((FAIL + 1))
fi

# 5. Data Sources
if grep -q "^## Data Sources" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Data Sources section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Data Sources section missing"
    FAIL=$((FAIL + 1))
fi

# Check for ClickHouse connection
if grep -q "ClickHouse" "$RUNBOOK_PATH"; then
    echo "✓ PASS: ClickHouse connection documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: ClickHouse connection not documented"
    FAIL=$((FAIL + 1))
fi

# Check for xAPI schema
if grep -q "xAPI\|xapi" "$RUNBOOK_PATH"; then
    echo "✓ PASS: xAPI event schema documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: xAPI event schema not documented"
    FAIL=$((FAIL + 1))
fi

# 6. Operational Procedures
if grep -q "^## Operational Procedures" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Operational Procedures section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Operational Procedures section missing"
    FAIL=$((FAIL + 1))
fi

# Check for common operational tasks
TASK_COUNT=0

if grep -q "Add New Dashboard\|Add.*Dashboard" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Add dashboard procedure documented"
    PASS=$((PASS + 1))
    TASK_COUNT=$((TASK_COUNT + 1))
else
    echo "✗ FAIL: Add dashboard procedure missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "Refresh Data\|Clear Cache" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Refresh data procedure documented"
    PASS=$((PASS + 1))
    TASK_COUNT=$((TASK_COUNT + 1))
else
    echo "✗ FAIL: Refresh data procedure missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "Fix Broken Queries" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Fix broken queries procedure documented"
    PASS=$((PASS + 1))
    TASK_COUNT=$((TASK_COUNT + 1))
else
    echo "✗ FAIL: Fix broken queries procedure missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "Backup\|backup" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Backup procedure documented"
    PASS=$((PASS + 1))
    TASK_COUNT=$((TASK_COUNT + 1))
else
    echo "✗ FAIL: Backup procedure missing"
    FAIL=$((FAIL + 1))
fi

# 7. Check for ADR-017 reference (deferral context)
if grep -q "ADR-017" "$RUNBOOK_PATH"; then
    echo "✓ PASS: ADR-017 referenced (deferral context)"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: ADR-017 reference missing (deferral context should be documented)"
    FAIL=$((FAIL + 1))
fi

# 8. Check for deployment gate notice
if grep -q "DEFERRED\|Deferred\|deferral" "$RUNBOOK_PATH"; then
    echo "✓ PASS: Deferral status documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Deferral status not clearly documented"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
    echo "✓ All Superset runbook checks passed"
    exit 0
else
    echo "✗ Some Superset runbook checks failed"
    exit 1
fi
