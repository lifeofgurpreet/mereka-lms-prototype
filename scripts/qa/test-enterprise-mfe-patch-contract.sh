#!/usr/bin/env bash
#
# Deterministic fixture coverage for enterprise MFE patch ownership.
#
# Proves:
# - placeholder repair stays narrow
# - learner-only optional 404 patches are required for learner bundles
# - admin bundles do not require learner-only signatures
# - env.config.js is not mutated
# - non-target code stays untouched

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_SCRIPT="${REPO_ROOT}/infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

assert_contains() {
  local file="$1"
  local label="$2"
  local pattern="$3"
  if grep -Fq "${pattern}" "${file}"; then
    echo "[PASS] ${label}"
  else
    echo "[FAIL] ${label}"
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local label="$2"
  local pattern="$3"
  if grep -Fq "${pattern}" "${file}"; then
    echo "[FAIL] ${label}"
    exit 1
  else
    echo "[PASS] ${label}"
  fi
}

LEARNER_DIR="${TMPDIR}/learner"
mkdir -p "${LEARNER_DIR}"

cat >"${LEARNER_DIR}/app-fixture.js" <<'EOF'
const runtimeCookie = "MISSING_ENV_VAR".INTEGRATION_WARNING_DISMISSED_COOKIE_NAME||null;
const accessBase = "MISSING_ENV_VAR".ENTERPRISE_ACCESS_BASE_URL;
const catalogBase = "MISSING_ENV_VAR".ENTERPRISE_CATALOG_BASE_URL;
const supportName = "MISSING_ENV_VAR".CUSTOMER_SUPPORT_NAME;
const unknownKey = "MISSING_ENV_VAR".BRAND_NEW_ENTERPRISE_KEY||null;
async function algoliaGuard(t){if(t.validUntil&&await Promise.resolve(true))return t.validUntil;return null}
async function p(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(a({enterprise_customer:e,lang:t},r)),{ENTERPRISE_CATALOG_API_BASE_URL:o}=(0,n.zj)(),c=`${o}/api/v1/academies?${i.toString()}`,{results:l}=await s(c);return l}
async function U(e,r={}){const t=new URLSearchParams(R({enterprise_customer:e},r)),s=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/enterprise-curations/?${t.toString()}`,u=await(0,i.bv)().get(s);return(0,o.il)(u.data).results[0]??null}
async function L(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(R({enterprise_customer:e,page_size:_.AK.toString(),lang:t},r)),o=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/highlight-sets/?${i.toString()}`,{results:c}=await s(o);return c}
async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`,t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}
async function Re(e){const r=await Promise.all([De(e),_e(e)]),t=(0,we.v)(r[1]);return{couponsOverview:r[0],couponCodeAssignments:r[1],couponCodeRedemptionCount:t}}
async function untouched(e){try{return await s(e)}catch(e){if(e.response&&500===e.response.status)return[];throw e}}
EOF

cat >"${LEARNER_DIR}/env.config.js" <<'EOF'
window.ENV_CONFIG = { INTEGRATION_WARNING_DISMISSED_COOKIE_NAME: "MISSING_ENV_VAR".INTEGRATION_WARNING_DISMISSED_COOKIE_NAME||null };
EOF

bash "${PATCH_SCRIPT}" "${LEARNER_DIR}" learner >/dev/null

LEARNER_JS="${LEARNER_DIR}/app-fixture.js"
LEARNER_ENV="${LEARNER_DIR}/env.config.js"

assert_contains "${LEARNER_JS}" "cookie placeholder patched" 'const runtimeCookie = "integration-warning-dismissed";'
assert_contains "${LEARNER_JS}" "access base placeholder patched" 'const accessBase = "";'
assert_contains "${LEARNER_JS}" "catalog base placeholder patched" 'const catalogBase = "";'
assert_contains "${LEARNER_JS}" "support placeholder patched" 'const supportName = "Mereka Support";'
assert_not_contains "${LEARNER_JS}" "placeholder signatures removed from learner bundle" '"MISSING_ENV_VAR".'
assert_contains "${LEARNER_JS}" "unknown placeholder fallback becomes empty string" 'const unknownKey = "";'
assert_contains "${LEARNER_JS}" "algolia null guard added" 'if(t&&t.validUntil&&await Promise.resolve(true))'
assert_contains "${LEARNER_JS}" "academies 404 downgraded" 'if(e.response&&404===e.response.status)return[];throw e'
assert_contains "${LEARNER_JS}" "curations 404 downgraded" 'if(e.response&&404===e.response.status)return null;throw e'
assert_contains "${LEARNER_JS}" "customer configurations 404 downgraded" 'async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`;try{const t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}catch(e){if(e.response&&404===e.response.status)return null;throw e}}'
assert_contains "${LEARNER_JS}" "ecommerce 404 downgraded" 'couponCodeRedemptionCount:0'
assert_contains "${LEARNER_JS}" "non-target 500 branch preserved" 'if(e.response&&500===e.response.status)return[];throw e'
assert_contains "${LEARNER_ENV}" "env.config.js left untouched" '"MISSING_ENV_VAR".INTEGRATION_WARNING_DISMISSED_COOKIE_NAME||null'

ADMIN_DIR="${TMPDIR}/admin"
mkdir -p "${ADMIN_DIR}"
cat >"${ADMIN_DIR}/app-fixture.js" <<'EOF'
const runtimeCookie = "MISSING_ENV_VAR".INTEGRATION_WARNING_DISMISSED_COOKIE_NAME||null;
const accessBase = "MISSING_ENV_VAR".ENTERPRISE_ACCESS_BASE_URL;
EOF

bash "${PATCH_SCRIPT}" "${ADMIN_DIR}" admin >/dev/null
assert_contains "${ADMIN_DIR}/app-fixture.js" "admin cookie placeholder patched" 'const runtimeCookie = "integration-warning-dismissed";'
assert_contains "${ADMIN_DIR}/app-fixture.js" "admin access placeholder patched" 'const accessBase = "";'

BROKEN_LEARNER_DIR="${TMPDIR}/broken-learner"
mkdir -p "${BROKEN_LEARNER_DIR}"
cat >"${BROKEN_LEARNER_DIR}/app-fixture.js" <<'EOF'
const runtimeCookie = "MISSING_ENV_VAR".INTEGRATION_WARNING_DISMISSED_COOKIE_NAME||null;
EOF

if bash "${PATCH_SCRIPT}" "${BROKEN_LEARNER_DIR}" learner >/dev/null 2>&1; then
  echo "[FAIL] learner role should fail when required learner patch signatures disappear"
  exit 1
else
  echo "[PASS] learner role fails when required learner patch signatures disappear"
fi

echo "ENTERPRISE_MFE_PATCH_CONTRACT_OK"
