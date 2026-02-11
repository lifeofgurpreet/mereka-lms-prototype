#!/usr/bin/env bash
# @covers AC-007, AC-012
# @spec: branding-system_spec.md
# Verify the runtime override CSS contains required brand signals.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

COMMON_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
LMS_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
CMS_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"

BRANDING_LEVEL="${BRANDING_LEVEL:-core}" # core|deep
if [[ "$BRANDING_LEVEL" != "core" && "$BRANDING_LEVEL" != "deep" ]]; then
  echo "Invalid BRANDING_LEVEL: ${BRANDING_LEVEL} (expected core|deep)" >&2
  exit 1
fi

failures=0

require_file() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $path)"
    failures=1
  fi
}

require_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi
  if grep -q -- "$needle" "$path"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $needle)"
    failures=1
  fi
}

echo "Verifying runtime override CSS..."
echo "Branding level: ${BRANDING_LEVEL}"
echo ""

require_file "Common overrides CSS" "$COMMON_CSS"
require_file "LMS overrides CSS" "$LMS_CSS"
require_file "CMS overrides CSS" "$CMS_CSS"

if [[ -f "$COMMON_CSS" && -f "$LMS_CSS" && -f "$CMS_CSS" ]]; then
  if cmp -s "$COMMON_CSS" "$LMS_CSS"; then
    echo "  ✓ Common/LMS overrides are identical"
  else
    echo "  ✗ Common/LMS overrides drifted (files differ)"
    failures=1
  fi
  if cmp -s "$COMMON_CSS" "$CMS_CSS"; then
    echo "  ✓ Common/CMS overrides are identical"
  else
    echo "  ✗ Common/CMS overrides drifted (files differ)"
    failures=1
  fi
fi

echo ""
echo "Required brand signals..."
require_contains "Has font-face Poppins" "$COMMON_CSS" 'font-family: "Poppins"'
require_contains "Has font-face Lato" "$COMMON_CSS" 'font-family: "Lato"'
require_contains "Exports branding revision marker" "$COMMON_CSS" "--mereka-branding-rev"
require_contains "Exports token --mereka-color-teal" "$COMMON_CSS" "--mereka-color-teal"
require_contains "Exports token --mereka-color-magenta" "$COMMON_CSS" "--mereka-color-magenta"
require_contains "Exports token --mereka-font-body" "$COMMON_CSS" "--mereka-font-body"
require_contains "Exports Paragon token --pgn-color-primary" "$COMMON_CSS" "--pgn-color-primary"
require_contains "Footer styles present" "$COMMON_CSS" ".mereka-footer"
require_contains "Footer logo size cap present" "$COMMON_CSS" ".mereka-footer .footer-brand img"
require_contains "Footer logo width is constrained" "$COMMON_CSS" "width: 120px;"

if [[ "$BRANDING_LEVEL" == "deep" ]]; then
  echo ""
  echo "Deep surface signals..."
  require_contains "Course listing styling present" "$COMMON_CSS" ".courses-listing"
  require_contains "Courseware styling present" "$COMMON_CSS" ".courseware"
  require_contains "Sequence nav styling present" "$COMMON_CSS" ".sequence-nav"
  require_contains "XBlock styling present" "$COMMON_CSS" ".xblock"
  require_contains "XBlock discussion styling present" "$COMMON_CSS" ".discussion-module"
  require_contains "XBlock video styling present" "$COMMON_CSS" ".video"
  require_contains "Dashboard notice styling present" "$COMMON_CSS" ".dashboard .notice"
  require_contains "Studio wrapper styling present" "$COMMON_CSS" ".wrapper-content"
  require_contains "Studio create-course CTA styling present" "$COMMON_CSS" ".action-create-course"
  require_contains "Studio create-library CTA styling present" "$COMMON_CSS" ".action-create-library"
  require_contains "Studio outline card styling present" "$COMMON_CSS" ".outline-complex"
  require_contains "Studio outline title typography present" "$COMMON_CSS" ".outline-item-title"
  require_contains "Studio outline action pill styling present" "$COMMON_CSS" ".action-button"
  require_contains "Studio add-component CTA styling present" "$COMMON_CSS" ".add-xblock-component"
fi

echo ""
if [[ $failures -eq 0 ]]; then
  echo "✓ Runtime override CSS checks passed."
  exit 0
fi

echo "✗ Runtime override CSS checks failed."
echo ""
echo "Fixes:"
echo "  1. Ensure deep styles are shipped in: infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
echo "  2. Keep LMS copy identical: infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
echo "  3. Keep CMS copy identical: infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
exit 1
