#!/usr/bin/env bash
# verify-enterprise-all-acs.sh
# Comprehensive runner for all 36 enterprise microservices acceptance criteria.
# Runs individual verification scripts and aggregates results.
# Exit 0 = all suites pass, exit 1 = any failure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0; TOTAL_FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Enterprise Microservices — Full AC Verification Suite      ║"
echo "║  Coverage: AC-001 through AC-036 (36 acceptance criteria)   ║"
echo "║  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

SUITES=(
  "verify-enterprise-service-deployment.sh|AC-001..AC-008|Service Deployment"
  "verify-enterprise-tenant-isolation.sh|AC-009..AC-013|Tenant Isolation"
  "verify-enterprise-license-management.sh|AC-014..AC-018|License Management"
  "verify-enterprise-catalog.sh|AC-019..AC-021|Enterprise Catalog"
  "verify-enterprise-access-subsidy.sh|AC-022..AC-025|Access & Subsidy"
  "verify-enterprise-sso-saml.sh|AC-026..AC-029|SSO/SAML"
  "verify-enterprise-integrated-channels.sh|AC-030..AC-032|Integrated Channels"
  "verify-enterprise-secrets.sh|AC-033..AC-034|Secrets & Config"
  "verify-enterprise-observability.sh|AC-035..AC-036|Observability"
)

RESULTS=()

for suite_info in "${SUITES[@]}"; do
  IFS='|' read -r script acs label <<< "$suite_info"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $label ($acs)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  SCRIPT_PATH="$SCRIPT_DIR/$script"
  if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo -e "${RED}✗${NC} Script not found or not executable: $script"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    RESULTS+=("FAIL|$label ($acs)")
    continue
  fi

  if "$SCRIPT_PATH" 2>&1; then
    RESULTS+=("PASS|$label ($acs)")
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    RESULTS+=("FAIL|$label ($acs)")
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
  echo
done

# Grand Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    GRAND SUMMARY                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
for result in "${RESULTS[@]}"; do
  IFS='|' read -r status label <<< "$result"
  if [[ "$status" == "PASS" ]]; then
    printf "║  ${GREEN}✓ PASS${NC}  %-50s ║\n" "$label"
  else
    printf "║  ${RED}✗ FAIL${NC}  %-50s ║\n" "$label"
  fi
done
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  Suites passed: ${GREEN}%d${NC} / %d                                     ║\n" "$TOTAL_PASS" "$((TOTAL_PASS + TOTAL_FAIL))"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ $TOTAL_FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
