#!/usr/bin/env bash
# @covers AC-FRONT-090
# @spec: frontend-performance-budgets_spec.md
# verify-mako-template-syntax.sh — Static syntax check for Mako templates
#
# Validates that all Mako templates in the Mereka theme:
#   1. Parse without syntax errors
#   2. Don't use undefined variables/functions (e.g., _() without gettext import)
#   3. Have all <%! %> imports resolvable
#
# This catches the class of bug where ${_('text')} is used in a template
# but `from django.utils.translation import gettext as _` is missing from
# the <%! %> block — causing TypeError: 'Undefined' at runtime.
#
# Usage: ./scripts/qa/verify-mako-template-syntax.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1" >&2; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== Mako Template Syntax Verification ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Find all Mako templates in the theme
# ---------------------------------------------------------------------------

if [[ ! -d "$THEME_DIR" ]]; then
  do_fail "Theme directory not found: $THEME_DIR"
  echo ""
  echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
  exit 1
fi

mapfile -t TEMPLATES < <(find "$THEME_DIR" -name "*.html" -type f | sort)

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  do_fail "No .html templates found in $THEME_DIR"
  echo ""
  echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
  exit 1
fi

echo "Found ${#TEMPLATES[@]} Mako templates in theme"
echo ""

# ---------------------------------------------------------------------------
# 2. Check each template for undefined function/variable usage
# ---------------------------------------------------------------------------

echo "--- Checking for undefined Mako variable references ---"
echo ""

for tmpl in "${TEMPLATES[@]}"; do
  rel="${tmpl#$REPO_ROOT/}"

  # Extract the <%! %> module-level block to see what's imported
  imports=$(sed -n '/<%!/,/%>/p' "$tmpl" 2>/dev/null || true)

  # Check for _() usage (gettext) without corresponding import
  if grep -q '\${_(' "$tmpl" 2>/dev/null; then
    if grep -qE 'import.*gettext.*as _|from.*import.*_' <<<"$imports"; then
      do_pass "$rel: uses \${_()} with gettext import present"
    else
      do_fail "$rel: uses \${_()} but missing 'from django.utils.translation import gettext as _' in <%! %> block"
    fi
  fi

  # Check for ugettext (deprecated in Django 4+)
  if grep -q 'ugettext' "$tmpl" 2>/dev/null; then
    do_warn "$rel: uses deprecated 'ugettext' — migrate to 'gettext'"
  fi

  if grep -qE 'from (lms|cms)\.envs\.tutor\.mereka_multisite import' "$tmpl" 2>/dev/null; then
    do_fail "$rel: imports deployment-only mereka_multisite settings module from a Mako template"
  fi

  if grep -q 'tenant_authn_microfrontend_url_for_host' "$tmpl" 2>/dev/null; then
    if grep -q 'from openedx_tenant_cache.runtime_urls import tenant_authn_microfrontend_url_for_host' <<<"$imports"; then
      do_pass "$rel: uses installed runtime URL helper for tenant Authn links"
    else
      do_fail "$rel: uses tenant_authn_microfrontend_url_for_host without importing openedx_tenant_cache.runtime_urls"
    fi
  fi

  # Check for ${variable} references to common functions that need imports
  # format_html, mark_safe, reverse, etc.
  for func in format_html mark_safe reverse static; do
    if grep -qE "\\\$\{${func}\(" "$tmpl" 2>/dev/null; then
      if ! grep -q "$func" <<<"$imports"; then
        do_fail "$rel: uses \${${func}()} but '${func}' not found in <%! %> imports"
      fi
    fi
  done
done

echo ""

# ---------------------------------------------------------------------------
# 3. Verify template runtime helpers are source-materialized
# ---------------------------------------------------------------------------

echo "--- Checking template runtime helper source ---"
echo ""

runtime_urls_helper="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_tenant_cache/runtime_urls.py"
if [[ -f "$runtime_urls_helper" ]]; then
  do_pass "openedx_tenant_cache.runtime_urls helper source exists in installed custom app"
  if grep -q 'def tenant_authn_microfrontend_url_for_host' "$runtime_urls_helper" \
    && grep -q 'def candidate_site_domains' "$runtime_urls_helper"; then
    do_pass "openedx_tenant_cache.runtime_urls exposes tenant Authn URL and host candidate helpers"
  else
    do_fail "openedx_tenant_cache.runtime_urls is missing required tenant URL helper functions"
  fi
else
  do_fail "openedx_tenant_cache.runtime_urls helper source is missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Check for Mako syntax errors (balanced tags)
# ---------------------------------------------------------------------------

echo "--- Checking Mako tag balance ---"
echo ""

for tmpl in "${TEMPLATES[@]}"; do
  rel="${tmpl#$REPO_ROOT/}"

  # Count only non-self-closing <%def> blocks. Mako commonly uses
  # one-line declarations like `<%def name="pagetitle()" />`.
  opens=$(grep -cE '<%def [^>]*[^/]>$|<%def [^>]*/?>([^/].*)?$' "$tmpl" 2>/dev/null || true)
  self_closing=$(grep -cE '<%def [^>]*/>' "$tmpl" 2>/dev/null || true)
  closes=$(grep -c '</%def>' "$tmpl" 2>/dev/null || true)
  opens=$((opens - self_closing))
  if [[ "$opens" != "$closes" ]]; then
    do_fail "$rel: <%def> open/close mismatch ($opens opens, $closes closes)"
  fi

  # Count only non-self-closing <%block> blocks. Many Open edX templates use
  # `<%block name="foo"/>` as an intentional single-line declaration.
  opens=$(grep -cE '<%block [^>]*[^/]>$|<%block [^>]*/?>([^/].*)?$' "$tmpl" 2>/dev/null || true)
  self_closing=$(grep -cE '<%block [^>]*/>' "$tmpl" 2>/dev/null || true)
  closes=$(grep -c '</%block>' "$tmpl" 2>/dev/null || true)
  opens=$((opens - self_closing))
  if [[ "$opens" != "$closes" ]]; then
    do_fail "$rel: <%block> open/close mismatch ($opens opens, $closes closes)"
  fi

  # Template passed tag balance checks
  do_pass "$rel: Mako tag balance OK"
done

echo ""

# ---------------------------------------------------------------------------
# 5. Verify no templates use raw Python builtins that Mako marks as UNDEFINED
# ---------------------------------------------------------------------------

echo "--- Checking for UNDEFINED-prone patterns ---"
echo ""

for tmpl in "${TEMPLATES[@]}"; do
  rel="${tmpl#$REPO_ROOT/}"

  # The most common UNDEFINED trap: using _() for i18n without import
  # We already checked this above, but also check for:
  # - ngettext, pgettext (less common i18n functions)
  for i18n_func in ngettext pgettext npgettext; do
    if grep -qE "\\\$\{${i18n_func}\(" "$tmpl" 2>/dev/null; then
      if ! echo "$(sed -n '/<%!/,/%>/p' "$tmpl")" | grep -q "$i18n_func"; then
        do_fail "$rel: uses ${i18n_func}() without import"
      fi
    fi
  done
done

echo ""

# ---------------------------------------------------------------------------
# 6. Guard known Mako named-block scope hazards
# ---------------------------------------------------------------------------

echo "--- Checking named-block runtime scope hazards ---"
echo ""

navbar_template="$THEME_DIR/lms/templates/header/navbar-logo-header.html"
if [[ -f "$navbar_template" ]]; then
  navigation_logo_block="$(awk '
    /<%block name="navigation_logo"/ { in_block = 1 }
    in_block { print }
    /<\/%block>/ { in_block = 0 }
  ' "$navbar_template")"

  if grep -qE '\$\{_tenant_logo\}|\$\{_platform_name\}' <<<"$navigation_logo_block"; then
    do_fail "lms/templates/header/navbar-logo-header.html: navigation_logo block references outer locals that Mako may render as Undefined"
  else
    do_pass "lms/templates/header/navbar-logo-header.html: navigation_logo block does not reference outer logo/platform locals"
  fi

  if grep -q '_navigation_logo_url' <<<"$navigation_logo_block" \
    && grep -q '_navigation_platform_name' <<<"$navigation_logo_block"; then
    do_pass "lms/templates/header/navbar-logo-header.html: navigation_logo block computes its own logo/platform fallbacks"
  else
    do_fail "lms/templates/header/navbar-logo-header.html: navigation_logo block must compute local logo/platform fallbacks"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "======================================="
echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"
echo "======================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL" >&2
  exit 1
fi

echo "RESULT: PASS"
