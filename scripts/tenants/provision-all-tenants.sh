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
TENANT_CONTRACT="${REPO_ROOT}/infrastructure/tenants/tenant-contracts.yml"

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

if [[ ! -f "$TENANT_CONTRACT" ]]; then
  echo -e "${RED}✗${NC} tenant contract not found: $TENANT_CONTRACT"
  exit 1
fi

mapfile -t TENANT_ROWS < <(python3 - "$TENANT_CONTRACT" <<'PY'
import sys
from pathlib import Path

import yaml

contract = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))
tenants = contract.get("tenants", [])
if not tenants:
    raise SystemExit("No tenants found in tenant contract")

for tenant in tenants:
    if not tenant.get("active", True):
        continue
    slug = tenant["slug"]
    name = tenant["name"]
    lms = tenant["domains"]["lms"]
    email = tenant.get("contact_email", "")
    country = tenant.get("country", "")
    print(f"{slug}|{name}|{lms}|{email}|{country}")
PY
)

if [[ "${#TENANT_ROWS[@]}" -eq 0 ]]; then
  echo -e "${RED}✗${NC} no active tenants found in $TENANT_CONTRACT"
  exit 1
fi

echo -e "${BLUE}=== Provisioning Tenants from Canonical Contract ===${NC}"
echo ""
echo "Tenant contract: ${TENANT_CONTRACT#$REPO_ROOT/}"
echo "Active tenants: ${#TENANT_ROWS[@]}"
echo ""
for idx in "${!TENANT_ROWS[@]}"; do
  IFS='|' read -r slug name domain _ _ <<< "${TENANT_ROWS[$idx]}"
  printf "  %s. %s (%s)\n" "$((idx + 1))" "$slug" "$domain"
done
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}[DRY RUN MODE]${NC} No changes will be made"
  echo ""
fi

# Track results
PROVISIONED=0
SKIPPED=0
FAILED=0

# Provision each tenant
for tenant_row in "${TENANT_ROWS[@]}"; do
  IFS='|' read -r slug name domain email country <<< "$tenant_row"

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
