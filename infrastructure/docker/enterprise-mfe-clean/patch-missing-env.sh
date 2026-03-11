#!/bin/sh
# patch-missing-env.sh
# Replace "MISSING_ENV_VAR".KEY placeholders in built JS bundles with safe
# build-time defaults for enterprise MFE portals.
#
# IMPORTANT: URL values MUST be empty strings or relative paths only.
# Runtime env.config.js (injected per-environment via ConfigMap) is the
# authority for all environment-specific URLs (LMS, enterprise services, etc.).
# Build-time values must NOT hardcode absolute domain-specific URLs — doing so
# causes cross-origin failures and makes bundles environment-dependent.
# Per-pod Caddy proxies handle same-origin routing of API requests.

set -eu

DIST_DIR="${1:-/openedx/dist}"

if [ ! -d "$DIST_DIR" ]; then
  echo "[patch-env] ERROR: dist dir not found: $DIST_DIR"
  exit 1
fi

replace_key() {
  key="$1"
  value="$2"
  pattern="\"MISSING_ENV_VAR\"\\.${key}"
  count_before=$(find "$DIST_DIR" -name '*.js' | xargs grep -o "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count_before:-0}" = "0" ]; then
    echo "[patch-env] INFO: $key not present in JS bundles"
    return 0
  fi

  for js in "$DIST_DIR"/*.js; do
    [ -f "$js" ] || continue
    [ "$(basename "$js")" = "env.config.js" ] && continue
    [ -w "$js" ] || continue
    # First: replace "MISSING_ENV_VAR".KEY||null with just the value.
    # Webpack compiles `process.env.KEY || null` as `"MISSING_ENV_VAR".KEY||null`.
    # If we only replace the MISSING_ENV_VAR part, ""||null evaluates to null
    # (empty string is falsy in JS). Matching the full pattern avoids this.
    sed -i "s#\"MISSING_ENV_VAR\"\\.${key}||null#\"${value}\"#g" "$js"
    # Then: replace any remaining "MISSING_ENV_VAR".KEY without ||null suffix.
    sed -i "s#\"MISSING_ENV_VAR\"\\.${key}#\"${value}\"#g" "$js"
  done

  count_after=$(find "$DIST_DIR" -name '*.js' | xargs grep -o "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count_after:-0}" != "0" ]; then
    echo "[patch-env] ERROR: unresolved placeholder remains for $key"
    exit 1
  fi

  echo "[patch-env] OK: patched $key ($count_before occurrence(s))"
}

replace_remaining_placeholders() {
  # Safety net: if upstream introduces new placeholders that are not explicitly
  # mapped above, replace them with empty strings so runtime code does not try
  # to read properties off "MISSING_ENV_VAR" (which yields undefined endpoints).
  pattern='"MISSING_ENV_VAR"\.[A-Z0-9_]+'
  count_before=$(find "$DIST_DIR" -name '*.js' | xargs grep -E -o "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count_before:-0}" = "0" ]; then
    echo "[patch-env] OK: no unresolved placeholder signatures remain"
    return 0
  fi

  for js in "$DIST_DIR"/*.js; do
    [ -f "$js" ] || continue
    [ "$(basename "$js")" = "env.config.js" ] && continue
    [ -w "$js" ] || continue
    # Match with ||null suffix first (broader pattern), then without.
    sed -E -i 's/"MISSING_ENV_VAR"\.[A-Z0-9_]+\|\|null/""/g' "$js"
    sed -E -i 's/"MISSING_ENV_VAR"\.[A-Z0-9_]+/""/g' "$js"
  done

  count_after=$(find "$DIST_DIR" -name '*.js' | xargs grep -E -o "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count_after:-0}" != "0" ]; then
    echo "[patch-env] ERROR: unresolved placeholder signatures remain after fallback patch (${count_after})"
    exit 1
  fi

  echo "[patch-env] OK: replaced remaining placeholder signatures (${count_before} occurrence(s))"
}

# --- URL values: empty string (same-origin via Caddy) or relative paths ---
# Runtime env.config.js owns all environment-specific URLs.
# Build-time just needs to replace placeholders so the bundle doesn't crash.
replace_key "BASE_URL" ""
replace_key "REFRESH_ACCESS_TOKEN_ENDPOINT" "/login_refresh"
replace_key "CSRF_TOKEN_API_PATH" "/csrf/api/v1/token"
replace_key "DATA_API_BASE_URL" ""
replace_key "ECOMMERCE_BASE_URL" ""
replace_key "DISCOVERY_BASE_URL" ""

# Enterprise service URLs: empty string → same-origin routing through per-pod
# Caddy (learner Caddy proxies /api/v1/bffs/* to enterprise-access, /api/* to
# LMS; admin Caddy proxies /api/* to LMS).
replace_key "ENTERPRISE_ACCESS_BASE_URL" ""
replace_key "ENTERPRISE_CATALOG_BASE_URL" ""
replace_key "ENTERPRISE_SUBSIDY_BASE_URL" ""
replace_key "LICENSE_MANAGER_BASE_URL" ""

# Portal URLs: empty string — runtime env.config.js provides per-environment
# portal URLs (e.g., learner.academyv2.mereka.dev vs learner.academyv2.mereka.io).
replace_key "ENTERPRISE_LEARNER_PORTAL_URL" ""

# --- Non-URL values: safe to bake at build time (environment-agnostic) ---
replace_key "ACCESS_TOKEN_COOKIE_NAME" "edx-jwt-cookie-header-payload"
replace_key "USER_INFO_COOKIE_NAME" "edx-user-info"
replace_key "INTEGRATION_WARNING_DISMISSED_COOKIE_NAME" "integration-warning-dismissed"
replace_key "PLATFORM_NAME" "Mereka Academy"
replace_key "CUSTOMER_SUPPORT_NAME" "Mereka Support"
replace_key "CUSTOMER_SUPPORT_EMAIL" "support@mereka.io"

replace_remaining_placeholders

# --- Null-safety patches for upstream bugs ---
# Upstream code destructures `const { algolia } = bffResponse` then reads
# `algolia.validUntil` without guarding for null/undefined. When Algolia is not
# configured, BFF returns no algolia field and the page crashes with:
#   TypeError: Cannot read properties of null (reading 'validUntil')
# Fix: add null guard so the property access is skipped when algolia is absent.
for js in "$DIST_DIR"/*.js; do
  [ -f "$js" ] || continue
  [ "$(basename "$js")" = "env.config.js" ] && continue
  [ -w "$js" ] || continue
  # Pattern: `if(X.validUntil)` → `if(X&&X.validUntil)` where X is a short var name
  # The minified pattern is like: t.validUntil&&await
  if grep -q '\.validUntil&&await' "$js"; then
    sed -i 's/\b\([a-z]\)\.validUntil&&await/\1\&\&\1.validUntil\&\&await/g' "$js"
    echo "[patch-env] OK: added null guard for algolia.validUntil access"
  fi
done

echo "[patch-env] Completed placeholder patching in $DIST_DIR"
