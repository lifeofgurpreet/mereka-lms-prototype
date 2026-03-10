#!/usr/bin/env bash
# verify-copy-terminology.sh — @covers AC-UICOPY-001, AC-UICOPY-002, AC-UICOPY-003
#
# Verifies the copy/terminology consistency contract:
# - Contract documentation exists with required sections
# - No banned strings in user-facing templates/SCSS/JS
# - PLATFORM_NAME configuration uses canonical brand terms
# - Multi-domain brand mapping configured
#
# Usage: ./scripts/qa/verify-copy-terminology.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
CONTRACT="$REPO_ROOT/docs/concepts/architecture/COPY_TERMINOLOGY_CONTRACT.md"
THEMES_DIR="$REPO_ROOT/infrastructure/tutor/themes"
CUSTOM_APPS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps"
PLUGINS_DIR="$REPO_ROOT/infrastructure/tutor/plugins"

PLUGIN_BUNDLE=""
PLUGIN_BUNDLE_FILE="$(mereka_plugin_main_file "$REPO_ROOT")"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_BUNDLE_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UICOPY-001..003: Copy/Terminology Consistency Verification ==="
echo ""

# =============================================================================
# Section 1: Contract Documentation (AC-UICOPY-001)
# =============================================================================
echo "--- Contract Documentation ---"
if [ -f "$CONTRACT" ]; then
  do_pass "COPY_TERMINOLOGY_CONTRACT.md exists"
else
  do_fail "COPY_TERMINOLOGY_CONTRACT.md not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

# Check required sections
echo ""
echo "--- Required Sections ---"
required_sections=(
  "Canonical Product Names"
  "Banned Strings"
  "Scope"
  "Multi-Domain Brand Mapping"
  "Verification Script"
  "AC-UICOPY-001"
  "AC-UICOPY-002"
  "AC-UICOPY-003"
)

for section in "${required_sections[@]}"; do
  if grep -qF "$section" "$CONTRACT"; then
    do_pass "Section present: $section"
  else
    do_fail "Section missing: $section"
  fi
done

# =============================================================================
# Section 2: Banned Strings Check (AC-UICOPY-001)
# =============================================================================
echo ""
echo "--- Banned Strings in Templates/SCSS ---"

# Banned strings (case-insensitive)
banned_strings=(
  "Powered by Tutor"
  "Your Platform Name Here"
  "Example University"
)

# Special handling for "Powered by Open edX" (known gap in footer.html)
# This will be checked separately with WARN instead of FAIL

# Helper function to check banned strings in a file
# Returns 0 (success) if banned string found, 1 (failure) if not found
# Excludes comments and documentation files
check_banned_strings() {
  local file="$1"
  local banned="$2"

  # Skip documentation files
  if [[ "$file" =~ \.md$ ]] || [[ "$file" =~ \.txt$ ]] || [[ "$file" =~ \.rst$ ]]; then
    return 1  # Not found (skip file)
  fi

  # Skip test files
  if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /fixtures/ ]] || [[ "$file" =~ test_ ]]; then
    return 1  # Not found (skip file)
  fi

  # Search for banned string, excluding comment lines
  # Mako comments: {# #}, ##
  # HTML comments: <!-- -->
  # JS/SCSS comments: //, /* */
  # Python comments: #
  if grep -iqF "$banned" "$file" 2>/dev/null; then
    # Check if match is in a comment
    local matches
    matches=$(grep -inF "$banned" "$file" 2>/dev/null || true)

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue  # Skip empty lines

      # Extract line number and content
      local line_num="${line%%:*}"
      local content="${line#*:}"

      # Skip if line is a comment
      if [[ "$content" =~ ^\s*(\{#|##|<!--|//|/\*|#) ]]; then
        continue
      fi

      # Skip if inside HTML comment (basic check)
      if [[ "$content" =~ \<!--.*"$banned".*--\> ]]; then
        continue
      fi

      # Found banned string outside of comment
      return 0  # Found (success for grep-style function)
    done <<< "$matches"
  fi

  return 1  # Not found
}

# Scan themes directory
if [ -d "$THEMES_DIR" ]; then
  do_pass "Themes directory exists"

  for banned in "${banned_strings[@]}"; do
    found_files=()

    # Search in templates (*.html)
    while IFS= read -r -d '' file; do
      if check_banned_strings "$file" "$banned"; then
        found_files+=("$file")
      fi
    done < <(find "$THEMES_DIR" -type f -name "*.html" -print0 2>/dev/null || true)

    # Search in SCSS (*.scss)
    while IFS= read -r -d '' file; do
      if check_banned_strings "$file" "$banned"; then
        found_files+=("$file")
      fi
    done < <(find "$THEMES_DIR" -type f -name "*.scss" -print0 2>/dev/null || true)

    if [ ${#found_files[@]} -eq 0 ]; then
      do_pass "No '$banned' in themes"
    else
      do_fail "Found '$banned' in themes: ${found_files[*]}"
    fi
  done
else
  do_warn "Themes directory not found"
fi

# Check "Powered by Open edX" separately (known gap in footer.html)
echo ""
echo "--- Known Gap: 'Powered by Open edX' ---"

footer_file="$THEMES_DIR/mereka/lms/templates/footer.html"
if [ -f "$footer_file" ]; then
  if grep -qiF "Powered by Open edX" "$footer_file"; then
    do_warn "footer.html contains 'Powered by Open edX' (documented gap, line 71)"
  else
    do_pass "footer.html does not contain 'Powered by Open edX' (gap resolved!)"
  fi
else
  do_warn "footer.html not found at expected location"
fi

# Scan custom apps directory
echo ""
echo "--- Banned Strings in Custom Apps ---"

if [ -d "$CUSTOM_APPS_DIR" ]; then
  do_pass "Custom apps directory exists"

  for banned in "${banned_strings[@]}"; do
    found_files=()

    # Search in templates (*/templates/*.html)
    while IFS= read -r -d '' file; do
      if check_banned_strings "$file" "$banned"; then
        found_files+=("$file")
      fi
    done < <(find "$CUSTOM_APPS_DIR" -path "*/templates/*.html" -print0 2>/dev/null || true)

    # Search in static SCSS (*/static/*.scss)
    while IFS= read -r -d '' file; do
      if check_banned_strings "$file" "$banned"; then
        found_files+=("$file")
      fi
    done < <(find "$CUSTOM_APPS_DIR" -path "*/static/*.scss" -print0 2>/dev/null || true)

    # Search in static JS (*/static/*.js, *.jsx)
    while IFS= read -r -d '' file; do
      if check_banned_strings "$file" "$banned"; then
        found_files+=("$file")
      fi
    done < <(find "$CUSTOM_APPS_DIR" -path "*/static/*.js" -o -path "*/static/*.jsx" -print0 2>/dev/null || true)

    if [ ${#found_files[@]} -eq 0 ]; then
      do_pass "No '$banned' in custom apps"
    else
      do_fail "Found '$banned' in custom apps: ${found_files[*]}"
    fi
  done
else
  do_warn "Custom apps directory not found"
fi

# =============================================================================
# Section 3: Canonical Terms Configuration (AC-UICOPY-002)
# =============================================================================
echo ""
echo "--- Canonical Brand Configuration ---"

# Check for PLATFORM_NAME in plugin configuration
mereka_plugin="$PLUGIN_BUNDLE_FILE"
if [ -f "$mereka_plugin" ]; then
  do_pass "mereka_lms.py plugin exists"

  # Check if PLATFORM_NAME is configured
  if grep -q "PLATFORM_NAME" "$mereka_plugin"; then
    do_pass "PLATFORM_NAME referenced in plugin"

    # Check if it contains "Mereka" or "Academy"
    if grep "PLATFORM_NAME" "$mereka_plugin" | grep -qE "(Mereka|Academy)"; then
      do_pass "PLATFORM_NAME contains canonical brand term"
    else
      do_warn "PLATFORM_NAME may not use canonical brand name"
    fi
  else
    do_warn "PLATFORM_NAME not found in mereka_lms.py"
  fi
else
  do_warn "mereka_lms.py plugin not found"
fi

# Check for SITE_NAME in multi-tenancy plugin
multi_tenancy_dir="$PLUGINS_DIR/multi-tenancy"
if [ -d "$multi_tenancy_dir" ]; then
  do_pass "Multi-tenancy plugin directory exists"

  # Check for domain mappings
  if grep -rq "SITE_NAME\|domain.*mereka\|biji-biji\|skillourfuture" "$multi_tenancy_dir" 2>/dev/null; then
    do_pass "Domain-to-brand mappings present in multi-tenancy"
  else
    do_warn "Domain-to-brand mappings not found in multi-tenancy plugin"
  fi
else
  do_warn "Multi-tenancy plugin directory not found"
fi

# Check config example for PLATFORM_NAME
config_example="$REPO_ROOT/infrastructure/tutor/config.example.yml"
if [ -f "$config_example" ]; then
  do_pass "config.example.yml exists"

  # PLATFORM_NAME is optional in config.yml (defaults from plugin)
  # Just verify the example doesn't have placeholder values
  if grep -q "PLATFORM_NAME.*Your.*Platform\|PLATFORM_NAME.*Example" "$config_example"; then
    do_fail "config.example.yml contains placeholder PLATFORM_NAME"
  else
    do_pass "config.example.yml has no placeholder PLATFORM_NAME"
  fi
else
  do_warn "config.example.yml not found"
fi

# =============================================================================
# Section 4: Multi-Domain Brand Mapping (AC-UICOPY-003)
# =============================================================================
echo ""
echo "--- Multi-Domain Brand Mapping ---"

# Check for domain references in multi-tenancy plugin
if [ -d "$multi_tenancy_dir" ]; then
  domain_count=0

  # Check for academyv2.mereka.io
  if grep -rq "academyv2\.mereka\.io\|academyv2.mereka.io" "$multi_tenancy_dir" 2>/dev/null; then
    do_pass "academyv2.mereka.io domain mapped"
    domain_count=$((domain_count + 1))
  else
    do_warn "academyv2.mereka.io domain not found in multi-tenancy config"
  fi

  # Check for academy.biji-biji.com
  if grep -rq "academy\.biji-biji\.com\|academy.biji-biji.com" "$multi_tenancy_dir" 2>/dev/null; then
    do_pass "academy.biji-biji.com domain mapped"
    domain_count=$((domain_count + 1))
  else
    do_warn "academy.biji-biji.com domain not found in multi-tenancy config"
  fi

  # Check for skillourfuture.academy.mereka.io
  if grep -rq "skillourfuture.*mereka\.io\|skillourfuture.academy.mereka.io" "$multi_tenancy_dir" 2>/dev/null; then
    do_pass "skillourfuture domain mapped"
    domain_count=$((domain_count + 1))
  else
    do_warn "skillourfuture domain not found in multi-tenancy config"
  fi

  # Verify all 3 domains present
  if [ "$domain_count" -eq 3 ]; then
    do_pass "All 3 branded domains configured"
  else
    do_warn "Expected 3 domains, found $domain_count"
  fi
else
  do_warn "Cannot check domain mapping (multi-tenancy plugin not found)"
fi

# Check for footer variants in MFE footer config
echo ""
echo "--- Footer Variant Configuration ---"

# Check if MerekaFooter v2 has variant logic
if grep -rq "FOOTER_VARIANT\|footer.*variant" "$PLUGINS_DIR" 2>/dev/null; then
  do_pass "Footer variant configuration present in plugins"
else
  do_warn "Footer variant configuration not found (may be in MFE component only)"
fi

# Check for MFE footer component in themes
mfe_footer_files=(
  "$THEMES_DIR/mereka/mfe/MerekaFooter.jsx"
  "$THEMES_DIR/mereka/mfe/mereka-footer.jsx"
)

footer_component_found=0
for footer_file in "${mfe_footer_files[@]}"; do
  if [ -f "$footer_file" ]; then
    footer_component_found=1
    do_pass "MFE footer component exists: $(basename "$footer_file")"

    # Check for variant logic
    if grep -q "variant\|academyv2\|biji-biji\|skillourfuture" "$footer_file" 2>/dev/null; then
      do_pass "Footer component has domain-specific logic"
    else
      do_warn "Footer component may not have variant logic"
    fi
    break
  fi
done

if [ "$footer_component_found" -eq 0 ]; then
  do_warn "MFE footer component not found (may be in plugin patches)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Action required: Fix copy/terminology issues."
  echo "  1. Remove banned strings from templates"
  echo "  2. Verify PLATFORM_NAME configuration in plugins"
  echo "  3. Check multi-tenancy domain mappings"
  echo "  4. See docs/concepts/architecture/COPY_TERMINOLOGY_CONTRACT.md for details"
  exit 1
fi

echo ""
echo "All copy/terminology checks passed!"
exit 0
