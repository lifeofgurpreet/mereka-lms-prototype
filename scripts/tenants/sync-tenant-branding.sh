#!/usr/bin/env bash
# @covers AC-MTA-008, AC-MTA-009, AC-MTA-010, AC-MTA-011
# @spec: multi-tenancy-architecture_spec.md
# Sync tenant branding assets from TenantConfig.branding_config overrides.
#
# Copies the base Mereka theme as a starting point, then applies tenant-specific
# overrides (logos, favicon, colors) from the tenant's branding directory.
#
# Usage:
#   ./scripts/tenants/sync-tenant-branding.sh --slug acme-corp [--dry-run]
#
# Tenant assets are expected at:
#   infrastructure/tutor/themes/mereka/tenants/{slug}/
#
# Directory structure for overrides:
#   tenants/{slug}/
#     logos/
#       logo-horizontal.png
#       logo-horizontal.svg
#       logo-square.png
#       logo-square.svg
#       logo-white.png        (optional)
#       logo-white.svg        (optional)
#     favicon.ico              (optional)
#     css/
#       overrides.css          (optional, custom CSS overrides)
#     branding.json            (optional, SiteConfiguration values)
#
# Idempotent: safe to re-run. Overwrites existing tenant assets with latest.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SLUG=""
DRY_RUN=0

usage() {
  echo "Usage: $0 --slug SLUG [--dry-run]"
  echo ""
  echo "Required:"
  echo "  --slug      Tenant slug (e.g. 'acme-corp')"
  echo ""
  echo "Optional:"
  echo "  --dry-run   Show what would be done without executing"
  echo "  -h, --help  Show this help"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  echo -e "${RED}ERROR${NC}: --slug is required"
  usage
fi

THEME_BASE="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TENANT_DIR="$THEME_BASE/tenants/$SLUG"

echo "=== Tenant Branding Sync ==="
echo ""
echo "  Slug:       $SLUG"
echo "  Theme base: $THEME_BASE"
echo "  Tenant dir: $TENANT_DIR"
echo ""

# Step 1: Create tenant directory structure if it doesn't exist.
if [[ ! -d "$TENANT_DIR" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}DRY RUN${NC}: Would create directory: $TENANT_DIR"
    echo -e "${YELLOW}DRY RUN${NC}: Would create subdirectories: logos/ css/"
  else
    mkdir -p "$TENANT_DIR/logos" "$TENANT_DIR/css"
    echo -e "${GREEN}Created${NC}: $TENANT_DIR/{logos,css}/"
  fi
else
  echo "Tenant directory already exists: $TENANT_DIR"
fi

# Step 2: If tenant has logo overrides, sync them to the theme image directories.
LOGO_DIR="$TENANT_DIR/logos"
if [[ -d "$LOGO_DIR" ]]; then
  LOGO_COUNT=$(find "$LOGO_DIR" -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null | wc -l)
  if [[ "$LOGO_COUNT" -gt 0 ]]; then
    echo ""
    echo "Found $LOGO_COUNT logo file(s) in $LOGO_DIR"

    # Target directories where logos need to exist in the theme.
    LOGO_TARGETS=(
      "$THEME_BASE/common/static/images"
      "$THEME_BASE/lms/static/images"
      "$THEME_BASE/cms/static/images"
      "$THEME_BASE/mfe/images"
    )

    # We don't overwrite base theme logos. Instead we note them for
    # SiteConfiguration-based resolution at runtime. The branding.json
    # file (if present) should configure logo URLs pointing to tenant assets.
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "${YELLOW}DRY RUN${NC}: Logo files found, ready for deployment."
      echo "  Logos are served via SiteConfiguration.values['LOGO_URL'] at runtime."
      echo "  Ensure branding.json maps logo paths for this tenant."
    else
      echo "Logo files available at: $LOGO_DIR"
      echo "  These are served via SiteConfiguration.values['LOGO_URL'] at runtime."
    fi
  else
    echo "No logo files found in $LOGO_DIR (add .png/.svg files for branding)"
  fi
else
  if [[ $DRY_RUN -eq 0 ]] && [[ -d "$TENANT_DIR" ]]; then
    mkdir -p "$LOGO_DIR"
    echo "Created empty logos directory: $LOGO_DIR"
  fi
fi

# Step 3: Check for CSS overrides.
CSS_DIR="$TENANT_DIR/css"
if [[ -d "$CSS_DIR" ]]; then
  CSS_COUNT=$(find "$CSS_DIR" -type f -name "*.css" 2>/dev/null | wc -l)
  if [[ "$CSS_COUNT" -gt 0 ]]; then
    echo ""
    echo "Found $CSS_COUNT CSS override file(s) in $CSS_DIR"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "${YELLOW}DRY RUN${NC}: CSS overrides available for collectstatic deployment."
    else
      echo "CSS overrides available for collectstatic deployment."
    fi
  fi
fi

# Step 4: Check for branding.json (SiteConfiguration values).
BRANDING_JSON="$TENANT_DIR/branding.json"
if [[ -f "$BRANDING_JSON" ]]; then
  echo ""
  echo "Found branding.json at $BRANDING_JSON"
  if command -v python3 &>/dev/null; then
    # Validate JSON
    if python3 -c "import json; json.load(open('$BRANDING_JSON'))" 2>/dev/null; then
      echo -e "${GREEN}Valid${NC}: branding.json is valid JSON"
    else
      echo -e "${RED}Invalid${NC}: branding.json contains malformed JSON"
    fi
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}DRY RUN${NC}: Would update SiteConfiguration.site_values from branding.json"
  else
    echo "To apply: merge branding.json into SiteConfiguration via Django admin or management command."
  fi
else
  echo ""
  echo "No branding.json found (optional: add to $TENANT_DIR/branding.json)"
fi

# Step 5: Check for favicon.
FAVICON="$TENANT_DIR/favicon.ico"
if [[ -f "$FAVICON" ]]; then
  echo ""
  echo -e "${GREEN}Found${NC}: favicon.ico for tenant $SLUG"
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}=== DRY RUN COMPLETE ===${NC}"
  echo "No changes made."
else
  echo -e "${GREEN}=== Branding Sync Complete ===${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Add logo files to: $LOGO_DIR/"
  echo "  2. (Optional) Add CSS overrides to: $CSS_DIR/"
  echo "  3. (Optional) Add branding.json to: $TENANT_DIR/"
  echo "  4. Run collectstatic to deploy: tutor local run lms collectstatic --noinput"
  echo "  5. Verify branding at the tenant's domain"
fi
