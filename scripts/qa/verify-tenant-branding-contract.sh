#!/usr/bin/env bash
# @covers AC-TBR-003
# Machine-checkable verifier for tenant branding contract compliance.
#
# Validates that required documentation, files, and keys exist to support
# multi-tenant branding activation without drift.
#
# Usage:
#   ./scripts/qa/verify-tenant-branding-contract.sh
#   ./scripts/qa/verify-tenant-branding-contract.sh --strict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
STRICT_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT_MODE=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Tenant Branding Contract Verification ===${NC}"
echo ""

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAIL_COUNT++)) || true
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
  if [[ $STRICT_MODE -eq 1 ]]; then
    fail "$1 (strict mode)"
    ((WARN_COUNT--)) || true
  fi
}

# ============================================================================
# Documentation Checks
# ============================================================================

echo -e "${BLUE}## Documentation Checks${NC}"

# AC-TBR-001: RAG matrix exists
if [[ -f "docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md" ]]; then
  pass "RAG matrix exists (docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md)"
else
  fail "RAG matrix missing (docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md)"
fi

# AC-TBR-002: Contract doc exists
if [[ -f "docs/guides/branding/TENANT_BRANDING_CONTRACT.md" ]]; then
  pass "Contract doc exists (docs/guides/branding/TENANT_BRANDING_CONTRACT.md)"
else
  fail "Contract doc missing (docs/guides/branding/TENANT_BRANDING_CONTRACT.md)"
fi

# Tenant provisioning guide exists
if [[ -f "docs/runbooks/operations/TENANT_PROVISIONING.md" ]]; then
  pass "Tenant provisioning guide exists"
else
  fail "Tenant provisioning guide missing (docs/runbooks/operations/TENANT_PROVISIONING.md)"
fi

# Multi-tenancy architecture overview exists
if [[ -f "docs/concepts/architecture/multi-tenancy-overview.md" ]]; then
  pass "Multi-tenancy architecture doc exists"
else
  fail "Multi-tenancy architecture doc missing (docs/concepts/architecture/multi-tenancy-overview.md)"
fi

echo ""

# ============================================================================
# Architecture Checks (AC-TBR-001: Architecture readiness evidence)
# ============================================================================

echo -e "${BLUE}## Architecture Checks${NC}"

# openedx_tenant_cache custom app exists
if [[ -d "infrastructure/tutor/custom-apps/openedx_tenant_cache" ]]; then
  pass "openedx_tenant_cache custom app exists"
else
  fail "openedx_tenant_cache custom app missing"
fi

# TenantSiteMapping model exists
if grep -q "class TenantSiteMapping" infrastructure/tutor/custom-apps/openedx_tenant_cache/models.py 2>/dev/null; then
  pass "TenantSiteMapping model defined"
else
  fail "TenantSiteMapping model missing"
fi

# TenantSiteConfiguration model exists
if grep -q "class TenantSiteConfiguration" infrastructure/tutor/custom-apps/openedx_tenant_cache/models.py 2>/dev/null; then
  pass "TenantSiteConfiguration model defined"
else
  fail "TenantSiteConfiguration model missing"
fi

# TenantResolutionMiddleware exists
if grep -q "class TenantResolutionMiddleware" infrastructure/tutor/plugins/multi-tenancy/middleware.py 2>/dev/null || \
   grep -q "class TenantResolutionMiddleware" infrastructure/tutor/custom-apps/mereka_tenancy/middleware.py 2>/dev/null; then
  pass "TenantResolutionMiddleware exists"
else
  fail "TenantResolutionMiddleware missing"
fi

# inject_mfe_branding function exists
if grep -q "def inject_mfe_branding" infrastructure/tutor/custom-apps/openedx_tenant_cache/branding.py 2>/dev/null; then
  pass "inject_mfe_branding() function exists"
else
  fail "inject_mfe_branding() function missing"
fi

# provision_tenant management command exists
if [[ -f "infrastructure/tutor/custom-apps/openedx_tenant_cache/management/commands/provision_tenant.py" ]]; then
  pass "provision_tenant management command exists"
else
  fail "provision_tenant management command missing"
fi

# apply_tenant_branding management command exists
if [[ -f "infrastructure/tutor/custom-apps/openedx_tenant_cache/management/commands/apply_tenant_branding.py" ]]; then
  pass "apply_tenant_branding management command exists"
else
  fail "apply_tenant_branding management command missing"
fi

echo ""

# ============================================================================
# Theme Directory Structure (AC-TBR-002: Brand pack structure)
# ============================================================================

echo -e "${BLUE}## Theme Directory Structure${NC}"

# Tenant theme root exists
if [[ -d "infrastructure/tutor/themes/mereka/tenants" ]]; then
  pass "Tenant theme directory exists (themes/mereka/tenants)"
else
  fail "Tenant theme directory missing (infrastructure/tutor/themes/mereka/tenants)"
fi

# README in tenants dir explains structure
if [[ -f "infrastructure/tutor/themes/mereka/tenants/README.md" ]]; then
  pass "Tenant directory README exists"
else
  warn "Tenant directory README missing (helps ops understand structure)"
fi

# Check if any tenants are provisioned
TENANT_COUNT=$(find infrastructure/tutor/themes/mereka/tenants -mindepth 1 -maxdepth 1 -type d ! -name README.md 2>/dev/null | wc -l)
if [[ $TENANT_COUNT -gt 0 ]]; then
  pass "Tenant directories exist ($TENANT_COUNT tenants provisioned)"
else
  warn "No tenant directories found (expected after first tenant provisioning)"
fi

echo ""

# ============================================================================
# Provisioning Scripts (AC-TBR-005: Handoff workflow)
# ============================================================================

echo -e "${BLUE}## Provisioning Scripts${NC}"

# provision-tenant.sh wrapper exists
if [[ -f "scripts/tenants/provision-tenant.sh" ]]; then
  pass "Tenant provisioning wrapper script exists"

  # Script is executable
  if [[ -x "scripts/tenants/provision-tenant.sh" ]]; then
    pass "Tenant provisioning script is executable"
  else
    fail "Tenant provisioning script is not executable (chmod +x needed)"
  fi
else
  fail "Tenant provisioning wrapper script missing (scripts/tenants/provision-tenant.sh)"
fi

# mereka-tenant.env example exists
if [[ -f "scripts/tenants/mereka-tenant.env" ]]; then
  pass "Mereka tenant .env example exists"
else
  warn "Mereka tenant .env example missing (scripts/tenants/mereka-tenant.env)"
fi

echo ""

# ============================================================================
# Verification Scripts (AC-TBR-003: Verification coverage)
# ============================================================================

echo -e "${BLUE}## Verification Scripts${NC}"

# Core tenant verifiers exist
VERIFIERS=(
  "scripts/qa/verify-tenant-model.sh"
  "scripts/qa/verify-tenant-middleware.sh"
  "scripts/qa/verify-tenant-configmap.sh"
  "scripts/qa/verify-tenant-provisioning.sh"
  "scripts/qa/verify-tenant-isolation-patterns.sh"
  "scripts/qa/verify-tenant-branding.sh"
)

for verifier in "${VERIFIERS[@]}"; do
  if [[ -f "$verifier" ]]; then
    pass "$(basename "$verifier") exists"
  else
    warn "$verifier missing (recommended for comprehensive verification)"
  fi
done

# Branding gate suite exists
if [[ -f "scripts/branding/run-branding-gates.sh" ]]; then
  pass "Branding gate suite exists (run-branding-gates.sh)"
else
  fail "Branding gate suite missing (scripts/branding/run-branding-gates.sh)"
fi

echo ""

# ============================================================================
# K8s Configuration (AC-TBR-001: K8s deployment readiness)
# ============================================================================

echo -e "${BLUE}## K8s Configuration${NC}"

# Tenant registry ConfigMap exists
if [[ -f "deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml" ]]; then
  pass "Tenant registry ConfigMap exists"
else
  fail "Tenant registry ConfigMap missing (deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml)"
fi

# Multi-tenancy Kustomization exists
if [[ -f "deploy/k8s/base/apps/multi-tenancy/kustomization.yaml" ]]; then
  pass "Multi-tenancy Kustomization exists"
else
  fail "Multi-tenancy Kustomization missing (deploy/k8s/base/apps/multi-tenancy/kustomization.yaml)"
fi

echo ""

# ============================================================================
# Contract Compliance (AC-TBR-002: Required inputs defined)
# ============================================================================

echo -e "${BLUE}## Contract Compliance Checks${NC}"

# Contract doc defines required inputs
if grep -q "## Required Inputs Per Tenant" docs/guides/branding/TENANT_BRANDING_CONTRACT.md 2>/dev/null; then
  pass "Contract defines required inputs per tenant"
else
  fail "Contract missing required inputs section"
fi

# Contract defines fallback rules
if grep -q "## Fallback Rules" docs/guides/branding/TENANT_BRANDING_CONTRACT.md 2>/dev/null; then
  pass "Contract defines fallback rules"
else
  fail "Contract missing fallback rules section"
fi

# Contract defines ownership boundaries
if grep -q "## Ownership Boundaries" docs/guides/branding/TENANT_BRANDING_CONTRACT.md 2>/dev/null; then
  pass "Contract defines ownership boundaries"
else
  fail "Contract missing ownership boundaries section"
fi

# Contract defines zero-downtime workflow (AC-TBR-005)
if grep -q "## Zero-Downtime Brand Pack Workflow" docs/guides/branding/TENANT_BRANDING_CONTRACT.md 2>/dev/null; then
  pass "Contract defines zero-downtime brand pack workflow"
else
  fail "Contract missing zero-downtime workflow (AC-TBR-005)"
fi

echo ""

# ============================================================================
# RAG Matrix Compliance (AC-TBR-001: RAG scoring present)
# ============================================================================

echo -e "${BLUE}## RAG Matrix Compliance${NC}"

# RAG matrix has 5 dimensions
DIMENSIONS=(
  "Architecture Readiness"
  "Runtime Activation Readiness"
  "Verification Coverage"
  "Operator Workflow"
  "Scale Readiness"
)

for dimension in "${DIMENSIONS[@]}"; do
  if grep -q "$dimension" docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md 2>/dev/null; then
    pass "RAG matrix includes dimension: $dimension"
  else
    fail "RAG matrix missing dimension: $dimension"
  fi
done

# RAG matrix includes evidence links
if grep -q "Evidence" docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md 2>/dev/null; then
  pass "RAG matrix includes evidence links"
else
  fail "RAG matrix missing evidence section"
fi

# RAG matrix includes gaps
if grep -q "Gaps" docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md 2>/dev/null; then
  pass "RAG matrix includes gap analysis"
else
  fail "RAG matrix missing gap section"
fi

# RAG matrix includes action items
if grep -q "Action to Reach GREEN" docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md 2>/dev/null; then
  pass "RAG matrix includes action items for GREEN status"
else
  fail "RAG matrix missing action items"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
  echo -e "${GREEN}✅ All checks passed${NC}"
  exit 0
elif [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  All required checks passed, but some warnings exist${NC}"
  if [[ $STRICT_MODE -eq 1 ]]; then
    echo -e "${RED}❌ Strict mode enabled: warnings treated as failures${NC}"
    exit 1
  fi
  exit 0
else
  echo -e "${RED}❌ Some checks failed${NC}"
  exit 1
fi
