#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_SCRIPT="${REPO_ROOT}/infrastructure/tutor/patches/patch-authn-deep-route-handoff.py"
SOURCE_PATCH_SCRIPT="${REPO_ROOT}/infrastructure/tutor/patches/patch-authn-dashboard-fallbacks.py"
VERIFY_SCRIPT="${REPO_ROOT}/infrastructure/tutor/patches/verify-authn-dashboard-fallbacks.py"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || true)}"

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "[FAIL] python3 not found on PATH"
  exit 1
fi

readarray -t PATCH_CONTRACT < <("${PYTHON_BIN}" - "${PATCH_SCRIPT}" <<'PY'
import importlib.util
import pathlib
import sys

script_path = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("patch_authn_deep_route_handoff", script_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

print(module.REPLACEMENT)
print(module.ROUTE_SCOPE)
PY
)

EXPECTED_REPLACEMENT="${PATCH_CONTRACT[0]}"
EXPECTED_ROUTE_SCOPE="${PATCH_CONTRACT[1]}"

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

DIST_DIR="${TMPDIR}/dist"
mkdir -p "${DIST_DIR}"

cat >"${DIST_DIR}/app-fixture.js" <<'EOF'
const er=e=>{const{authenticatedUser:t,finishAuthUrl:r,redirectUrl:o,redirectToProgressiveProfilingPage:n,success:i}=e;let u="";if(i){if(u=r&&!o.includes(r)?(0,s.zj)().LMS_BASE_URL+r:o,n){return "profiling"}window.location.href=u}return null};
EOF

python3 "${PATCH_SCRIPT}" "${DIST_DIR}" >/dev/null

FIXTURE="${DIST_DIR}/app-fixture.js"

assert_not_contains "${FIXTURE}" "old LMS_BASE_URL handoff removed" 'u=r&&!o.includes(r)?(0,s.zj)().LMS_BASE_URL+r:o'
assert_contains "${FIXTURE}" "patch routes authn deep-route contract to current apps origin" "${EXPECTED_REPLACEMENT}"
assert_contains "${FIXTURE}" "patch scopes only authority-owned authn deep-route prefixes" "${EXPECTED_ROUTE_SCOPE}"
NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
if [[ -z "${NODE_BIN}" ]]; then
  echo "[FAIL] node not found on PATH"
  exit 1
fi
"${NODE_BIN}" --check "${FIXTURE}" >/dev/null
echo "[PASS] patch emits syntactically valid JavaScript"

BROKEN_DIR="${TMPDIR}/broken"
mkdir -p "${BROKEN_DIR}"
echo 'const noMatch = true;' >"${BROKEN_DIR}/app-fixture.js"

if python3 "${PATCH_SCRIPT}" "${BROKEN_DIR}" >/dev/null 2>&1; then
  echo "[FAIL] patch should fail when expected authn signature is missing"
  exit 1
else
echo "[PASS] patch fails when expected authn signature is missing"
fi

APP_DIR="${TMPDIR}/authn-app"
mkdir -p "${APP_DIR}/src/login/data" "${APP_DIR}/src/register/data"

cat >"${APP_DIR}/src/login/data/service.js" <<'EOF'
redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,
EOF

cat >"${APP_DIR}/src/register/data/service.js" <<'EOF'
redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,
EOF

cat >"${APP_DIR}/src/login/LoginFailure.jsx" <<'EOF'
const url = `${getConfig().LMS_BASE_URL}/dashboard/?tpa_hint=${context.tpaHint}`;
EOF

python3 "${SOURCE_PATCH_SCRIPT}" "${APP_DIR}" >/dev/null

assert_contains "${APP_DIR}/src/login/data/service.js" "login service uses relative dashboard fallback" 'redirectUrl: data.redirect_url || "/dashboard",'
assert_contains "${APP_DIR}/src/register/data/service.js" "register service uses relative dashboard fallback" 'redirectUrl: data.redirect_url || "/dashboard",'
assert_contains "${APP_DIR}/src/login/LoginFailure.jsx" "login failure uses relative dashboard fallback" 'const url = `/dashboard/?tpa_hint=${context.tpaHint}`;'

python3 "${SOURCE_PATCH_SCRIPT}" "${APP_DIR}" >/dev/null
echo "[PASS] authn source fallback patch is idempotent for legacy upstream layout"

MOVED_APP_DIR="${TMPDIR}/authn-app-moved"
mkdir -p \
  "${MOVED_APP_DIR}/src/features/login/data" \
  "${MOVED_APP_DIR}/src/features/register/data" \
  "${MOVED_APP_DIR}/src/features/login"

cat >"${MOVED_APP_DIR}/src/features/login/data/service.js" <<'EOF'
redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,
EOF

cat >"${MOVED_APP_DIR}/src/features/register/data/service.js" <<'EOF'
redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,
EOF

cat >"${MOVED_APP_DIR}/src/features/login/LoginFailure.jsx" <<'EOF'
const url = `${getConfig().LMS_BASE_URL}/dashboard/?tpa_hint=${context.tpaHint}`;
EOF

python3 "${SOURCE_PATCH_SCRIPT}" "${MOVED_APP_DIR}" >/dev/null

assert_contains "${MOVED_APP_DIR}/src/features/login/data/service.js" "moved login service uses relative dashboard fallback" 'redirectUrl: data.redirect_url || "/dashboard",'
assert_contains "${MOVED_APP_DIR}/src/features/register/data/service.js" "moved register service uses relative dashboard fallback" 'redirectUrl: data.redirect_url || "/dashboard",'
assert_contains "${MOVED_APP_DIR}/src/features/login/LoginFailure.jsx" "moved login failure uses relative dashboard fallback" 'const url = `/dashboard/?tpa_hint=${context.tpaHint}`;'

MISSING_FLOW_APP_DIR="${TMPDIR}/authn-app-missing-flow"
mkdir -p "${MISSING_FLOW_APP_DIR}/src/features/login/data" "${MISSING_FLOW_APP_DIR}/src/features/login"

cat >"${MISSING_FLOW_APP_DIR}/src/features/login/data/service.js" <<'EOF'
redirectUrl: data.redirect_url || `${getConfig().LMS_BASE_URL}/dashboard`,
EOF

cat >"${MISSING_FLOW_APP_DIR}/src/features/login/LoginFailure.jsx" <<'EOF'
const url = `${getConfig().LMS_BASE_URL}/dashboard/?tpa_hint=${context.tpaHint}`;
EOF

if python3 "${SOURCE_PATCH_SCRIPT}" "${MISSING_FLOW_APP_DIR}" >/dev/null 2>"${TMPDIR}/missing-flow.err"; then
  echo "[FAIL] source fallback patch should fail when one expected authn flow disappears"
  exit 1
else
  assert_contains "${TMPDIR}/missing-flow.err" "source fallback patch fails loud on missing register flow" "register service dashboard fallback"
fi

VERIFY_DIST="${TMPDIR}/verify-dist"
mkdir -p "${VERIFY_DIST}"

cat >"${VERIFY_DIST}/safe-fixture.js" <<'EOF'
const dashboardHref = "/dashboard";
const redirect = window.location.origin+r;
EOF

python3 "${VERIFY_SCRIPT}" "${VERIFY_DIST}" >/dev/null
echo "[PASS] verifier allows canonical /dashboard literals when LMS_BASE_URL fallback is gone"

VERIFY_MAP_DIST="${TMPDIR}/verify-map-dist"
mkdir -p "${VERIFY_MAP_DIST}"

cat >"${VERIFY_MAP_DIST}/safe-fixture.js" <<'EOF'
const dashboardHref = "/dashboard";
const redirect = window.location.origin+r;
EOF

cat >"${VERIFY_MAP_DIST}/safe-fixture.js.map" <<'EOF'
{"sources":["app.js"],"names":["LMS_BASE_URL"],"mappings":"AAAA","x_fallback":"`${getConfig().LMS_BASE_URL}/dashboard`"}
EOF

python3 "${VERIFY_SCRIPT}" "${VERIFY_MAP_DIST}" >/dev/null
echo "[PASS] verifier ignores dashboard fallback residues that survive only in source maps"

cat >"${VERIFY_DIST}/broken-fixture.js" <<'EOF'
const redirect = `${getConfig().LMS_BASE_URL}/dashboard`;
const compat = window.location.origin+r;
EOF

if python3 "${VERIFY_SCRIPT}" "${VERIFY_DIST}" >/dev/null 2>&1; then
  echo "[FAIL] verifier should fail when LMS_BASE_URL dashboard fallback survives"
  exit 1
else
  echo "[PASS] verifier fails when LMS_BASE_URL dashboard fallback survives"
fi

echo "AUTHN_DEEP_ROUTE_HANDOFF_PATCH_OK"
