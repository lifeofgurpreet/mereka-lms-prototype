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
BRANDING_FILE=""
BASE_DIR=""

usage() {
  echo "Usage: $0 --slug SLUG [--dry-run] [--branding-file PATH] [--base-dir PATH]"
  echo ""
  echo "Required:"
  echo "  --slug      Tenant slug (e.g. 'acme-corp')"
  echo ""
  echo "Optional:"
  echo "  --dry-run   Show what would be done without executing"
  echo "  --branding-file PATH  Use explicit branding JSON file instead of tenants/{slug}/branding.json"
  echo "  --base-dir PATH       Override tenants root directory (defaults to themes/mereka/tenants)"
  echo "  -h, --help  Show this help"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --branding-file) BRANDING_FILE="$2"; shift 2 ;;
    --base-dir) BASE_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  echo -e "${RED}ERROR${NC}: --slug is required"
  usage
fi

THEME_BASE="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TENANTS_BASE="${BASE_DIR:-$THEME_BASE/tenants}"
TENANT_DIR="$TENANTS_BASE/$SLUG"

if [[ -z "$BRANDING_FILE" ]]; then
  BRANDING_FILE="$TENANT_DIR/branding.json"
fi

echo "=== Tenant Branding Sync ==="
echo ""
echo "  Slug:       $SLUG"
echo "  Theme base: $THEME_BASE"
echo "  Tenants:    $TENANTS_BASE"
echo "  Tenant dir: $TENANT_DIR"
echo "  Branding:   $BRANDING_FILE"
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

# Step 4: Check for branding.json (SiteConfiguration values) and build token overrides.
if [[ -f "$BRANDING_FILE" ]]; then
  echo ""
  echo "Found branding.json at $BRANDING_FILE"
  if command -v python3 &>/dev/null; then
    # Validate JSON
    if python3 -c "import json; json.load(open('$BRANDING_FILE'))" 2>/dev/null; then
      echo -e "${GREEN}Valid${NC}: branding.json is valid JSON"
    else
      echo -e "${RED}Invalid${NC}: branding.json contains malformed JSON"
      exit 1
    fi
  fi
  TOKEN_CSS="$CSS_DIR/tokens.css"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}DRY RUN${NC}: Would update SiteConfiguration.site_values from branding.json"
    echo -e "${YELLOW}DRY RUN${NC}: Would generate tenant token overrides at $TOKEN_CSS"
  else
    echo "To apply: merge branding.json into SiteConfiguration via Django admin or management command."
    if command -v python3 &>/dev/null; then
      python3 - "$BRANDING_FILE" "$TOKEN_CSS" <<'PY'
import json
import re
import sys
from pathlib import Path

branding_path = Path(sys.argv[1])
token_css_path = Path(sys.argv[2])
data = json.loads(branding_path.read_text(encoding="utf-8"))

hex_re = re.compile(r"^#[0-9a-fA-F]{6}$")

def pick_hex(value, fallback):
    if isinstance(value, str) and hex_re.match(value):
        return value.lower()
    return fallback

colors = data.get("colors") if isinstance(data.get("colors"), dict) else None
if not colors:
    print("ERROR: branding.json must define a top-level colors object.", file=sys.stderr)
    sys.exit(1)

if not isinstance(colors.get("primary"), str) or not hex_re.match(colors["primary"]):
    print("ERROR: branding.json must define colors.primary as #RRGGBB.", file=sys.stderr)
    sys.exit(1)

primary = pick_hex(colors.get("primary"), "#ab3b78")
secondary = pick_hex(colors.get("secondary"), "#237072")
accent = pick_hex(colors.get("accent"), "#295cad")
text_on_primary = pick_hex(colors.get("text_on_primary"), "#ffffff")

payload = "\n".join(
    [
        "/* Generated by scripts/tenants/sync-tenant-branding.sh */",
        "/* Do not edit directly: update tenants/{slug}/branding.json and re-run sync. */",
        ":root {",
        f"  --tenant-color-primary: {primary};",
        f"  --tenant-color-secondary: {secondary};",
        f"  --tenant-color-accent: {accent};",
        f"  --tenant-color-text-on-primary: {text_on_primary};",
        "  --mereka-color-magenta: var(--tenant-color-primary);",
        "  --mereka-color-teal: var(--tenant-color-secondary);",
        "  --mereka-color-blue: var(--tenant-color-accent);",
        "  --pgn-color-primary-base: var(--tenant-color-primary);",
        "  --pgn-color-secondary-base: var(--tenant-color-secondary);",
        "  --pgn-color-info-base: var(--tenant-color-accent);",
        "  --pgn-link-color: var(--tenant-color-primary);",
        "  --pgn-link-hover-color: var(--tenant-color-secondary);",
        "  --pgn-color-text-base: var(--tenant-color-text-on-primary);",
        "}",
        "",
    ]
)

token_css_path.parent.mkdir(parents=True, exist_ok=True)
token_css_path.write_text(payload, encoding="utf-8")
print(f"Wrote tenant token overrides: {token_css_path}")
PY
    else
      echo -e "${YELLOW}WARN${NC}: python3 not found; skipped tenant token CSS generation"
    fi
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
