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
PORTAL_ROLE="${2:-auto}"

if [ ! -d "$DIST_DIR" ]; then
  echo "[patch-env] ERROR: dist dir not found: $DIST_DIR"
  exit 1
fi

case "$PORTAL_ROLE" in
  learner|admin|auto) ;;
  *)
    echo "[patch-env] ERROR: unsupported portal role: $PORTAL_ROLE"
    exit 1
    ;;
esac

role_requires_patch() {
  patch_role="$1"
  case "$patch_role:$PORTAL_ROLE" in
    both:*)
      return 0
      ;;
    learner:learner|admin:admin)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

replace_literal_in_file() {
  file_path="$1"
  search="$2"
  replacement="$3"
  python3 - "$file_path" "$search" "$replacement" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
search = sys.argv[2]
replacement = sys.argv[3]
text = path.read_text(encoding="utf-8")
count = text.count(search)
if count:
    path.write_text(text.replace(search, replacement), encoding="utf-8")
print(count)
PY
}

apply_exact_bundle_patch() {
  label="$1"
  patch_role="$2"
  search="$3"
  replacement="$4"
  total_matches=0

  for js in "$DIST_DIR"/*.js; do
    [ -f "$js" ] || continue
    [ "$(basename "$js")" = "env.config.js" ] && continue
    [ -w "$js" ] || continue
    count="$(replace_literal_in_file "$js" "$search" "$replacement")"
    total_matches=$((total_matches + count))
  done

  if [ "$total_matches" -gt 0 ]; then
    echo "[patch-env] OK: ${label} (${total_matches} occurrence(s))"
    return 0
  fi

  if role_requires_patch "$patch_role"; then
    echo "[patch-env] ERROR: expected ${label} signature missing for portal role ${PORTAL_ROLE}"
    exit 1
  fi

  echo "[patch-env] INFO: ${label} not present for portal role ${PORTAL_ROLE}"
}

replace_key() {
  key="$1"
  value="$2"
  pattern="\"MISSING_ENV_VAR\"\\.${key}"
  count_before=$(find "$DIST_DIR" -name '*.js' ! -name 'env.config.js' -exec grep -o "$pattern" {} + 2>/dev/null | wc -l | tr -d ' ')
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

  count_after=$(find "$DIST_DIR" -name '*.js' ! -name 'env.config.js' -exec grep -o "$pattern" {} + 2>/dev/null | wc -l | tr -d ' ')
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
  count_before=$(find "$DIST_DIR" -name '*.js' ! -name 'env.config.js' -exec grep -E -o "$pattern" {} + 2>/dev/null | wc -l | tr -d ' ')
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

  count_after=$(find "$DIST_DIR" -name '*.js' ! -name 'env.config.js' -exec grep -E -o "$pattern" {} + 2>/dev/null | wc -l | tr -d ' ')
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
algolia_matches=0
for js in "$DIST_DIR"/*.js; do
  [ -f "$js" ] || continue
  [ "$(basename "$js")" = "env.config.js" ] && continue
  [ -w "$js" ] || continue
  count_before="$(python3 - "$js" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pattern = re.compile(r"\b([a-z])\.validUntil&&await")
updated, count = pattern.subn(r"\1&&\1.validUntil&&await", text)
if count:
    path.write_text(updated, encoding="utf-8")
print(count)
PY
)"
  if [ "${count_before:-0}" != "0" ]; then
    algolia_matches=$((algolia_matches + count_before))
  fi
done

if [ "$algolia_matches" -gt 0 ]; then
  echo "[patch-env] OK: added null guard for algolia.validUntil access (${algolia_matches} occurrence(s))"
elif role_requires_patch learner; then
  echo "[patch-env] ERROR: expected algolia.validUntil learner signature missing for portal role ${PORTAL_ROLE}"
  exit 1
else
  echo "[patch-env] INFO: algolia.validUntil learner signature not present for portal role ${PORTAL_ROLE}"
fi

# Optional enterprise enrichment endpoints may legitimately 404 in some
# deployments even after routing is correct. The learner MFE currently mounts
# these through suspense hooks in dashboard/search surfaces, so a plain 404 can
# escalate into the global error boundary before local empty-state UI runs.
#
# Hardening rule:
# - 404 on optional enrichment endpoints => downgrade to empty/default state
# - non-404 / auth / server failures => rethrow
#
# This is intentionally narrow and deterministic. It only targets the current
# shipped learner bundle signatures for:
# - academies list
# - enterprise curations configuration
# - highlight sets
# - browse-and-request customer configuration
# - ecommerce coupon overview / assignment summary bundle
apply_exact_bundle_patch \
  "learner academies optional 404 handling" \
  learner \
  'async function p(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(a({enterprise_customer:e,lang:t},r)),{ENTERPRISE_CATALOG_API_BASE_URL:o}=(0,n.zj)(),c=`${o}/api/v1/academies?${i.toString()}`,{results:l}=await s(c);return l}' \
  'async function p(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(a({enterprise_customer:e,lang:t},r)),{ENTERPRISE_CATALOG_API_BASE_URL:o}=(0,n.zj)(),c=`${o}/api/v1/academies?${i.toString()}`;try{const{results:r}=await s(c);return r}catch(e){if(e.response&&404===e.response.status)return[];throw e}}'

apply_exact_bundle_patch \
  "learner enterprise-curations optional 404 handling" \
  learner \
  'async function U(e,r={}){const t=new URLSearchParams(R({enterprise_customer:e},r)),s=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/enterprise-curations/?${t.toString()}`,u=await(0,i.bv)().get(s);return(0,o.il)(u.data).results[0]??null}' \
  'async function U(e,r={}){const t=new URLSearchParams(R({enterprise_customer:e},r)),s=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/enterprise-curations/?${t.toString()}`;try{const e=await(0,i.bv)().get(s);return(0,o.il)(e.data).results[0]??null}catch(e){if(e.response&&404===e.response.status)return null;throw e}}'

apply_exact_bundle_patch \
  "learner highlight-sets optional 404 handling" \
  learner \
  'async function L(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(R({enterprise_customer:e,page_size:_.AK.toString(),lang:t},r)),o=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/highlight-sets/?${i.toString()}`,{results:c}=await s(o);return c}' \
  'async function L(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(R({enterprise_customer:e,page_size:_.AK.toString(),lang:t},r)),o=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/highlight-sets/?${i.toString()}`;try{const{results:e}=await s(o);return e}catch(e){if(e.response&&404===e.response.status)return[];throw e}}'

apply_exact_bundle_patch \
  "learner customer-configurations optional 404 handling" \
  learner \
  'async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`,t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}' \
  'async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`;try{const t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}catch(e){if(e.response&&404===e.response.status)return null;throw e}}'

apply_exact_bundle_patch \
  "learner ecommerce optional 404 handling" \
  learner \
  'async function Re(e){const r=await Promise.all([De(e),_e(e)]),t=(0,we.v)(r[1]);return{couponsOverview:r[0],couponCodeAssignments:r[1],couponCodeRedemptionCount:t}}' \
  'async function Re(e){try{const r=await Promise.all([De(e),_e(e)]),t=(0,we.v)(r[1]);return{couponsOverview:r[0],couponCodeAssignments:r[1],couponCodeRedemptionCount:t}}catch(r){if(r.response&&404===r.response.status)return{couponsOverview:[],couponCodeAssignments:[],couponCodeRedemptionCount:0};throw r}}'

echo "[patch-env] Completed placeholder patching in $DIST_DIR for portal role ${PORTAL_ROLE}"
