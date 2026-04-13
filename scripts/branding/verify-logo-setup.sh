#!/usr/bin/env bash
# @covers AC-001
# @spec: branding-system_spec.md
# Verify that footer/header logo files are correctly configured
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_MODE="${VERIFY_LOGO_SETUP_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_LOGO_SETUP_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      scripts/branding/verify-logo-setup.sh|\
      assets/branding/logo-horizontal.png|\
      assets/branding/logo-horizontal-white.png|\
      assets/branding/logo-square.png|\
      infrastructure/tutor/themes/mereka/common/static/images/logo-horizontal.png|\
      infrastructure/tutor/themes/mereka/common/static/images/logo-horizontal-white.png|\
      infrastructure/tutor/themes/mereka/common/static/images/logo-square.png|\
      infrastructure/tutor/themes/mereka/mfe/images/logo-horizontal.png|\
      infrastructure/tutor/themes/mereka/mfe/images/logo-horizontal-white.png|\
      infrastructure/tutor/themes/mereka/mfe/images/logo-square.png|\
      infrastructure/tutor/themes/mereka/lms/static/images/logo-horizontal.png|\
      infrastructure/tutor/themes/mereka/lms/static/images/logo-horizontal-white.png|\
      infrastructure/tutor/themes/mereka/lms/static/images/logo-square.png|\
      infrastructure/tutor/themes/mereka/cms/static/images/logo-horizontal.png|\
      infrastructure/tutor/themes/mereka/cms/static/images/logo-horizontal-white.png|\
      infrastructure/tutor/themes/mereka/cms/static/images/logo-square.png|\
      deploy/k8s/base/apps/openedx/settings/lms/production.py|\
      infrastructure/tutor/themes/mereka/lms/templates/footer.html|\
      infrastructure/tutor/themes/mereka/lms/templates/header/brand.html)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-logo-setup (scope skip: no logo-setup authority changes)"
  exit 0
fi

echo "Verifying Mereka Academy logo setup..."
echo ""

# Check if source logo files exist
echo "1. Checking source logo files in assets/branding/..."
MISSING_SOURCE=0
for logo in logo-horizontal.png logo-horizontal-white.png logo-square.png; do
  if [[ -f "$REPO_ROOT/assets/branding/$logo" ]]; then
    echo "  ✓ $logo exists"
  else
    echo "  ✗ $logo MISSING"
    MISSING_SOURCE=1
  fi
done

if [[ $MISSING_SOURCE -eq 1 ]]; then
  echo ""
  echo "ERROR: Missing source logo files. Please add them to assets/branding/"
  exit 1
fi

echo ""
echo "2. Checking logo files in theme directories..."
MISSING_THEME=0
for dir in common/static/images mfe/images lms/static/images cms/static/images; do
  echo "  Checking $dir..."
  THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/$dir"
  if [[ ! -d "$THEME_DIR" ]]; then
    echo "    ✗ Directory does not exist"
    MISSING_THEME=1
    continue
  fi

  for logo in logo-horizontal.png logo-horizontal-white.png logo-square.png; do
    if [[ -f "$THEME_DIR/$logo" ]]; then
      echo "    ✓ $logo"
    else
      echo "    ✗ $logo MISSING"
      MISSING_THEME=1
    fi
  done
done

if [[ $MISSING_THEME -eq 1 ]]; then
  echo ""
  echo "ERROR: Missing logo files in theme directories."
  echo "Run: make branding-sync"
  exit 1
fi

echo ""
echo "3. Checking MFE_CONFIG logo URLs in LMS settings..."
SETTINGS_FILE="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
if [[ -f "$SETTINGS_FILE" ]]; then
  if grep -q 'LOGO_URL.*logo-horizontal\.\(png\|svg\)' "$SETTINGS_FILE"; then
    echo "  ✓ LOGO_URL points to logo-horizontal asset"
  else
    echo "  ✗ LOGO_URL does not reference logo-horizontal.{png,svg}"
    MISSING_THEME=1
  fi

  if grep -q 'LOGO_WHITE_URL.*logo-horizontal-white\.\(png\|svg\)' "$SETTINGS_FILE"; then
    echo "  ✓ LOGO_WHITE_URL points to logo-horizontal-white asset"
  else
    echo "  ✗ LOGO_WHITE_URL does not reference logo-horizontal-white.{png,svg}"
    MISSING_THEME=1
  fi
else
  echo "  ✗ LMS production settings file not found"
  MISSING_THEME=1
fi

echo ""
echo "4. Checking footer template references..."
FOOTER_TEMPLATE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [[ -f "$FOOTER_TEMPLATE" ]]; then
  if grep -q "logo.png" "$FOOTER_TEMPLATE"; then
    echo "  ✓ Footer template references logo.png"
  else
    echo "  ✗ Footer template does not reference logo.png"
    MISSING_THEME=1
  fi
else
  echo "  ✗ Footer template not found"
  MISSING_THEME=1
fi

HEADER_TEMPLATE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/header/brand.html"
if [[ -f "$HEADER_TEMPLATE" ]]; then
  if grep -q "logo.png" "$HEADER_TEMPLATE"; then
    echo "  ✓ Header brand template references logo.png"
  else
    echo "  ✗ Header brand template does not reference logo.png"
    MISSING_THEME=1
  fi
else
  echo "  ✗ Header brand template not found"
  MISSING_THEME=1
fi

echo ""
if [[ $MISSING_THEME -eq 0 ]]; then
  echo "✓ All logo files and configurations are in place!"
  echo ""
  echo "Next steps:"
  echo "  1. Apply Tutor patches: ./infrastructure/tutor/apply-patches.sh"
  echo "  2. Rebuild images: tutor images build openedx && tutor images build mfe"
  echo "  3. Restart services: tutor local restart (or kubectl rollout restart)"
  echo "  4. Run collectstatic: tutor local run lms ./manage.py lms collectstatic --noinput"
  exit 0
else
  echo "✗ Some logo files or configurations are missing."
  echo ""
  echo "To fix:"
  echo "  1. Run: make branding-sync"
  echo "  2. Check that logo files exist in assets/branding/"
  exit 1
fi
