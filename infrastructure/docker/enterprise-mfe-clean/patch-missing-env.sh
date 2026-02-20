#!/bin/sh
# patch-missing-env.sh
# Replace critical MFE placeholders of the form "MISSING_ENV_VAR".KEY in built
# JS bundles with canonical production values for enterprise portals.
#
# This is a build-time stabilization step for upstream enterprise MFEs that ship
# unresolved placeholders in static bundles.

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
    sed -i "s#\"MISSING_ENV_VAR\"\\.${key}#\"${value}\"#g" "$js"
  done

  count_after=$(find "$DIST_DIR" -name '*.js' | xargs grep -o "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${count_after:-0}" != "0" ]; then
    echo "[patch-env] ERROR: unresolved placeholder remains for $key"
    exit 1
  fi

  echo "[patch-env] OK: patched $key ($count_before occurrence(s))"
}

# Critical endpoints for enterprise admin/learner portals.
replace_key "BASE_URL" "https://admin.academyv2.mereka.io"
replace_key "REFRESH_ACCESS_TOKEN_ENDPOINT" "https://admin.academyv2.mereka.io/login_refresh"
replace_key "DATA_API_BASE_URL" "https://academyv2.mereka.io"
replace_key "ECOMMERCE_BASE_URL" "https://ecommerce.academyv2.mereka.io"
replace_key "DISCOVERY_BASE_URL" "https://discovery.academyv2.mereka.io"
replace_key "LICENSE_MANAGER_BASE_URL" "https://admin.academyv2.mereka.io/api/license-manager"
replace_key "ENTERPRISE_CATALOG_BASE_URL" "https://admin.academyv2.mereka.io/api/enterprise-catalog"
replace_key "ENTERPRISE_ACCESS_BASE_URL" "https://admin.academyv2.mereka.io/api/enterprise-access"
replace_key "ENTERPRISE_SUBSIDY_BASE_URL" "https://admin.academyv2.mereka.io/api/enterprise-subsidy"
replace_key "ENTERPRISE_LEARNER_PORTAL_URL" "https://enterprise.academyv2.mereka.io"
replace_key "ACCESS_TOKEN_COOKIE_NAME" "edx-jwt-cookie-header-payload"
replace_key "USER_INFO_COOKIE_NAME" "edx-user-info"

echo "[patch-env] Completed placeholder patching in $DIST_DIR"
