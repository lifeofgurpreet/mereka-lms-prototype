#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
#
# Provision all 3 tenants for Mereka LMS multi-tenancy architecture.
#
# Provisions:
#   1. MEREKA tenant (academyv2.mereka.io)
#   2. BIJIBIJI tenant (academy.biji-biji.com)
#   3. SKILLOURFUTURE tenant (skillourfuture.academy.mereka.io)
#
# Usage:
#   ./scripts/tenants/provision-all-tenants.sh [--dry-run] [--skip-existing]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROVISION_SCRIPT="${REPO_ROOT}/scripts/tenants/provision-tenant.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
DRY_RUN=0
SKIP_EXISTING=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-existing) SKIP_EXISTING=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Verify provision script exists
if [[ ! -x "$PROVISION_SCRIPT" ]]; then
  echo -e "${RED}✗${NC} provision-tenant.sh not found or not executable at $PROVISION_SCRIPT"
  exit 1
fi

echo -e "${BLUE}=== Provisioning All Tenants for Mereka LMS ===${NC}"
echo ""
echo "This will provision 3 tenants:"
echo "  1. MEREKA (academyv2.mereka.io)"
echo "  2. BIJIBIJI (academy.biji-biji.com)"
echo "  3. SKILLOURFUTURE (skillourfuture.academy.mereka.io)"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}[DRY RUN MODE]${NC} No changes will be made"
  echo ""
fi

# Track results
PROVISIONED=0
SKIPPED=0
FAILED=0

# Tenant definitions
declare -A TENANTS
TENANTS[mereka]="Mereka Academy|academyv2.mereka.io|team@mereka.io|MY"
TENANTS[bijibiji]="Biji-Biji Initiative|academy.biji-biji.com|admin@biji-biji.com|MY"
TENANTS[skillourfuture]="Skill Our Future|skillourfuture.academy.mereka.io|admin@mereka.io|MY"

# Provision each tenant
for slug in mereka bijibiji skillourfuture; do
  IFS='|' read -r name domain email country <<< "${TENANTS[$slug]}"

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Tenant: ${slug} (${name})${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Build provision command
  CMD="$PROVISION_SCRIPT --slug $slug --name \"$name\" --domain $domain --contact-email $email --country $country"

  if [[ $DRY_RUN -eq 1 ]]; then
    CMD="$CMD --dry-run"
  fi

  # Run provision
  if eval "$CMD"; then
    echo -e "${GREEN}✓${NC} Tenant ${slug} provisioned successfully"
    PROVISIONED=$((PROVISIONED + 1))
  else
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 2 ]] && [[ $SKIP_EXISTING -eq 1 ]]; then
      echo -e "${YELLOW}⊘${NC} Tenant ${slug} already exists (skipped)"
      SKIPPED=$((SKIPPED + 1))
    else
      echo -e "${RED}✗${NC} Failed to provision tenant ${slug} (exit code: $EXIT_CODE)"
      FAILED=$((FAILED + 1))
    fi
  fi

  echo ""
done

# Summary
echo -e "${BLUE}=== Provisioning Summary ===${NC}"
echo -e "${GREEN}Provisioned:${NC} $PROVISIONED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}[DRY RUN]${NC} No changes were made. Remove --dry-run to provision tenants."
  exit 0
fi

# Verification
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} All tenants provisioned successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Verify EnterpriseCustomer records:"
  echo "     kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \"from enterprise.models import EnterpriseCustomer; print(f'Count: {EnterpriseCustomer.objects.count()}')\""
  echo ""
  echo "  2. Run tenant isolation verification:"
  echo "     bash scripts/qa/verify-tenant-isolation.sh"
  echo ""
  echo "  3. Test X-Tenant-ID headers:"
  echo "     curl -I https://academyv2.mereka.io/courses | grep X-Tenant-ID"
  echo "     curl -I https://academy.biji-biji.com/courses | grep X-Tenant-ID"
  echo "     curl -I https://skillourfuture.academy.mereka.io/courses | grep X-Tenant-ID"
  echo ""
  exit 0
else
  echo -e "${RED}✗${NC} Some tenants failed to provision. Review errors above."
  exit 1
fi
