#!/usr/bin/env bash
# verify-legacy-ecommerce-ui-refs.sh — Guard against new legacy ecommerce references
# @covers AC-UIECOM-004
#
# Flags any legacy ecommerce URLs/paths in branded/operational surfaces.
# Known references (ADRs, specs, deprecation docs) are excluded.
#
# Usage:
#   ./scripts/qa/verify-legacy-ecommerce-ui-refs.sh
#   ./scripts/qa/verify-legacy-ecommerce-ui-refs.sh --strict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
STRICT_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT_MODE=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Legacy Ecommerce UI Reference Guard ===${NC}"
echo ""

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS_COUNT++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)) || true; }
warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
  if [[ $STRICT_MODE -eq 1 ]]; then
    fail "$1 (strict mode)"
    ((WARN_COUNT--)) || true
  fi
}

# ============================================================================
# Ecommerce Service Inventory
# ============================================================================

echo -e "${BLUE}## Ecommerce Service Inventory${NC}"

# Check if legacy ecommerce K8s configs still exist
if [[ -d "deploy/k8s/base/plugins/ecommerce" ]]; then
  warn "Legacy ecommerce K8s configs still present (deploy/k8s/base/plugins/ecommerce/)"
else
  pass "No legacy ecommerce K8s configs in base"
fi

# Check if purchase-gateway exists (replacement)
if [[ -d "services/purchase-gateway" ]]; then
  pass "Purchase Gateway service exists (replacement)"
else
  warn "Purchase Gateway service not found"
fi

# Check ADR-018 exists
if [[ -f "docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md" ]]; then
  pass "ADR-018 (deprecation decision) exists"
else
  fail "ADR-018 missing — deprecation decision not documented"
fi

echo ""

# ============================================================================
# Branded Surface Scan (AC-UIECOM-001 + AC-UIECOM-004)
# ============================================================================

echo -e "${BLUE}## Branded Surface Scan${NC}"

# Patterns that indicate legacy ecommerce references
LEGACY_PATTERNS=(
  "ecommerce\.academyv2\.mereka\.io"
  "/basket/"
  "/checkout/"
  "oscar"
)

# Directories to scan (branded/operational surfaces)
SCAN_DIRS=(
  "infrastructure/tutor/plugins/"
  "infrastructure/tutor/themes/"
  "scripts/branding/"
)

# Only scan if directories exist
EXISTING_SCAN_DIRS=()
for dir in "${SCAN_DIRS[@]}"; do
  [[ -d "$dir" ]] && EXISTING_SCAN_DIRS+=("$dir")
done

if [[ ${#EXISTING_SCAN_DIRS[@]} -eq 0 ]]; then
  warn "No branded surface directories found to scan"
else
  for pattern in "${LEGACY_PATTERNS[@]}"; do
    MATCHES=$(grep -rn "$pattern" "${EXISTING_SCAN_DIRS[@]}" 2>/dev/null \
      | grep -v "# DEPRECATED" \
      | grep -v "# Legacy" \
      | grep -v "# NOTE:" || true)

    if [[ -z "$MATCHES" ]]; then
      pass "No '${pattern}' in branded surfaces"
    else
      MATCH_COUNT=$(echo "$MATCHES" | wc -l)
      warn "'${pattern}' found ${MATCH_COUNT} time(s) in branded surfaces"
      echo "$MATCHES" | head -3 | while IFS= read -r line; do
        echo -e "    ${YELLOW}→${NC} $line"
      done
    fi
  done
fi

echo ""

# ============================================================================
# LMS Settings Audit (AC-UIECOM-001)
# ============================================================================

echo -e "${BLUE}## LMS Settings Audit${NC}"

LMS_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$LMS_SETTINGS" ]]; then
  pass "LMS production settings exist"

  # Check for legacy ecommerce config keys
  if grep -q "ECOMMERCE_PUBLIC_URL_ROOT" "$LMS_SETTINGS"; then
    warn "ECOMMERCE_PUBLIC_URL_ROOT still configured in LMS settings"
  else
    pass "No ECOMMERCE_PUBLIC_URL_ROOT in LMS settings"
  fi

  if grep -q "ECOMMERCE_API_URL" "$LMS_SETTINGS"; then
    warn "ECOMMERCE_API_URL still configured in LMS settings"
  else
    pass "No ECOMMERCE_API_URL in LMS settings"
  fi

  if grep -q "ORDER_HISTORY_MICROFRONTEND_URL" "$LMS_SETTINGS"; then
    warn "ORDER_HISTORY_MICROFRONTEND_URL still configured in LMS settings"
  else
    pass "No ORDER_HISTORY_MICROFRONTEND_URL in LMS settings"
  fi

  # Check if MFE_CONFIG has ecommerce base URL
  if grep -q 'ECOMMERCE_BASE_URL' "$LMS_SETTINGS"; then
    warn "MFE_CONFIG['ECOMMERCE_BASE_URL'] still configured"
  else
    pass "No ECOMMERCE_BASE_URL in MFE_CONFIG"
  fi
else
  warn "LMS production settings not found at expected path"
fi

echo ""

# ============================================================================
# Caddyfile Route Audit
# ============================================================================

echo -e "${BLUE}## Caddyfile Route Audit${NC}"

CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"

if [[ -f "$CADDYFILE" ]]; then
  pass "Caddyfile exists"

  # Check for deprecated route patterns
  if grep -q '/basket' "$CADDYFILE"; then
    warn "Caddyfile references /basket route"
  else
    pass "No /basket route in Caddyfile"
  fi

  if grep -q '/checkout' "$CADDYFILE"; then
    warn "Caddyfile references /checkout route"
  else
    pass "No /checkout route in Caddyfile"
  fi

  # Check if orders/payment already redirect to purchase gateway
  if grep -q 'payments-gateway\|purchase-gateway' "$CADDYFILE"; then
    pass "Orders/payment routes proxy to new gateway"
  else
    warn "Orders/payment routes not proxied to new gateway"
  fi
else
  warn "Caddyfile not found"
fi

echo ""

# ============================================================================
# Tutor Plugin Audit
# ============================================================================

echo -e "${BLUE}## Tutor Plugin Audit${NC}"

PLUGIN="infrastructure/tutor/plugins/mereka_lms.py"

if [[ -f "$PLUGIN" ]]; then
  # Check for ecommerce plugin enablement
  if grep -q "ECOMMERCE" "$PLUGIN" 2>/dev/null; then
    warn "mereka_lms.py references ECOMMERCE config"
  else
    pass "mereka_lms.py has no ECOMMERCE references"
  fi
else
  warn "mereka_lms.py not found"
fi

# Check config.example.yml deprecation notice
if [[ -f "infrastructure/tutor/config.example.yml" ]]; then
  if grep -q "DEPRECATED" infrastructure/tutor/config.example.yml; then
    pass "config.example.yml marks ecommerce as DEPRECATED"
  else
    warn "config.example.yml doesn't mark ecommerce as DEPRECATED"
  fi
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
  echo -e "${GREEN}All checks passed — no legacy ecommerce UI references${NC}"
  exit 0
elif [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${YELLOW}Warnings: legacy ecommerce references exist (expected during transition)${NC}"
  exit 0
else
  echo -e "${RED}Failures found${NC}"
  exit 1
fi
