#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_SCRIPT="${REPO_ROOT}/infrastructure/tutor/patches/patch-authn-deep-route-handoff.py"

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
assert_contains "${FIXTURE}" "patch routes known MFE deep routes to current apps origin" '/^\/(?:authn|account|course-authoring|authoring|communications|discussions|gradebook|learner-dashboard|learner-record|learning|ora-grading|u)(?:\/|$)/.test(r)?window.location.origin+r:(0,s.zj)().LMS_BASE_URL+r'
assert_contains "${FIXTURE}" "patch scopes only known active MFE deep-route prefixes" 'authn|account|course-authoring|authoring|communications|discussions|gradebook|learner-dashboard|learner-record|learning|ora-grading|u'
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

echo "AUTHN_DEEP_ROUTE_HANDOFF_PATCH_OK"
