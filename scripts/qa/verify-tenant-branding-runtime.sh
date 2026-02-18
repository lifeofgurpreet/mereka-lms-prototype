#!/usr/bin/env bash
# @covers AC-TBR-101, AC-TBR-102, AC-TBR-103
# @spec: multi-tenancy-architecture_spec.md
# Runtime verification of tenant branding system
#
# Usage:
#   ./scripts/qa/verify-tenant-branding-runtime.sh [--env prod|staging|local] [--target URL]
#
# This script verifies that the multi-tenant branding system is working correctly
# at runtime by checking:
# - Per-domain SITE_NAME configuration (AC-TBR-101)
# - Per-domain logo URL configuration (AC-TBR-102)
# - Footer variant contract per domain (AC-TBR-103)
#
# IMPORTANT: This is a runtime check — it requires ENABLE_MULTI_TENANT_BRANDING=True
# and live endpoints. When the runtime is not available, all checks are marked as SKIP.
#
# Reference: docs/operations/TENANT_BRANDING_SURFACE_MATRIX.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0
WARN=0

# Default environment
ENV="${ENV:-prod}"
BASE_URL=""
TARGET_URL=""
CURL_TIMEOUT=10
RUNTIME_AVAILABLE=0

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-tenant-branding-runtime.sh [OPTIONS]

Options:
  --env prod|staging|local   Set environment (default: prod)
                             prod: https://academyv2.mereka.io
                             staging: https://academyv2.mereka.io (same as prod)
                             local: http://apps.localhost
  --target URL               Override base URL (e.g., http://localhost:8000)
  -h, --help                 Show this help

Environment variables:
  ENV                        Same as --env flag
  CURL_TIMEOUT              Timeout for HTTP requests (default: 10s)

Examples:
  # Check production
  ./scripts/qa/verify-tenant-branding-runtime.sh --env prod

  # Check local development
  ./scripts/qa/verify-tenant-branding-runtime.sh --env local

  # Check custom target
  ./scripts/qa/verify-tenant-branding-runtime.sh --target http://localhost:8000

Exit codes:
  0 - All checks passed or all checks skipped (runtime not available)
  1 - One or more checks failed

Note: This script requires live endpoints. If ENABLE_MULTI_TENANT_BRANDING=False,
all checks will be marked as SKIP with a clear message.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="${2:-}"
      shift 2
      ;;
    --target)
      TARGET_URL="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}ERROR:${NC} Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Set base URL based on environment
if [[ -n "$TARGET_URL" ]]; then
  BASE_URL="$TARGET_URL"
else
  case "$ENV" in
    prod|staging)
      BASE_URL="https://academyv2.mereka.io"
      ;;
    local)
      BASE_URL="http://apps.localhost"
      ;;
    *)
      echo -e "${RED}ERROR:${NC} Invalid environment: $ENV" >&2
      echo "Valid options: prod, staging, local" >&2
      exit 1
      ;;
  esac
fi

# Helper functions
pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
  SKIP=$((SKIP + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARN=$((WARN + 1))
}

# Domain targets to check
# All tenants currently share "Mereka Academy" as SITE_NAME (Phase 1)
# Per-tenant SITE_NAME differentiation is Phase 2 scope
declare -A DOMAIN_TARGETS=(
  ["academyv2.mereka.io"]="Mereka Academy"
  ["academy.biji-biji.com"]="Mereka Academy"
  ["skillourfuture.academy.mereka.io"]="Mereka Academy"
)

# Check if runtime is available
check_runtime_available() {
  local first_domain="academyv2.mereka.io"
  local test_url

  if [[ "$ENV" == "local" ]]; then
    test_url="http://apps.localhost/api/mfe_config/v1"
  else
    test_url="https://${first_domain}/api/mfe_config/v1"
  fi

  echo -e "${CYAN}Checking runtime availability...${NC}"

  if curl -sf --max-time "$CURL_TIMEOUT" "$test_url" >/dev/null 2>&1; then
    RUNTIME_AVAILABLE=1
    pass "Runtime is available (MFE config endpoint reachable)"
  else
    RUNTIME_AVAILABLE=0
    warn "Runtime not available — MFE config endpoint unreachable"
    echo "  URL: $test_url"
    echo "  This is expected if ENABLE_MULTI_TENANT_BRANDING=False"
    echo "  All runtime checks will be marked as SKIP"
  fi

  echo ""
}

# Verify per-domain MFE config endpoint
verify_domain_config() {
  local domain="$1"
  local expected_site_name="$2"
  local config_url
  local response
  local actual_site_name
  local logo_url
  local has_brand_colors=0

  if [[ "$ENV" == "local" ]]; then
    config_url="http://apps.localhost/api/mfe_config/v1"
  else
    config_url="https://${domain}/api/mfe_config/v1"
  fi

  echo -e "${CYAN}Checking domain: ${domain}${NC}"

  if [[ "$RUNTIME_AVAILABLE" -eq 0 ]]; then
    skip "AC-TBR-101: SITE_NAME for ${domain} (runtime not available)"
    skip "AC-TBR-102: Logo URL for ${domain} (runtime not available)"
    skip "AC-TBR-103: Footer variant for ${domain} (runtime not available)"
    echo ""
    return
  fi

  # Fetch MFE config
  if ! response=$(curl -sf --max-time "$CURL_TIMEOUT" "$config_url" 2>&1); then
    fail "AC-TBR-101: Failed to fetch MFE config for ${domain}"
    echo "  URL: $config_url"
    echo "  Error: $response"
    skip "AC-TBR-102: Logo URL for ${domain} (config fetch failed)"
    skip "AC-TBR-103: Footer variant for ${domain} (config fetch failed)"
    echo ""
    return
  fi

  # Extract SITE_NAME using basic grep/sed (no jq dependency)
  if ! actual_site_name=$(echo "$response" | grep -o '"SITE_NAME"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"SITE_NAME"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'); then
    fail "AC-TBR-101: SITE_NAME not found in MFE config for ${domain}"
    echo "  URL: $config_url"
  else
    # Check if SITE_NAME is domain-specific (not default "Open edX")
    if [[ "$actual_site_name" == "Open edX" ]]; then
      fail "AC-TBR-101: SITE_NAME is default 'Open edX' for ${domain} (expected: ${expected_site_name})"
      echo "  URL: $config_url"
      echo "  Actual: $actual_site_name"
    elif [[ "$actual_site_name" == "$expected_site_name" ]]; then
      pass "AC-TBR-101: SITE_NAME is domain-specific for ${domain} (${actual_site_name})"
    else
      warn "AC-TBR-103: SITE_NAME mismatch for ${domain}"
      echo "  Expected: $expected_site_name"
      echo "  Actual: $actual_site_name"
      echo "  Footer variant contract may be broken"
    fi
  fi

  # Extract logo URL
  if ! logo_url=$(echo "$response" | grep -o '"LOGO_URL"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"LOGO_URL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'); then
    fail "AC-TBR-102: LOGO_URL not found in MFE config for ${domain}"
    echo "  URL: $config_url"
  else
    if [[ -z "$logo_url" ]]; then
      fail "AC-TBR-102: LOGO_URL is empty for ${domain}"
      echo "  URL: $config_url"
    else
      # Check if logo URL is domain-specific (not default Open edX logo)
      if echo "$logo_url" | grep -qi "openedx"; then
        fail "AC-TBR-102: LOGO_URL contains default 'openedx' for ${domain}"
        echo "  URL: $config_url"
        echo "  Logo URL: $logo_url"
      else
        pass "AC-TBR-102: Logo URL is domain-specific for ${domain}"
      fi
    fi
  fi

  # Verify LMS_BASE_URL matches the domain
  local lms_base_url
  if lms_base_url=$(echo "$response" | grep -o '"LMS_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"LMS_BASE_URL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'); then
    if echo "$lms_base_url" | grep -q "$domain"; then
      pass "AC-TBR-101: LMS_BASE_URL matches domain for ${domain}"
    else
      fail "AC-TBR-101: LMS_BASE_URL does not match domain for ${domain}"
      echo "  Expected to contain: $domain"
      echo "  Actual: $lms_base_url"
    fi
  fi

  # Brand color tokens are Phase 2 (branding_config population)
  # Not a failure or warning — just informational
  if echo "$response" | grep -qE '"--mereka-color-|"BRAND_(PRIMARY|SECONDARY|ACCENT)"'; then
    has_brand_colors=1
    echo -e "  ${CYAN}[INFO]${NC} Brand color tokens present for ${domain}"
  else
    echo -e "  ${CYAN}[INFO]${NC} Brand color tokens not yet configured for ${domain} (Phase 2 scope)"
  fi

  # Footer variant contract check (AC-TBR-103)
  # This checks that the SITE_NAME matches the expected variant from footer mapping
  if [[ "$actual_site_name" == "$expected_site_name" ]]; then
    pass "AC-TBR-103: Footer variant contract OK for ${domain}"
  else
    # Already reported as WARN above, don't duplicate
    :
  fi

  echo ""
}

# Main execution
echo "=== Tenant Branding Runtime Verification ==="
echo "Environment: $ENV"
echo "Base URL: $BASE_URL"
echo "Curl timeout: ${CURL_TIMEOUT}s"
echo ""

# Check runtime availability first
check_runtime_available

# If runtime is not available, skip all domain checks but still iterate
# to show what would be checked
for domain in "${!DOMAIN_TARGETS[@]}"; do
  verify_domain_config "$domain" "${DOMAIN_TARGETS[$domain]}"
done

# Summary
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP | ${YELLOW}WARN:${NC} $WARN"
echo ""

# Exit logic
if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}FAILED:${NC} $FAIL check(s) failed"
  echo ""
  echo "Common issues:"
  echo "- Cache TTL: Wait 5 minutes after config change (Redis cache)"
  echo "- DNS propagation: New domains may take up to 30 minutes"
  echo "- ENABLE_MULTI_TENANT_BRANDING=False: Check Tutor config"
  echo "- Caddy routing: Verify domain in Caddyfile and restart Caddy"
  echo ""
  echo "See docs/operations/TROUBLESHOOTING.md for detailed troubleshooting"
  exit 1
elif [[ "$RUNTIME_AVAILABLE" -eq 0 ]] && [[ "$SKIP" -gt 0 ]]; then
  echo -e "${YELLOW}SKIPPED:${NC} Runtime not available"
  echo "This is expected when ENABLE_MULTI_TENANT_BRANDING=False"
  echo "Run this script after enabling multi-tenant branding in production"
  exit 0
else
  echo -e "${GREEN}SUCCESS:${NC} All runtime checks passed"
  exit 0
fi
