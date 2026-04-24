#!/usr/bin/env bash
# test-enterprise-mfe-optional-endpoint-hardening.sh
#
# Proves the enterprise learner bundle patch downgrades only optional 404s to
# empty/default state for the learner dashboard/search secondary path.
#
# Exit 0 = patch signatures applied correctly
# Exit 1 = patch missing / regressed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_SCRIPT="${REPO_ROOT}/infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

FIXTURE_JS="${TMPDIR}/app-fixture.js"

cat >"${FIXTURE_JS}" <<'EOF'
async function p(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(a({enterprise_customer:e,lang:t},r)),{ENTERPRISE_CATALOG_API_BASE_URL:o}=(0,n.zj)(),c=`${o}/api/v1/academies?${i.toString()}`,{results:l}=await s(c);return l}
async function U(e,r={}){const t=new URLSearchParams(R({enterprise_customer:e},r)),s=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/enterprise-curations/?${t.toString()}`,u=await(0,i.bv)().get(s);return(0,o.il)(u.data).results[0]??null}
async function L(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(R({enterprise_customer:e,page_size:_.AK.toString(),lang:t},r)),o=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/highlight-sets/?${i.toString()}`,{results:c}=await s(o);return c}
async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`,t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}
async function Re(e){const r=await Promise.all([De(e),_e(e)]),t=(0,we.v)(r[1]);return{couponsOverview:r[0],couponCodeAssignments:r[1],couponCodeRedemptionCount:t}}
EOF

bash "${PATCH_SCRIPT}" "${TMPDIR}" >/dev/null

assert_contains() {
  local label="$1"
  local pattern="$2"
  if grep -Fq "${pattern}" "${FIXTURE_JS}"; then
    echo "[PASS] ${label}"
  else
    echo "[FAIL] ${label}"
    exit 1
  fi
}

assert_not_contains() {
  local label="$1"
  local pattern="$2"
  if grep -Fq "${pattern}" "${FIXTURE_JS}"; then
    echo "[FAIL] ${label}"
    exit 1
  else
    echo "[PASS] ${label}"
  fi
}

assert_contains "academies 404 becomes empty list" 'if(e.response&&404===e.response.status)return[];throw e'
assert_contains "enterprise curations 404 becomes null" 'if(e.response&&404===e.response.status)return null;throw e'
assert_contains "highlight sets 404 becomes empty list" 'async function L(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(R({enterprise_customer:e,page_size:_.AK.toString(),lang:t},r)),o=`${(0,n.zj)().ENTERPRISE_CATALOG_API_BASE_URL}/api/v1/highlight-sets/?${i.toString()}`;try{const{results:e}=await s(o);return e}catch(e){if(e.response&&404===e.response.status)return[];throw e}}'
assert_contains "customer configuration 404 becomes null" 'async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`;try{const t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}catch(e){if(e.response&&404===e.response.status)return null;throw e}}'
assert_contains "coupon bundle 404 becomes empty payload" 'if(r.response&&404===r.response.status)return{couponsOverview:[],couponCodeAssignments:[],couponCodeRedemptionCount:0};throw r'

assert_not_contains "original academies snippet removed" 'async function p(e,r={}){const t=(0,u.n7)(),i=new URLSearchParams(a({enterprise_customer:e,lang:t},r)),{ENTERPRISE_CATALOG_API_BASE_URL:o}=(0,n.zj)(),c=`${o}/api/v1/academies?${i.toString()}`,{results:l}=await s(c);return l}'
assert_not_contains "original customer configuration snippet removed" 'async function ce(e){const r=`${(0,n.zj)().ENTERPRISE_ACCESS_BASE_URL}/api/v1/customer-configurations/${e}/`,t=await(0,i.bv)().get(r);return(0,o.il)(t.data)}'

echo "OPTIONAL_ENDPOINT_HARDENING_PATCH_OK"
