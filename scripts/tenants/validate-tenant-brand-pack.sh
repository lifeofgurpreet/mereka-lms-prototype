#!/usr/bin/env bash
# @covers AC-TBR-202
# Validates tenant brand pack directory structure and branding.json configuration.
#
# Checks:
# - Directory structure (branding.json, logos/, favicons/, css/)
# - JSON validity of branding.json
# - JSON Schema compliance (if jq and schema available)
# - Logo file existence and size limits
# - Color hex format
# - Footer link HTTPS enforcement
# - Email format validation
# - Domain FQDN validation
#
# Usage:
#   ./scripts/tenants/validate-tenant-brand-pack.sh
#   ./scripts/tenants/validate-tenant-brand-pack.sh --slug <tenant-slug>
#   ./scripts/tenants/validate-tenant-brand-pack.sh --strict
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
TENANT_SLUG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      TENANT_SLUG="$2"
      shift 2
      ;;
    --strict)
      STRICT_MODE=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--slug <tenant-slug>] [--strict]"
      echo ""
      echo "Options:"
      echo "  --slug <slug>    Validate specific tenant"
      echo "  --strict         Treat warnings as failures"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}=== Tenant Brand Pack Validation ===${NC}"
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
# Tenant Directory Discovery
# ============================================================================

TENANT_DIR="infrastructure/tutor/themes/mereka/tenants"

# Check if tenant directory exists
if [[ ! -d "$TENANT_DIR" ]]; then
  warn "Tenant directory does not exist ($TENANT_DIR)"
  echo ""
  echo -e "${BLUE}## Summary${NC}"
  echo ""
  echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
  echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
  echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
  echo ""
  echo -e "${YELLOW}⚠️  No tenant directories found (expected after first tenant provisioning)${NC}"
  exit 0
fi

# Collect tenant directories
TENANT_DIRS=()
if [[ -n "$TENANT_SLUG" ]]; then
  # Validate specific tenant
  if [[ -d "$TENANT_DIR/$TENANT_SLUG" ]]; then
    TENANT_DIRS=("$TENANT_DIR/$TENANT_SLUG")
  else
    fail "Tenant directory not found: $TENANT_DIR/$TENANT_SLUG"
    echo ""
    echo -e "${BLUE}## Summary${NC}"
    echo ""
    echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
    echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
    echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
    echo ""
    exit 1
  fi
else
  # Validate all tenants (exclude _template and README.md)
  while IFS= read -r dir; do
    # Skip _template directory
    if [[ "$(basename "$dir")" == "_template" ]]; then
      continue
    fi
    TENANT_DIRS+=("$dir")
  done < <(find "$TENANT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi

if [[ ${#TENANT_DIRS[@]} -eq 0 ]]; then
  warn "No tenant directories found (expected after first tenant provisioning)"
  echo ""
  echo -e "${BLUE}## Summary${NC}"
  echo ""
  echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
  echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
  echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
  echo ""
  echo -e "${YELLOW}⚠️  No tenant directories to validate${NC}"
  exit 0
fi

echo "Found ${#TENANT_DIRS[@]} tenant directory(ies) to validate"
echo ""

# ============================================================================
# Validate Each Tenant
# ============================================================================

for tenant_dir in "${TENANT_DIRS[@]}"; do
  tenant_slug=$(basename "$tenant_dir")
  echo -e "${BLUE}### Tenant: $tenant_slug${NC}"

  # Check directory structure
  if [[ -d "$tenant_dir/logos" ]]; then
    pass "logos/ directory exists"
  else
    warn "logos/ directory missing (create with mkdir -p $tenant_dir/logos)"
  fi

  if [[ -d "$tenant_dir/favicons" ]]; then
    pass "favicons/ directory exists"
  else
    warn "favicons/ directory missing (create with mkdir -p $tenant_dir/favicons)"
  fi

  if [[ -d "$tenant_dir/css" ]]; then
    pass "css/ directory exists"
  else
    warn "css/ directory missing (optional, create with mkdir -p $tenant_dir/css)"
  fi

  # Check branding.json exists
  if [[ ! -f "$tenant_dir/branding.json" ]]; then
    warn "branding.json missing for $tenant_slug (tenant may use DB-only config or config.json)"
    echo ""
    continue
  fi

  pass "branding.json exists"

  # Validate JSON syntax
  if ! jq empty "$tenant_dir/branding.json" 2>/dev/null; then
    fail "branding.json is not valid JSON"
    echo ""
    continue
  fi

  pass "branding.json is valid JSON"

  CONFIG_JSON=$(jq -r '.' "$tenant_dir/branding.json")

  # Required fields present
  REQUIRED_FIELDS=("slug" "name" "domain" "colors.primary" "logos.logo_url" "logos.favicon_url" "footer.contact_email")
  ALL_REQUIRED_PRESENT=1

  for field in "${REQUIRED_FIELDS[@]}"; do
    if ! echo "$CONFIG_JSON" | jq -e ".${field}" >/dev/null 2>&1; then
      fail "Required field missing: $field"
      ALL_REQUIRED_PRESENT=0
    fi
  done

  if [[ $ALL_REQUIRED_PRESENT -eq 1 ]]; then
    pass "All required fields present"
  fi

  # slug matches directory name
  config_slug=$(echo "$CONFIG_JSON" | jq -r '.slug // ""')
  if [[ "$config_slug" == "$tenant_slug" ]]; then
    pass "slug matches directory name ($tenant_slug)"
  else
    fail "slug mismatch: directory=$tenant_slug, config=$config_slug"
  fi

  # slug pattern validation
  if echo "$config_slug" | grep -qE '^[a-z0-9-]+$'; then
    if [[ ${#config_slug} -ge 2 && ${#config_slug} -le 63 ]]; then
      pass "slug matches pattern (^[a-z0-9-]+$, 2-63 chars)"
    else
      fail "slug length invalid (must be 2-63 chars, got ${#config_slug})"
    fi
  else
    fail "slug pattern invalid (must match ^[a-z0-9-]+$)"
  fi

  # All color values match hex pattern
  for color_field in "primary" "secondary" "accent" "text_on_primary"; do
    color_value=$(echo "$CONFIG_JSON" | jq -r ".colors.${color_field} // \"\"")
    if [[ -n "$color_value" ]]; then
      if echo "$color_value" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
        pass "colors.$color_field is valid hex ($color_value)"
      else
        fail "colors.$color_field is not valid hex ($color_value)"
      fi
    fi
  done

  # Logo files referenced exist on disk
  for logo_field in "logo_url" "logo_square_url" "logo_white_url" "favicon_url"; do
    logo_path=$(echo "$CONFIG_JSON" | jq -r ".logos.${logo_field} // \"\"")
    if [[ -n "$logo_path" ]]; then
      # Convert /static/themes/mereka/tenants/... to infrastructure/tutor/themes/mereka/tenants/...
      local_path=$(echo "$logo_path" | sed 's|^/static/themes/|infrastructure/tutor/themes/|')

      if [[ -f "$local_path" ]]; then
        pass "logos.$logo_field exists on disk ($local_path)"

        # Check file size (<500KB)
        file_size=$(stat -c%s "$local_path" 2>/dev/null || stat -f%z "$local_path" 2>/dev/null || echo "0")
        if [[ $file_size -lt 512000 ]]; then
          pass "logos.$logo_field is under 500KB ($(( file_size / 1024 ))KB)"
        else
          warn "logos.$logo_field exceeds 500KB ($(( file_size / 1024 ))KB)"
        fi
      else
        if [[ "$logo_field" == "logo_url" || "$logo_field" == "favicon_url" ]]; then
          fail "logos.$logo_field does not exist on disk ($local_path)"
        else
          warn "logos.$logo_field does not exist on disk ($local_path) (optional logo)"
        fi
      fi
    fi
  done

  # Footer links URLs are HTTPS
  footer_links=$(echo "$CONFIG_JSON" | jq -r '.footer.links // [] | length')
  if [[ $footer_links -gt 0 ]]; then
    for i in $(seq 0 $(( footer_links - 1 ))); do
      link_url=$(echo "$CONFIG_JSON" | jq -r ".footer.links[$i].url // \"\"")
      if [[ -n "$link_url" ]]; then
        if echo "$link_url" | grep -qE '^https://'; then
          pass "footer.links[$i].url uses HTTPS"
        else
          fail "footer.links[$i].url does not use HTTPS ($link_url)"
        fi
      fi
    done
  fi

  # Footer text has no HTML tags
  footer_text=$(echo "$CONFIG_JSON" | jq -r '.footer.text // ""')
  if [[ -n "$footer_text" ]]; then
    if echo "$footer_text" | grep -qE '<[^>]+>'; then
      fail "footer.text contains HTML tags (plaintext only)"
    else
      pass "footer.text is plaintext (no HTML)"
    fi

    if [[ ${#footer_text} -le 500 ]]; then
      pass "footer.text is under 500 chars (${#footer_text} chars)"
    else
      fail "footer.text exceeds 500 chars (${#footer_text} chars)"
    fi
  fi

  # Contact email matches basic email pattern
  contact_email=$(echo "$CONFIG_JSON" | jq -r '.footer.contact_email // ""')
  if [[ -n "$contact_email" ]]; then
    if echo "$contact_email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
      pass "footer.contact_email is valid email format"
    else
      fail "footer.contact_email is not valid email format ($contact_email)"
    fi
  fi

  # Domain is valid FQDN pattern
  domain=$(echo "$CONFIG_JSON" | jq -r '.domain // ""')
  if [[ -n "$domain" ]]; then
    if echo "$domain" | grep -qE '^([a-z0-9-]+\.)+[a-z]{2,}$'; then
      pass "domain is valid FQDN pattern"
    else
      fail "domain is not valid FQDN pattern ($domain)"
    fi
  fi

  # JSON Schema validation (if schema file exists)
  if [[ -f "specs/standards/brand-pack-schema.json" ]]; then
    # Check if ajv-cli is available
    if command -v ajv >/dev/null 2>&1; then
      if ajv validate -s specs/standards/brand-pack-schema.json -d "$tenant_dir/branding.json" >/dev/null 2>&1; then
        pass "branding.json validates against JSON Schema"
      else
        fail "branding.json does not validate against JSON Schema"
      fi
    else
      warn "ajv-cli not available (install with: npm install -g ajv-cli)"
    fi
  fi

  echo ""
done

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
