#!/usr/bin/env bash
# verify-enterprise-admin-runtime-config.sh
#
# Regression guard for enterprise admin portal runtime wiring.
# Ensures env config is served and frontend bundles are not shipped with
# unresolved MISSING_ENV_VAR placeholders for critical API base URLs.

set -euo pipefail

PASS=0
FAIL=0
WARN=0
SKIP=0

ADMIN_URL="${ADMIN_URL:-https://admin.academyv2.mereka.io}"
TIMEOUT="${TIMEOUT:-15}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }
skip_check() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

echo "=== Enterprise Admin Runtime Config Guard ==="
echo "URL: $ADMIN_URL"
echo

ADMIN_HTML="$(curl -sS -L --max-time "$TIMEOUT" "$ADMIN_URL/" || true)"
if [ -z "$ADMIN_HTML" ]; then
  fail_check "Admin portal returned empty HTML"
else
  pass_check "Admin portal HTML fetched"
fi

if printf '%s' "$ADMIN_HTML" | grep -q 'src="/env.config.js"'; then
  pass_check "index.html references /env.config.js"
else
  fail_check "index.html missing /env.config.js runtime config script"
fi

ENV_JS="$(curl -sS -L --max-time "$TIMEOUT" "$ADMIN_URL/env.config.js" || true)"
if [ -z "$ENV_JS" ]; then
  fail_check "env.config.js is unreachable or empty"
else
  pass_check "env.config.js fetched"
fi

if printf '%s' "$ENV_JS" | grep -q 'window.ENV_CONFIG'; then
  pass_check "env.config.js defines window.ENV_CONFIG"
else
  fail_check "env.config.js does not define window.ENV_CONFIG"
fi

REQUIRED_KEYS=(
  ENTERPRISE_CATALOG_API_BASE_URL
  ENTERPRISE_ACCESS_BASE_URL
  LICENSE_MANAGER_URL
  ENTERPRISE_SUBSIDY_BASE_URL
)
for key in "${REQUIRED_KEYS[@]}"; do
  if printf '%s' "$ENV_JS" | grep -q "$key"; then
    pass_check "env.config.js contains $key"
  else
    fail_check "env.config.js missing $key"
  fi
done

mapfile -t SCRIPT_PATHS < <(printf '%s' "$ADMIN_HTML" | grep -o 'src="/[^"]*\.js"' | sed 's/src="//;s/"$//' | sort -u)
if [ "${#SCRIPT_PATHS[@]}" -eq 0 ]; then
  warn_check "No JS bundle paths discovered in index.html"
else
  pass_check "Discovered ${#SCRIPT_PATHS[@]} JS bundles in index.html"
fi

COMBINED_JS="$TMPDIR/admin-bundles.js"
touch "$COMBINED_JS"
for path in "${SCRIPT_PATHS[@]}"; do
  body="$(curl -sS -L --max-time "$TIMEOUT" "$ADMIN_URL$path" || true)"
  if [ -z "$body" ]; then
    fail_check "Failed to fetch JS bundle: $path"
    continue
  fi
  printf '%s\n' "$body" >> "$COMBINED_JS"
done

if [ -s "$COMBINED_JS" ]; then
  pass_check "Downloaded JS bundles for placeholder scan"
else
  skip_check "No JS bundle content available for scan"
fi

CRITICAL_PLACEHOLDERS=(
  'MISSING_ENV_VAR".BASE_URL'
  'MISSING_ENV_VAR".LICENSE_MANAGER_BASE_URL'
  'MISSING_ENV_VAR".ENTERPRISE_CATALOG_BASE_URL'
  'MISSING_ENV_VAR".ENTERPRISE_ACCESS_BASE_URL'
  'MISSING_ENV_VAR".ENTERPRISE_SUBSIDY_BASE_URL'
)
for placeholder in "${CRITICAL_PLACEHOLDERS[@]}"; do
  if grep -q "$placeholder" "$COMBINED_JS" 2>/dev/null; then
    fail_check "Unresolved build placeholder present: $placeholder"
  else
    pass_check "No unresolved placeholder: $placeholder"
  fi
done

GENERIC_COUNT="$(grep -E -o '"MISSING_ENV_VAR"\.[A-Z0-9_]+' "$COMBINED_JS" 2>/dev/null | wc -l | tr -d ' ' || true)"
if [ -z "$GENERIC_COUNT" ]; then
  GENERIC_COUNT="0"
fi
if [ "$GENERIC_COUNT" != "0" ]; then
  fail_check "Found unresolved generic MISSING_ENV_VAR placeholders in admin bundles ($GENERIC_COUNT)"
else
  pass_check "No unresolved generic MISSING_ENV_VAR placeholders in admin bundles"
fi

if grep -q 'undefined_license_key' "$COMBINED_JS" 2>/dev/null || printf '%s' "$ADMIN_HTML" | grep -q 'undefined_license_key'; then
  fail_check "Found undefined_license_key marker in served admin assets"
else
  pass_check "No undefined_license_key marker in served admin assets"
fi

echo
echo "=== Summary ==="
echo "  PASS: $PASS | FAIL: $FAIL | WARN: $WARN | SKIP: $SKIP"
echo
if [ "$FAIL" -gt 0 ]; then
  echo "  RESULT: FAIL"
  exit 1
fi
echo "  RESULT: PASS"
exit 0
