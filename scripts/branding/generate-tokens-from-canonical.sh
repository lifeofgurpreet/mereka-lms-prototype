#!/usr/bin/env bash
# generate-tokens-from-canonical.sh
#
# Reads assets/branding/tokens.css (single source of truth) and regenerates
# the token blocks in:
#   - infrastructure/tutor/themes/mereka/scss/_tokens.scss       (SCSS bridge)
#   - infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css
#   - infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
#   - infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css
#   - infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css
#
# Idempotent: running when everything is in sync produces no diff.
#
# Usage:
#   ./scripts/branding/generate-tokens-from-canonical.sh          # update files
#   ./scripts/branding/generate-tokens-from-canonical.sh --check  # exit 1 if drift
#
# @covers AC-TKPIPE-004, AC-TKPIPE-005
# @spec: design-tokens-system_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

CANONICAL="$REPO_ROOT/assets/branding/tokens.css"
SCSS_BRIDGE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
DESIGN_TOKENS_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
COMMON_OVERRIDES="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
LMS_OVERRIDES="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
CMS_OVERRIDES="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"

for f in "$CANONICAL" "$SCSS_BRIDGE" "$DESIGN_TOKENS_CSS" "$COMMON_OVERRIDES" "$LMS_OVERRIDES" "$CMS_OVERRIDES"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file not found: $f" >&2
    exit 1
  fi
done

python3 - \
  "$CANONICAL" \
  "$SCSS_BRIDGE" \
  "$DESIGN_TOKENS_CSS" \
  "$COMMON_OVERRIDES" \
  "$LMS_OVERRIDES" \
  "$CMS_OVERRIDES" \
  "$CHECK_ONLY" \
  <<'PY'
import re
import sys
from pathlib import Path

canonical_path     = Path(sys.argv[1])
scss_path          = Path(sys.argv[2])
design_tokens_path = Path(sys.argv[3])
common_path        = Path(sys.argv[4])
lms_path           = Path(sys.argv[5])
cms_path           = Path(sys.argv[6])
check_only         = sys.argv[7] == "1"

# ---------------------------------------------------------------------------
# 1. Parse tokens.css — extract all --name: value pairs from :root
# ---------------------------------------------------------------------------

def parse_root_vars(css: str) -> dict[str, str]:
    """Return ordered dict of CSS custom property name → raw value string."""
    root_match = re.search(r":root\s*\{(.*?)\}", css, re.S)
    if not root_match:
        raise ValueError("No :root block found")
    block = root_match.group(1)
    # Match properties; value may contain parens, spaces, commas
    tokens: dict[str, str] = {}
    for m in re.finditer(r"(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);", block):
        name = m.group(1).strip()
        value = re.sub(r"\s+", " ", m.group(2).strip())
        tokens[name] = value
    return tokens

canonical_css = canonical_path.read_text(encoding="utf-8")
tokens = parse_root_vars(canonical_css)

# ---------------------------------------------------------------------------
# Namespace mapping: canonical --name  →  --mereka-name  used in overrides
# ---------------------------------------------------------------------------

# Exact renames (semantic aliases take priority over simple prefixing)
CANONICAL_TO_MEREKA: dict[str, str] = {
    "--color-black":     "--mereka-color-ink-900",
    "--color-teal":      "--mereka-color-teal",
    "--color-magenta":   "--mereka-color-magenta",
    "--color-blue":      "--mereka-color-blue",
    "--color-sky":       "--mereka-color-sky",
    "--color-forest":    "--mereka-color-success",
    "--color-gold":      "--mereka-color-warning",
    "--color-burgundy":  "--mereka-color-danger",
    "--color-pink":      "--mereka-color-danger-soft",
    # Fonts
    "--font-heading":    "--mereka-font-heading",
    "--font-body":       "--mereka-font-body",
    # Spacing — direct passthrough
    **{f"--space-{n}": f"--mereka-space-{n}"
       for n in ["0","1","2","3","4","5","6","8","10","12","16","20","24"]},
}

# SCSS variable mapping: canonical --name → $scss-name
def canonical_to_scss_var(name: str) -> str:
    """Convert --color-teal → $color-teal, --font-body → $font-body, etc."""
    # strip leading --
    return "$" + name.lstrip("-")


def token_or_default(name: str, default: str) -> str:
    """Return canonical token if available, else fallback to a supplied default."""
    return tokens.get(name, default)

# ---------------------------------------------------------------------------
# 2. Generate SCSS bridge block
#    Replace only the "generated" SCSS variable declarations and :root block.
#    Preserve Bootstrap overrides and global CSS rules that follow.
# ---------------------------------------------------------------------------

SCSS_GEN_START = "// BEGIN GENERATED — DO NOT EDIT (run generate-tokens-from-canonical.sh)\n"
SCSS_GEN_END   = "// END GENERATED\n"

# Colors to emit as SCSS vars (in declaration order from tokens.css)
SCSS_COLOR_NAMES = [
    "--color-teal", "--color-magenta", "--color-blue", "--color-sky",
    "--color-forest", "--color-gold", "--color-burgundy", "--color-pink",
    "--color-black", "--color-white",
]
# Additional colours that exist in _tokens.scss but NOT in tokens.css
# (Mereka-specific ink scale / neutral scale). These are static and preserved.
SCSS_STATIC_VARS = [
    ('$color-ink-900',          '#000000'),
    ('$color-ink-700',          '#4A494A'),
    ('$color-ink-500',          '#6B6B6B'),
    ('$color-ink-300',          '#929092'),
    ('$color-neutral-100',      '#FBFAFB'),
    ('$color-neutral-75',       '#F5F5F5'),
    ('$color-border',           '#DDDDDE'),
    ('$color-border-strong',    '#7B7B7C'),
]

def build_scss_generated_block() -> str:
    lines = [SCSS_GEN_START]
    # Emit static Mereka-specific vars first (ink scale, neutrals, borders)
    lines.append("// Mereka-specific palette (not in tokens.css)\n")
    for var, val in SCSS_STATIC_VARS:
        lines.append(f"{var}: {val};\n")
    lines.append("\n")
    # Emit vars derived from tokens.css
    lines.append("// Sourced from assets/branding/tokens.css\n")
    for cname in SCSS_COLOR_NAMES:
        if cname in tokens:
            svar = canonical_to_scss_var(cname)
            lines.append(f"{svar}: {tokens[cname]};\n")
    lines.append("\n")
    # Font stack vars
    lines.append("$mereka-body-font: \"Poppins\", \"Lato\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;\n")
    lines.append("$mereka-heading-font: \"Lato\", \"Poppins\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;\n")
    lines.append("\n")
    # Semantic aliases (reference the vars above)
    lines.append("// Semantic aliases\n")
    lines.append("$color-info: $color-blue;\n")
    lines.append("$color-info-soft: $color-sky;\n")
    lines.append("$color-success: $color-forest;\n")
    lines.append("$color-warning: $color-gold;\n")
    lines.append("$color-danger: $color-burgundy;\n")
    lines.append("$color-danger-soft: $color-pink;\n")
    lines.append("\n")
    # :root CSS custom properties block
    lines.append(":root {\n")
    lines.append("  --mereka-font-body: #{$mereka-body-font};\n")
    lines.append("  --mereka-font-heading: #{$mereka-heading-font};\n")
    lines.append("  --mereka-color-ink-900: #{$color-ink-900};\n")
    lines.append("  --mereka-color-ink-700: #{$color-ink-700};\n")
    lines.append("  --mereka-color-ink-500: #{$color-ink-500};\n")
    lines.append("  --mereka-color-ink-300: #{$color-ink-300};\n")
    lines.append("  --mereka-color-teal: #{$color-teal};\n")
    lines.append("  --mereka-color-magenta: #{$color-magenta};\n")
    lines.append(f"  --mereka-color-magenta-dark: {token_or_default('--color-magenta-dark', '#8a2f60')};\n")
    lines.append("  --mereka-color-blue: #{$color-blue};\n")
    lines.append("  --mereka-color-sky: #{$color-sky};\n")
    lines.append("  --mereka-color-indigo: #{$color-blue};\n")
    lines.append("  --mereka-color-ink-deep: #1a1623;\n")
    lines.append("  --mereka-color-surface-primary: #{$color-neutral-100};\n")
    lines.append("  --mereka-color-surface-secondary: #{$color-neutral-75};\n")
    lines.append("  --mereka-color-border: #{$color-border};\n")
    lines.append("  --mereka-color-border-strong: #{$color-border-strong};\n")
    lines.append("  --mereka-color-info: #{$color-info};\n")
    lines.append("  --mereka-color-info-soft: #{$color-info-soft};\n")
    lines.append("  --mereka-color-success: #{$color-success};\n")
    lines.append("  --mereka-color-warning: #{$color-warning};\n")
    lines.append("  --mereka-color-danger: #{$color-danger};\n")
    lines.append("  --mereka-color-danger-soft: #{$color-danger-soft};\n")
    lines.append("  --mereka-color-indigo-rgb: 41 92 173;\n")
    lines.append("  --mereka-color-teal-rgb: 35 112 114;\n")
    lines.append("  --mereka-color-magenta-rgb: 171 59 120;\n")
    lines.append("  --mereka-color-blue-rgb: 41 92 173;\n")
    lines.append("  --mereka-color-sky-rgb: 148 209 228;\n")
    lines.append("  --mereka-color-forest-rgb: 44 110 73;\n")
    lines.append("  --mereka-color-gold-rgb: 244 190 72;\n")
    lines.append("  --mereka-color-burgundy-rgb: 140 0 47;\n")
    lines.append("  --mereka-color-white-rgb: 255 255 255;\n")
    lines.append("  --mereka-color-ink-deep-rgb: 26 22 35;\n")
    lines.append("  --mereka-shadow-card: 0 20px 60px rgba(26, 22, 35, 0.08);\n")
    lines.append("  --mereka-mfe-gradient: linear-gradient(120deg, var(--mereka-color-magenta) 0%, var(--mereka-color-teal) 60%, var(--mereka-color-blue) 100%);\n")
    lines.append("  --mereka-mfe-card-shadow: 0 25px 60px rgb(var(--mereka-color-ink-deep-rgb) / 0.08);\n")
    lines.append("  --mereka-mfe-surface: var(--pgn-color-white);\n")
    lines.append("  --mereka-mfe-surface-muted: rgb(var(--mereka-color-ink-deep-rgb) / 0.04);\n")
    lines.append("  --mereka-mfe-border: rgb(var(--mereka-color-ink-deep-rgb) / 0.10);\n")
    lines.append(f"  --mereka-mfe-navbar-divider: {token_or_default('--mereka-mfe-navbar-divider', '0')};\n")
    lines.append(f"  --mereka-mfe-navbar-shadow: {token_or_default('--mereka-mfe-navbar-shadow', '0 10px 30px rgb(26 22 35 / 0.05)')};\n")
    lines.append("  --mereka-mfe-focus: rgb(var(--mereka-color-teal-rgb) / 0.18);\n")
    lines.append(f"  --mereka-mfe-btn-outline-border: {token_or_default('--mereka-mfe-btn-outline-border', 'rgb(26 22 35 / 0.25)')};\n")
    lines.append("  --mereka-mfe-form-control-radius: 16px;\n")
    lines.append("  --mereka-mfe-form-control-border: 1px solid var(--pgn-form-control-border-color);\n")
    lines.append(f"  --mereka-mfe-btn-shadow: {token_or_default('--mereka-mfe-btn-shadow', '0 12px 30px rgb(var(--mereka-color-indigo-rgb) / 0.3)')};\n")
    lines.append(f"  --mereka-mfe-btn-shadow-hover: {token_or_default('--mereka-mfe-btn-shadow-hover', '0 18px 38px rgb(var(--mereka-color-teal-rgb) / 0.24)')};\n")
    lines.append(f"  --mereka-mfe-form-control-focus-border: {token_or_default('--mereka-mfe-form-control-focus-border', 'var(--mereka-color-teal)')};\n")
    lines.append(f"  --mereka-mfe-dropdown-toggle-border: {token_or_default('--mereka-mfe-dropdown-toggle-border', 'rgb(26 22 35 / 0.20)')};\n")
    lines.append(f"  --mereka-mfe-badge-bg: {token_or_default('--mereka-mfe-badge-bg', 'rgba(35, 112, 114, 0.12)')};\n")
    lines.append(f"  --mereka-mfe-status-pill-bg: {token_or_default('--mereka-mfe-status-pill-bg', 'rgba(35, 112, 114, 0.10)')};\n")
    lines.append(f"  --mereka-mfe-authn-header-gradient-1: {token_or_default('--mereka-mfe-authn-header-gradient-1', 'rgb(var(--mereka-color-teal-rgb) / 0.14)')};\n")
    lines.append(f"  --mereka-mfe-authn-header-gradient-2: {token_or_default('--mereka-mfe-authn-header-gradient-2', 'rgb(var(--mereka-color-magenta-rgb) / 0.1)')};\n")
    lines.append(f"  --mereka-mfe-authn-header-gradient-3: {token_or_default('--mereka-mfe-authn-header-gradient-3', 'rgb(var(--mereka-color-blue-rgb) / 0.12)')};\n")
    lines.append(f"  --mereka-mfe-alert-info-bg: {token_or_default('--mereka-mfe-alert-info-bg', 'rgb(var(--mereka-color-sky-rgb) / 0.22)')};\n")
    lines.append(f"  --mereka-mfe-alert-info-border: {token_or_default('--mereka-mfe-alert-info-border', 'rgb(var(--mereka-color-sky-rgb) / 0.55)')};\n")
    lines.append(f"  --mereka-mfe-alert-success-bg: {token_or_default('--mereka-mfe-alert-success-bg', 'rgb(var(--mereka-color-forest-rgb) / 0.12)')};\n")
    lines.append(f"  --mereka-mfe-alert-success-border: {token_or_default('--mereka-mfe-alert-success-border', 'rgb(var(--mereka-color-forest-rgb) / 0.35)')};\n")
    lines.append(f"  --mereka-mfe-alert-warning-bg: {token_or_default('--mereka-mfe-alert-warning-bg', 'rgb(var(--mereka-color-gold-rgb) / 0.14)')};\n")
    lines.append(f"  --mereka-mfe-alert-warning-border: {token_or_default('--mereka-mfe-alert-warning-border', 'rgb(var(--mereka-color-gold-rgb) / 0.55)')};\n")
    lines.append(f"  --mereka-mfe-alert-danger-bg: {token_or_default('--mereka-mfe-alert-danger-bg', 'rgb(var(--mereka-color-burgundy-rgb) / 0.08)')};\n")
    lines.append(f"  --mereka-mfe-alert-danger-border: {token_or_default('--mereka-mfe-alert-danger-border', 'rgb(var(--mereka-color-burgundy-rgb) / 0.22)')};\n")
    lines.append(f"  --mereka-mfe-modal-shadow: {token_or_default('--mereka-mfe-modal-shadow', '0 30px 90px rgb(var(--mereka-color-ink-deep-rgb) / 0.18)')};\n")
    lines.append("  --mereka-mfe-card-radius: 24px;\n")
    lines.append("  --mereka-mfe-card-border: 1px solid var(--mereka-mfe-border);\n")
    lines.append(f"  --mereka-mfe-navbar-padding: {token_or_default('--mereka-mfe-navbar-padding', '0.85rem 1.5rem')};\n")
    lines.append(f"  --mereka-mfe-navbar-mobile-padding: {token_or_default('--mereka-mfe-navbar-mobile-padding', '0.75rem 1rem')};\n")
    lines.append(f"  --mereka-mfe-navbar-logo-height: {token_or_default('--mereka-mfe-navbar-logo-height', '32px')};\n")
    lines.append(f"  --mereka-mfe-pill-radius: {token_or_default('--mereka-mfe-pill-radius', '999px')};\n")
    lines.append(f"  --mereka-mfe-nav-item-font-weight: {token_or_default('--mereka-mfe-nav-item-font-weight', '500')};\n")
    lines.append(f"  --mereka-mfe-nav-link-transition: {token_or_default('--mereka-mfe-nav-link-transition', '150ms ease')};\n")
    lines.append(f"  --mereka-mfe-authn-cta-min-height: {token_or_default('--mereka-mfe-authn-cta-min-height', '44px')};\n")
    lines.append(f"  --mereka-mfe-emphasis-font-weight: {token_or_default('--mereka-mfe-emphasis-font-weight', '700')};\n")
    lines.append(f"  --mereka-mfe-authn-link-letter-spacing: {token_or_default('--mereka-mfe-authn-link-letter-spacing', '0.01em')};\n")
    lines.append(f"  --mereka-mfe-brand-font-weight: {token_or_default('--mereka-mfe-brand-font-weight', '600')};\n")
    lines.append(f"  --mereka-mfe-badge-gap: {token_or_default('--mereka-mfe-badge-gap', '0.35rem')};\n")
    lines.append(f"  --mereka-mfe-badge-padding: {token_or_default('--mereka-mfe-badge-padding', '0.25rem 0.85rem')};\n")
    lines.append(f"  --mereka-mfe-badge-letter-spacing: {token_or_default('--mereka-mfe-badge-letter-spacing', '0.08em')};\n")
    lines.append(f"  --mereka-mfe-badge-font-weight: {token_or_default('--mereka-mfe-badge-font-weight', '600')};\n")
    lines.append(f"  --mereka-mfe-course-grid-gap: {token_or_default('--mereka-mfe-course-grid-gap', '1rem')};\n")
    lines.append(f"  --mereka-mfe-status-badge-padding: {token_or_default('--mereka-mfe-status-badge-padding', '0.1rem 0.55rem')};\n")
    lines.append(f"  --mereka-mfe-authn-card-radius: {token_or_default('--mereka-mfe-authn-card-radius', '28px')};\n")
    lines.append(f"  --mereka-mfe-authn-card-border: {token_or_default('--mereka-mfe-authn-card-border', '1px solid rgb(var(--mereka-color-ink-deep-rgb) / 0.10)')};\n")
    lines.append(f"  --mereka-mfe-authn-card-shadow: {token_or_default('--mereka-mfe-authn-card-shadow', '0 28px 72px rgb(var(--mereka-color-ink-deep-rgb) / 0.14)')};\n")
    lines.append("  --mereka-mfe-alert-radius: 16px;\n")
    lines.append("  --mereka-mfe-modal-radius: 24px;\n")
    lines.append("  --mereka-mfe-modal-border: 1px solid var(--mereka-mfe-border);\n")
    lines.append("  --mereka-mfe-dropdown-radius: 16px;\n")
    lines.append("  --mereka-mfe-dropdown-border: 1px solid var(--mereka-mfe-border);\n")
    lines.append("  --mereka-mfe-dropdown-shadow: 0 20px 60px rgb(var(--mereka-color-ink-deep-rgb) / 0.14);\n")
    lines.append("  --mereka-mfe-tab-radius: 999px;\n")
    lines.append("  --mereka-radius-xl: 32px;\n")
    lines.append(f"  --mereka-mfe-compact-card-radius: {token_or_default('--mereka-mfe-compact-card-radius', '20px')};\n")
    lines.append(f"  --mereka-mfe-compact-card-border: {token_or_default('--mereka-mfe-compact-card-border', '1px solid rgb(var(--mereka-color-ink-deep-rgb) / 0.08)')};\n")
    lines.append(f"  --mereka-mfe-compact-card-shadow: {token_or_default('--mereka-mfe-compact-card-shadow', '0 25px 60px rgb(var(--mereka-color-ink-deep-rgb) / 0.08)')};\n")
    lines.append(f"  --mereka-mfe-compact-card-shadow-hover: {token_or_default('--mereka-mfe-compact-card-shadow-hover', '0 18px 48px rgb(var(--mereka-color-ink-deep-rgb) / 0.12)')};\n")
    lines.append(f"  --mereka-mfe-compact-list-gap: {token_or_default('--mereka-mfe-compact-list-gap', '1.5rem')};\n")
    lines.append(f"  --mereka-mfe-compact-vertical-gap: {token_or_default('--mereka-mfe-compact-vertical-gap', '1.25rem')};\n")
    lines.append(f"  --mereka-mfe-course-list-gap: {token_or_default('--mereka-mfe-course-list-gap', '1rem')};\n")
    lines.append(f"  --mereka-mfe-discussions-card-radius: {token_or_default('--mereka-mfe-discussions-card-radius', '22px')};\n")
    lines.append(f"  --mereka-mfe-discussions-card-border: {token_or_default('--mereka-mfe-discussions-card-border', '1px solid rgb(var(--mereka-color-ink-deep-rgb) / 0.09)')};\n")
    # Paragon bridge (canonical v22 token names only)
    lines.append("  --pgn-body-bg: #{$color-neutral-100};\n")
    lines.append("  --pgn-body-color: #{$color-ink-900};\n")
    lines.append("  --pgn-link-color: #{$color-info};\n")
    lines.append("  --pgn-link-hover-color: #{$color-teal};\n")
    lines.append("  --pgn-border-color: #{$color-border};\n")
    lines.append(f"  --pgn-form-control-border-color: {token_or_default('--pgn-form-control-border-color', '#{$color-border}')};\n")
    lines.append(f"  --pgn-btn-color: {token_or_default('--pgn-btn-color', '#{$color-ink-700}')};\n")
    lines.append(f"  --pgn-btn-hover-color: {token_or_default('--pgn-btn-hover-color', '#{$color-ink-900}')};\n")
    lines.append(f"  --pgn-alert-bg: {token_or_default('--pgn-alert-bg', 'var(--mereka-color-white)')};\n")
    lines.append(f"  --pgn-alert-border-color: {token_or_default('--pgn-alert-border-color', 'var(--mereka-mfe-border)')};\n")
    lines.append("  --pgn-border-color-translucent: rgba(26, 22, 35, 0.12);\n")
    lines.append("  --pgn-btn-border-radius: 999px;\n")
    lines.append("  --pgn-spacing-spacer-base: 1rem;\n")
    lines.append("  --pgn-typography-font-size-xs: 0.75rem;\n")
    lines.append("  --pgn-color-white: #fff;\n")
    lines.append("  --pgn-color-black: #000;\n")
    lines.append("  --pgn-color-gray-base: #{$color-ink-900};\n")
    lines.append("  --pgn-color-gray-500: #6b7280;\n")
    lines.append("  --pgn-color-gray-700: #374151;\n")
    lines.append("  --pgn-color-light-200: #e5e7eb;\n")
    lines.append("  --pgn-color-light-500: #6b7280;\n")
    lines.append("  --pgn-color-dark-200: #111827;\n")
    lines.append("  --pgn-color-primary-base: #{$color-magenta};\n")
    lines.append("  --pgn-color-secondary-base: #{$color-teal};\n")
    lines.append("  --pgn-color-success-base: #{$color-success};\n")
    lines.append("  --pgn-color-primary-700: #{$color-burgundy};\n")
    lines.append("  --pgn-color-info-base: #{$color-info};\n")
    lines.append("  --pgn-color-warning-base: #{$color-warning};\n")
    lines.append("  --pgn-color-danger-base: #{$color-danger};\n")
    lines.append("  --pgn-color-info-200: #{$color-info-soft};\n")
    lines.append("  --pgn-color-info-300: #{$color-info-soft};\n")
    lines.append("  --pgn-color-info-500: #{$color-info};\n")
    lines.append("  --pgn-color-info-700: #{$color-info};\n")
    lines.append("  --pgn-color-brand-base: #{$color-magenta};\n")
    lines.append("  --pgn-color-brand-700: #{$color-burgundy};\n")
    lines.append("  --pgn-color-accent-a: #{$color-sky};\n")
    lines.append("  --pgn-color-accent-b: #{$color-info};\n")
    lines.append("  --pgn-color-red: #{$color-danger};\n")
    lines.append("  --pgn-typography-font-family-sans-serif: #{$mereka-body-font};\n")
    lines.append("  --pgn-typography-font-family-base: #{$mereka-body-font};\n")
    lines.append("  --pgn-typography-headings-font-family: #{$mereka-heading-font};\n")
    lines.append(f"  --pgn-typography-font-size-sm: {token_or_default('--pgn-typography-font-size-sm', '0.875rem')};\n")
    lines.append(f"  --pgn-typography-font-size-base: {token_or_default('--pgn-typography-font-size-base', '1rem')};\n")
    lines.append(f"  --pgn-typography-font-size-lg: {token_or_default('--pgn-typography-font-size-lg', '1.125rem')};\n")
    lines.append(f"  --pgn-typography-line-height-sm: {token_or_default('--pgn-typography-line-height-sm', '1.5')};\n")
    lines.append(f"  --pgn-typography-line-height-base: {token_or_default('--pgn-typography-line-height-base', '1.5')};\n")
    lines.append(f"  --pgn-typography-line-height-lg: {token_or_default('--pgn-typography-line-height-lg', '1.5')};\n")
    lines.append(f"  --pgn-spacing-1: {token_or_default('--pgn-spacing-1', token_or_default('--space-1', '0.25rem'))};\n")
    lines.append(f"  --pgn-spacing-2: {token_or_default('--pgn-spacing-2', token_or_default('--space-2', '0.5rem'))};\n")
    lines.append(f"  --pgn-spacing-3: {token_or_default('--pgn-spacing-3', token_or_default('--space-3', '1rem'))};\n")
    lines.append(f"  --pgn-spacing-4: {token_or_default('--pgn-spacing-4', token_or_default('--space-4', '1.5rem'))};\n")
    lines.append(f"  --pgn-spacing-5: {token_or_default('--pgn-spacing-5', token_or_default('--space-5', '3rem'))};\n")
    lines.append(f"  --pgn-spacing-6: {token_or_default('--pgn-spacing-6', token_or_default('--space-6', '4.5rem'))};\n")
    lines.append("  --pgn-spacing-spacer-0: 0;\n")
    lines.append("  --pgn-spacing-spacer-1: 0.25rem;\n")
    lines.append("  --pgn-spacing-spacer-2: 0.5rem;\n")
    lines.append("  --pgn-spacing-spacer-3: 1rem;\n")
    lines.append("  --pgn-spacing-spacer-4: 1.5rem;\n")
    lines.append("  --pgn-spacing-spacer-5: 3rem;\n")
    lines.append("  --pgn-spacing-spacer-6: 4.5rem;\n")
    lines.append(f"  --pgn-size-border-radius-sm: {token_or_default('--pgn-size-border-radius-sm', token_or_default('--radius-sm', '0.25rem'))};\n")
    lines.append(f"  --pgn-size-border-radius-base: {token_or_default('--pgn-size-border-radius-base', token_or_default('--radius-md', '0.375rem'))};\n")
    lines.append(f"  --pgn-size-border-radius-lg: {token_or_default('--pgn-size-border-radius-lg', token_or_default('--radius-lg', '0.425rem'))};\n")
    lines.append(f"  --pgn-elevation-1: {token_or_default('--pgn-elevation-1', token_or_default('--shadow-sm', '0 1px 2px rgba(0, 0, 0, 0.05)'))};\n")
    lines.append(f"  --pgn-elevation-2: {token_or_default('--pgn-elevation-2', token_or_default('--shadow-md', '0 4px 6px rgba(0, 0, 0, 0.1)'))};\n")
    lines.append(f"  --pgn-elevation-3: {token_or_default('--pgn-elevation-3', token_or_default('--shadow-lg', '0 10px 15px rgba(0, 0, 0, 0.1)'))};\n")
    lines.append(f"  --pgn-elevation-4: {token_or_default('--pgn-elevation-4', token_or_default('--shadow-xl', '0 20px 25px rgba(0, 0, 0, 0.15)'))};\n")
    lines.append(f"  --pgn-color-primary-100: {token_or_default('--pgn-color-primary-100', '#{$color-magenta}')};\n")
    lines.append(f"  --pgn-color-primary-200: {token_or_default('--pgn-color-primary-200', '#{$color-magenta}')};\n")
    lines.append(f"  --pgn-color-primary-300: {token_or_default('--pgn-color-primary-300', '#{$color-magenta}')};\n")
    lines.append(f"  --pgn-color-primary-400: {token_or_default('--pgn-color-primary-400', '#{$color-magenta}')};\n")
    lines.append(f"  --pgn-color-primary-500: {token_or_default('--pgn-color-primary-500', '#{$color-magenta}')};\n")
    lines.append(f"  --pgn-zindex-dropdown: {token_or_default('--pgn-zindex-dropdown', '1000')};\n")
    lines.append(f"  --pgn-zindex-modal: {token_or_default('--pgn-zindex-modal', '1050')};\n")
    lines.append(f"  --pgn-zindex-popover: {token_or_default('--pgn-zindex-popover', '1060')};\n")
    lines.append(f"  --pgn-zindex-tooltip: {token_or_default('--pgn-zindex-tooltip', '1070')};\n")
    lines.append(f"  --pgn-transition-base: {token_or_default('--pgn-transition-base', 'all 0.2s ease-in-out 0s normal')};\n")
    lines.append(f"  --pgn-transition-fade: {token_or_default('--pgn-transition-fade', 'opacity 0.15s linear 0s normal')};\n")
    lines.append("  --pgn-elevation-box-shadow-level-2: 0 4px 6px rgba(0, 0, 0, 0.1);\n")
    lines.append("}\n")
    lines.append(SCSS_GEN_END)
    return "".join(lines)

def find_root_block_end(text: str) -> int:
    """Return the index just past the closing '}' of the first :root { } block."""
    root_start = text.find(":root {")
    if root_start == -1:
        return -1
    depth = 0
    i = root_start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1  # index after the closing '}'
        i += 1
    return -1


def update_scss(current: str) -> str:
    generated = build_scss_generated_block()
    # If markers already present, replace between them (subsequent runs)
    if SCSS_GEN_START in current and SCSS_GEN_END in current:
        before = current[:current.index(SCSS_GEN_START)]
        after  = current[current.index(SCSS_GEN_END) + len(SCSS_GEN_END):]
        return before + generated + after
    # First run: bootstrap the markers.
    # The original _tokens.scss layout:
    #   [header comment lines starting with //]
    #   [SCSS var declarations — $name: value; lines]
    #   [Bootstrap overrides — $font-family-sans-serif, $primary, etc. + blank lines]
    #   :root { ... }
    #   [CSS rules: body{}, h1-h6{}, a{}, .btn-primary{}, .card{}]
    #
    # Strategy:
    #   - File header  = leading // comment lines
    #   - Generated    = SCSS vars + :root block (replaced)
    #   - Preserved    = Bootstrap overrides block (between vars and :root)
    #                  + CSS rules (after :root closing })
    root_start = current.find(":root {")
    root_end_idx = find_root_block_end(current)
    if root_start == -1 or root_end_idx == -1:
        # No :root block — prepend generated and keep all existing content
        header = "// Mereka → Paragon token bridge. Keeps the brand palette + typography in one place\n"
        header += "// so MFEs and the legacy LMS/Studio theme remain visually consistent.\n"
        return header + generated + "\n" + current
    # Everything between the SCSS vars section and :root { is the Bootstrap overrides block.
    # Find the end of the last SCSS $variable line before :root by scanning lines.
    lines_before_root = current[:root_start].splitlines(keepends=True)
    # Work backwards to find the blank-line gap before :root { (Bootstrap block ends there)
    # The SCSS vars are lines starting with '$'; after them come Bootstrap vars, then blank, then :root
    # Collect the Bootstrap-override block: lines between the last $color-*/semantic var and :root
    # We detect the boundary: the generated block covers $color-*/semantic vars + font vars;
    # Bootstrap overrides start at $font-family-sans-serif (not covered by generated block).
    #
    # Simplest robust approach: find the blank line separating semantic aliases from Bootstrap vars.
    # In the original file this is the blank line between "$color-danger-soft: $color-pink;" and
    # "$mereka-body-font:". The generated block already covers $mereka-body-font through :root.
    # So Bootstrap overrides = lines from "$font-family-sans-serif" to just before ":root {".
    bootstrap_start_marker = "$font-family-sans-serif:"
    bootstrap_start_idx = current.find(bootstrap_start_marker, 0, root_start)
    if bootstrap_start_idx == -1:
        # No Bootstrap overrides block — just preserve CSS rules after :root
        bootstrap_overrides = ""
    else:
        # Walk back to the start of that line
        line_start = current.rfind("\n", 0, bootstrap_start_idx) + 1
        # Bootstrap block ends at :root { (strip trailing blank lines)
        bootstrap_overrides = current[line_start:root_start].rstrip("\n")
    # CSS rules: everything after the :root closing brace
    after_root = current[root_end_idx:]
    if after_root.startswith("\n"):
        after_root = after_root[1:]
    header = "// Mereka → Paragon token bridge. Keeps the brand palette + typography in one place\n"
    header += "// so MFEs and the legacy LMS/Studio theme remain visually consistent.\n"
    preserved = ""
    if bootstrap_overrides.strip():
        preserved = bootstrap_overrides + "\n\n"
    if after_root.strip():
        preserved += after_root
    return header + generated + "\n" + preserved

# ---------------------------------------------------------------------------
# 3. Generate mereka-design-tokens.css
#    This file is a direct copy of tokens.css (same structure, same content).
#    We regenerate it wholesale — it has no hand-written sections.
# ---------------------------------------------------------------------------

def build_design_tokens_css() -> str:
    lines = []
    lines.append("/**\n")
    lines.append(" * Mereka Design System - CSS Custom Properties\n")
    lines.append(" * DO NOT EDIT — generated from assets/branding/tokens.css\n")
    lines.append(" * Run: scripts/branding/generate-tokens-from-canonical.sh\n")
    lines.append(" * Source: https://www.figma.com/design/jBO2FrTslM4wocrRzwQaPo/mereka.io-Design-System\n")
    lines.append(" */\n")
    lines.append("\n")
    # Emit canonical :root block verbatim (preserves comments + ordering)
    root_match = re.search(r"(:root\s*\{.*?\})", canonical_css, re.S)
    if root_match:
        lines.append(root_match.group(1))
        lines.append("\n")
    return "".join(lines)

# ---------------------------------------------------------------------------
# 4. Generate :root block for mereka-overrides.css files
#    Replaces only the :root { ... } block; preserves header comment and all
#    CSS rules that follow.
# ---------------------------------------------------------------------------

OVERRIDES_GEN_START = "  /* BEGIN GENERATED — DO NOT EDIT (run generate-tokens-from-canonical.sh) */\n"
OVERRIDES_GEN_END   = "  /* END GENERATED */\n"

def build_overrides_root_block() -> str:
    """Build the full :root { ... } block for mereka-overrides.css files."""
    lines = [":root {\n"]
    lines.append("  --mereka-branding-rev: \"2026-02-25-wcag-aa\";\n")
    lines.append("\n")
    lines.append(OVERRIDES_GEN_START)
    lines.append("\n")
    lines.append("  /* Typography */\n")
    lines.append("  --mereka-font-body: \"Poppins\", \"Lato\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Arial, sans-serif;\n")
    lines.append("  --mereka-font-heading: \"Lato\", \"Poppins\", -apple-system, BlinkMacSystemFont, \"Segoe UI\", Arial, sans-serif;\n")
    lines.append("\n")
    lines.append("  /* Palette (source: assets/branding/tokens.css) */\n")
    lines.append("  --mereka-color-ink-900: #000000;\n")
    lines.append("  --mereka-color-ink-700: #4A494A;\n")
    lines.append("  --mereka-color-ink-500: #6B6B6B;\n")
    lines.append("  --mereka-color-ink-300: #AFADB2;\n")
    # Emit canonical colour tokens that map to mereka-* namespace
    for cname, mname in [
        ("--color-teal",     "--mereka-color-teal"),
        ("--color-magenta",  "--mereka-color-magenta"),
        ("--color-magenta-dark", "--mereka-color-magenta-dark"),
        ("--color-blue",     "--mereka-color-blue"),
        ("--color-sky",      "--mereka-color-sky"),
    ]:
        if cname in tokens:
            lines.append(f"  {mname}: {tokens[cname]};\n")
    lines.append("  --mereka-color-surface-primary: #FBFAFB;\n")
    lines.append("  --mereka-color-surface-secondary: #F5F5F5;\n")
    lines.append("  --mereka-color-border: #DDDDDE;\n")
    lines.append("  --mereka-color-border-strong: #7B7B7C;\n")
    lines.append("\n")
    lines.append("  /* Semantics */\n")
    lines.append("  --mereka-color-info: var(--mereka-color-blue);\n")
    lines.append("  --mereka-color-info-soft: var(--mereka-color-sky);\n")
    # Emit semantic colours from canonical source
    for cname, mname in [
        ("--color-forest",   "--mereka-color-success"),
        ("--color-gold",     "--mereka-color-warning"),
        ("--color-burgundy", "--mereka-color-danger"),
        ("--color-pink",     "--mereka-color-danger-soft"),
    ]:
        if cname in tokens:
            lines.append(f"  {mname}: {tokens[cname]};\n")
    lines.append("\n")
    lines.append("  /* Effects */\n")
    lines.append("  --mereka-shadow-card: 0 20px 60px rgba(26, 22, 35, 0.08);\n")
    lines.append("  --mereka-gradient-primary: linear-gradient(\n")
    lines.append("    135deg,\n")
    lines.append("    var(--mereka-color-teal) 0%,\n")
    lines.append("    var(--mereka-color-blue) 100%\n")
    lines.append("  );\n")
    lines.append("\n")
    lines.append("  /* Paragon bridge (MFEs) - canonical v22 token names only */\n")
    lines.append("  --pgn-body-bg: var(--mereka-color-surface-primary);\n")
    lines.append("  --pgn-body-color: var(--mereka-color-ink-900);\n")
    lines.append("  --pgn-link-color: var(--mereka-color-info);\n")
    lines.append("  --pgn-link-hover-color: var(--mereka-color-teal);\n")
    lines.append("  --pgn-border-color: var(--mereka-color-border);\n")
    lines.append(f"  --pgn-form-control-border-color: {token_or_default('--pgn-form-control-border-color', 'var(--mereka-color-border)')};\n")
    lines.append("  --pgn-border-color-translucent: rgba(26, 22, 35, 0.12);\n")
    lines.append("  --pgn-btn-border-radius: 999px;\n")
    lines.append("  --pgn-spacing-spacer-base: 1rem;\n")
    lines.append("  --pgn-typography-font-size-xs: 0.75rem;\n")
    lines.append("  --pgn-color-white: #ffffff;\n")
    lines.append("  --pgn-color-black: #000000;\n")
    lines.append("  --pgn-color-gray-base: var(--mereka-color-ink-900);\n")
    lines.append("  --pgn-color-gray-500: #6b7280;\n")
    lines.append("  --pgn-color-gray-700: #374151;\n")
    lines.append("  --pgn-color-light-200: #e5e7eb;\n")
    lines.append("  --pgn-color-light-500: #6b7280;\n")
    lines.append("  --pgn-color-dark-200: #111827;\n")
    lines.append("  --pgn-color-primary-base: var(--mereka-color-magenta);\n")
    lines.append("  --pgn-color-secondary-base: var(--mereka-color-teal);\n")
    lines.append("  --pgn-color-success-base: var(--mereka-color-success);\n")
    lines.append("  --pgn-color-primary-400: var(--mereka-color-magenta);\n")
    lines.append("  --pgn-color-primary-500: var(--mereka-color-magenta);\n")
    lines.append("  --pgn-color-primary-700: var(--mereka-color-danger);\n")
    lines.append("  --pgn-color-info-base: var(--mereka-color-info);\n")
    lines.append("  --pgn-color-warning-base: var(--mereka-color-warning);\n")
    lines.append("  --pgn-color-danger-base: var(--mereka-color-danger);\n")
    lines.append("  --pgn-color-info-200: var(--mereka-color-info-soft);\n")
    lines.append("  --pgn-color-info-300: var(--mereka-color-info-soft);\n")
    lines.append("  --pgn-color-info-500: var(--mereka-color-info);\n")
    lines.append("  --pgn-color-info-700: var(--mereka-color-info);\n")
    lines.append("  --pgn-color-brand-base: var(--mereka-color-magenta);\n")
    lines.append("  --pgn-color-brand-700: var(--mereka-color-danger);\n")
    lines.append("  --pgn-color-accent-a: var(--mereka-color-sky);\n")
    lines.append("  --pgn-color-accent-b: var(--mereka-color-info);\n")
    lines.append("  --pgn-color-red: var(--mereka-color-danger);\n")
    lines.append("  --pgn-typography-font-family-sans-serif: var(--mereka-font-body);\n")
    lines.append("  --pgn-typography-font-family-base: var(--mereka-font-body);\n")
    lines.append("  --pgn-typography-headings-font-family: var(--mereka-font-heading);\n")
    lines.append(f"  --pgn-typography-font-size-sm: {token_or_default('--pgn-typography-font-size-sm', '0.875rem')};\n")
    lines.append(f"  --pgn-typography-font-size-base: {token_or_default('--pgn-typography-font-size-base', '1rem')};\n")
    lines.append(f"  --pgn-typography-font-size-lg: {token_or_default('--pgn-typography-font-size-lg', '1.125rem')};\n")
    lines.append(f"  --pgn-typography-line-height-sm: {token_or_default('--pgn-typography-line-height-sm', '1.5')};\n")
    lines.append(f"  --pgn-typography-line-height-base: {token_or_default('--pgn-typography-line-height-base', '1.5')};\n")
    lines.append(f"  --pgn-typography-line-height-lg: {token_or_default('--pgn-typography-line-height-lg', '1.5')};\n")
    lines.append(f"  --pgn-spacing-1: {token_or_default('--pgn-spacing-1', '0.25rem')};\n")
    lines.append(f"  --pgn-spacing-2: {token_or_default('--pgn-spacing-2', '0.5rem')};\n")
    lines.append(f"  --pgn-spacing-3: {token_or_default('--pgn-spacing-3', '1rem')};\n")
    lines.append(f"  --pgn-spacing-4: {token_or_default('--pgn-spacing-4', '1.5rem')};\n")
    lines.append(f"  --pgn-spacing-5: {token_or_default('--pgn-spacing-5', '3rem')};\n")
    lines.append(f"  --pgn-spacing-6: {token_or_default('--pgn-spacing-6', '4.5rem')};\n")
    lines.append("  --pgn-spacing-spacer-0: 0;\n")
    lines.append("  --pgn-spacing-spacer-1: 0.25rem;\n")
    lines.append("  --pgn-spacing-spacer-2: 0.5rem;\n")
    lines.append("  --pgn-spacing-spacer-3: 1rem;\n")
    lines.append("  --pgn-spacing-spacer-4: 1.5rem;\n")
    lines.append("  --pgn-spacing-spacer-5: 3rem;\n")
    lines.append("  --pgn-spacing-spacer-6: 4.5rem;\n")
    lines.append(f"  --pgn-size-border-radius-sm: {token_or_default('--pgn-size-border-radius-sm', '0.25rem')};\n")
    lines.append(f"  --pgn-size-border-radius-base: {token_or_default('--pgn-size-border-radius-base', '0.375rem')};\n")
    lines.append(f"  --pgn-size-border-radius-lg: {token_or_default('--pgn-size-border-radius-lg', '0.425rem')};\n")
    lines.append("  --pgn-elevation-1: var(--shadow-sm);\n")
    lines.append("  --pgn-elevation-2: var(--shadow-md);\n")
    lines.append("  --pgn-elevation-3: var(--shadow-lg);\n")
    lines.append("  --pgn-elevation-4: var(--shadow-xl);\n")
    lines.append(f"  --pgn-color-primary-100: {token_or_default('--pgn-color-primary-100', 'var(--mereka-color-magenta)')};\n")
    lines.append(f"  --pgn-color-primary-200: {token_or_default('--pgn-color-primary-200', 'var(--mereka-color-magenta)')};\n")
    lines.append(f"  --pgn-color-primary-300: {token_or_default('--pgn-color-primary-300', 'var(--mereka-color-magenta)')};\n")
    lines.append(f"  --pgn-color-primary-400: {token_or_default('--pgn-color-primary-400', 'var(--mereka-color-magenta)')};\n")
    lines.append(f"  --pgn-color-primary-500: {token_or_default('--pgn-color-primary-500', 'var(--mereka-color-magenta)')};\n")
    lines.append("  --pgn-zindex-dropdown: 1000;\n")
    lines.append("  --pgn-zindex-modal: 1050;\n")
    lines.append("  --pgn-zindex-popover: 1060;\n")
    lines.append("  --pgn-zindex-tooltip: 1070;\n")
    lines.append(f"  --pgn-transition-base: {token_or_default('--pgn-transition-base', 'all 0.2s ease-in-out 0s normal')};\n")
    lines.append(f"  --pgn-transition-fade: {token_or_default('--pgn-transition-fade', 'opacity 0.15s linear 0s normal')};\n")
    lines.append("  --pgn-elevation-box-shadow-level-2: var(--shadow-md);\n")
    lines.append("\n")
    lines.append("  /*\n")
    lines.append("    Design-system aliases\n")
    lines.append("    Source of truth: `assets/branding/tokens.css` (synced from bbbi-mereka-brand-assets).\n")
    lines.append("    We alias the most-used tokens so external apps can speak the same language.\n")
    lines.append("  */\n")
    lines.append("  --color-black: var(--mereka-color-ink-900);\n")
    lines.append("  --color-white: #ffffff;\n")
    lines.append("  --color-teal: var(--mereka-color-teal);\n")
    lines.append("  --color-magenta: var(--mereka-color-magenta);\n")
    lines.append("  --color-blue: var(--mereka-color-blue);\n")
    lines.append("  --color-burgundy: var(--mereka-color-danger);\n")
    lines.append("  --color-pink: var(--mereka-color-danger-soft);\n")
    lines.append("  --color-sky: var(--mereka-color-sky);\n")
    lines.append("  --color-gold: var(--mereka-color-warning);\n")
    lines.append("  --color-forest: var(--mereka-color-success);\n")
    lines.append("\n")
    lines.append("  --color-success: var(--mereka-color-success);\n")
    lines.append("  --color-success-light: #8fbec2;\n")
    lines.append("  --color-warning: var(--mereka-color-warning);\n")
    lines.append("  --color-warning-dark: #e18437;\n")
    lines.append("  --color-error: var(--mereka-color-danger);\n")
    lines.append("  --color-error-light: var(--mereka-color-danger-soft);\n")
    lines.append("  --color-info: var(--mereka-color-info);\n")
    lines.append("  --color-info-light: var(--mereka-color-info-soft);\n")
    lines.append("\n")
    lines.append("  --font-heading: \"Lato\", sans-serif;\n")
    lines.append("  --font-body: \"Poppins\", sans-serif;\n")
    lines.append("\n")
    # Emit radius tokens from canonical
    for name in ["--radius-none", "--radius-sm", "--radius-md", "--radius-lg",
                 "--radius-xl", "--radius-full"]:
        if name in tokens:
            lines.append(f"  {name}: {tokens[name]};\n")
    lines.append("\n")
    # Emit shadow tokens from canonical
    for name in ["--shadow-sm", "--shadow-md", "--shadow-lg", "--shadow-xl"]:
        if name in tokens:
            lines.append(f"  {name}: {tokens[name]};\n")
    lines.append("\n")
    lines.append(OVERRIDES_GEN_END)
    lines.append("}\n")
    return "".join(lines)


def update_overrides(current: str) -> str:
    """Replace the :root { ... } block, preserving header comment and trailing CSS."""
    # Find the header comment (everything before :root)
    root_start = current.find(":root {")
    if root_start == -1:
        # No :root block — prepend generated block
        return build_overrides_root_block() + "\n" + current
    header = current[:root_start]
    # Find the matching closing brace of the :root block
    # We look for the first } on its own line after :root
    rest = current[root_start:]
    # Find end of :root block — first line that is just '}'
    root_end_offset = rest.find("\n}\n")
    if root_end_offset == -1:
        root_end_offset = rest.rfind("\n}")
    if root_end_offset == -1:
        # Fallback: replace everything
        return header + build_overrides_root_block()
    after_root = rest[root_end_offset + 3:]  # skip '\n}\n'
    return header + build_overrides_root_block() + after_root


# ---------------------------------------------------------------------------
# 5. Apply updates (or check for drift)
# ---------------------------------------------------------------------------

def write_or_check(path: Path, current: str, new: str, label: str) -> bool:
    """Return True if there is a diff. Write if not check_only."""
    if current == new:
        print(f"  OK (no change): {label}")
        return False
    if check_only:
        print(f"  DRIFT: {label} — run generate-tokens-from-canonical.sh to fix")
        return True
    path.write_text(new, encoding="utf-8")
    print(f"  UPDATED: {label}")
    return False

drift_detected = False

print("=== Token Generation Pipeline ===\n")

# SCSS bridge
scss_current = scss_path.read_text(encoding="utf-8")
scss_new = update_scss(scss_current)
if write_or_check(scss_path, scss_current, scss_new, scss_path.relative_to(Path(sys.argv[1]).parent.parent.parent)):
    drift_detected = True

# mereka-design-tokens.css (full regeneration)
design_tokens_current = design_tokens_path.read_text(encoding="utf-8")
design_tokens_new = build_design_tokens_css()
if write_or_check(design_tokens_path, design_tokens_current, design_tokens_new,
                  design_tokens_path.relative_to(Path(sys.argv[1]).parent.parent.parent)):
    drift_detected = True

# mereka-overrides.css — common, lms, cms
for p in (common_path, lms_path, cms_path):
    current = p.read_text(encoding="utf-8")
    updated = update_overrides(current)
    if write_or_check(p, current, updated, p.relative_to(Path(sys.argv[1]).parent.parent.parent)):
        drift_detected = True

print("")
if drift_detected:
    print("FAIL: token drift detected — run ./scripts/branding/generate-tokens-from-canonical.sh")
    sys.exit(1)
else:
    action = "checked" if check_only else "regenerated"
    print(f"PASS: all token layers {action} successfully")
PY

SYNC_JSON_TOKENS="${SYNC_JSON_TOKENS:-1}"
SYNC_SCRIPT="$REPO_ROOT/scripts/branding/sync-tokens-to-json.sh"
if [[ "$SYNC_JSON_TOKENS" == "1" && -x "$SYNC_SCRIPT" ]]; then
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    "$SYNC_SCRIPT" --check
  else
    "$SYNC_SCRIPT" --apply
  fi
fi
