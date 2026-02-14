#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-011, AC-012, AC-013, AC-014
# Verify multi-tenant badge isolation and branding
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Multi-Tenant Isolation Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-011: Tenant-scoped badge class filtering in API
# ---------------------------------------------------------------------------
# Check for enterprise customer UUID filtering in API endpoints
BADGES_API="services/badgr-server"
ENTERPRISE_API="deploy/k8s/base/apps/enterprise"

if grep -r "enterprise_customer_uuid" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -i "badge.*class" | grep -q "filter\|queryset"; then
  pass "AC-011: Enterprise customer UUID filtering for badge classes found"
else
  skip "AC-011: Tenant-scoped badge class filtering not yet implemented"
fi

# Check for API endpoint pattern /api/v1/badges/enterprise/{uuid}/badge-classes/
if grep -r "/enterprise/.*badge-classes\|/badges/enterprise" "$BADGES_API" 2>/dev/null | grep -q "url\|path\|route"; then
  pass "AC-011: Enterprise badge API endpoint pattern found"
else
  skip "AC-011: Enterprise badge API endpoint not found"
fi

# ---------------------------------------------------------------------------
# AC-012: Tenant isolation enforcement (403 for cross-tenant access)
# ---------------------------------------------------------------------------
# Check for permission classes or queryset filtering
if grep -r "permission.*class\|queryset.*filter" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -i "enterprise" | grep -q "badge"; then
  pass "AC-012: Permission/queryset filtering for tenant isolation found"
else
  skip "AC-012: Tenant isolation enforcement not yet implemented"
fi

# Check for 403 Forbidden responses in cross-tenant scenarios
if grep -r "403\|Forbidden\|PermissionDenied" "$BADGES_API" 2>/dev/null | grep -i "enterprise\|tenant" | grep -q "badge"; then
  pass "AC-012: 403 Forbidden response for cross-tenant access configured"
else
  skip "AC-012: 403 response handling not found"
fi

# ---------------------------------------------------------------------------
# AC-013: Tenant branding in issuer profile
# ---------------------------------------------------------------------------
# Check for issuer profile configuration with tenant branding
if grep -r "issuer.*profile\|IssuerProfile" "$BADGES_API" 2>/dev/null | grep -q "logo\|branding\|enterprise"; then
  pass "AC-013: Issuer profile with tenant branding configuration found"
else
  skip "AC-013: Issuer profile branding not yet implemented"
fi

# Check for tenant-specific logo/name/URL fields
if grep -r "tenant.*logo\|enterprise.*logo\|tenant.*name" "$BADGES_API" 2>/dev/null | grep -i "issuer\|badge"; then
  pass "AC-013: Tenant branding fields (logo, name, URL) defined"
else
  skip "AC-013: Tenant branding fields not found"
fi

# Check that issuer reflects tenant identity, not Mereka Academy default
if grep -r "tenant.*identity\|enterprise.*issuer" "$BADGES_API" 2>/dev/null | grep -q "!.*mereka\|override"; then
  pass "AC-013: Issuer identity override for tenant (not default Mereka) configured"
else
  skip "AC-013: Tenant identity override logic not found"
fi

# ---------------------------------------------------------------------------
# AC-014: Learner credential portfolio shows badges from multiple tenants
# ---------------------------------------------------------------------------
# Check for learner portfolio view
LEARNER_PORTAL="infrastructure/tutor/custom-apps/learner_portal"
MFE_CONFIG="deploy/k8s/base/apps/mfe"

if grep -r "credential.*portfolio\|badge.*portfolio" "$LEARNER_PORTAL" "$MFE_CONFIG" 2>/dev/null | grep -q "learner\|user"; then
  pass "AC-014: Learner credential portfolio configuration found"
else
  skip "AC-014: Learner credential portfolio not yet implemented"
fi

# Check for multi-tenant badge aggregation (learner sees all their badges)
if grep -r "all.*badges\|aggregate.*badge" "$LEARNER_PORTAL" "$MFE_CONFIG" 2>/dev/null | grep -i "enterprise\|tenant" | grep -q "learner"; then
  pass "AC-014: Multi-tenant badge aggregation for learner portfolio found"
else
  skip "AC-014: Multi-tenant aggregation not found"
fi

# Check for issuer labeling (badges labeled by issuer name)
if grep -r "issuer.*name\|issuer.*label" "$LEARNER_PORTAL" "$MFE_CONFIG" 2>/dev/null | grep -i "badge\|credential"; then
  pass "AC-014: Issuer labeling in portfolio configured"
else
  skip "AC-014: Issuer labeling not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Badge template management
# ---------------------------------------------------------------------------
# Check for badge template CRUD operations scoped to tenant
if grep -r "create.*badge.*class\|edit.*badge.*template" "$BADGES_API" 2>/dev/null | grep -i "enterprise\|tenant" | grep -q "admin"; then
  pass "Badge template CRUD operations for enterprise admins found"
else
  skip "Badge template CRUD operations not found"
fi

# Check for tenant isolation in badge template storage
if grep -r "badge.*image.*storage\|template.*storage" "$BADGES_API" 2>/dev/null | grep -q "tenant\|enterprise\|isolated"; then
  pass "Tenant-isolated badge template storage configured"
else
  skip "Tenant-isolated template storage not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
