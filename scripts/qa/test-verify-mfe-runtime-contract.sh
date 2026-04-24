#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-mfe-runtime-contract.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

if bash "$VERIFY_SCRIPT" --url >/tmp/mfe_runtime_missing_url.out 2>&1; then
  fail "--url without value should fail"
fi
grep -q "ERROR: --url requires a value" /tmp/mfe_runtime_missing_url.out || fail "missing-value error not surfaced for --url"
grep -q "Usage:" /tmp/mfe_runtime_missing_url.out || fail "usage not printed for --url failure"
pass "missing --url value fails cleanly"

GENERATED_ENV_DIR="${TMPDIR}/generated-env-config"
mkdir -p "$GENERATED_ENV_DIR"

cat >"${GENERATED_ENV_DIR}/env.config.jsx" <<'EOF'
import { getConfig } from '@edx/frontend-platform/config';

const runtimeMarkers = {
  footer: 'MerekaFooter',
  sidebar: 'mereka_learner_sidebar_widget',
  dashboard: 'mereka_dashboard_course_list_context',
};

window.__MEREKA_RUNTIME_MARKERS__ = runtimeMarkers;
window.__MEREKA_RUNTIME_PADDING__ = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
EOF

bash "$VERIFY_SCRIPT" --generated-env-config "${GENERATED_ENV_DIR}/env.config.jsx" >/tmp/mfe_runtime_generated_env_healthy.out 2>&1 \
  || fail "healthy generated env.config.jsx should pass"
grep -q "at most one getConfig declaration/import" /tmp/mfe_runtime_generated_env_healthy.out || fail "healthy generated env.config.jsx did not validate getConfig uniqueness"
pass "healthy generated env.config.jsx passes build-time ownership verifier"

cat >"${GENERATED_ENV_DIR}/duplicate-get-config.env.config.jsx" <<'EOF'
import { getConfig } from '@edx/frontend-platform/config';
import { getConfig } from '@edx/frontend-platform/config';

const runtimeMarkers = {
  footer: 'MerekaFooter',
  sidebar: 'mereka_learner_sidebar_widget',
  dashboard: 'mereka_dashboard_course_list_context',
};

window.__MEREKA_RUNTIME_MARKERS__ = runtimeMarkers;
window.__MEREKA_RUNTIME_PADDING__ = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
EOF

if bash "$VERIFY_SCRIPT" --generated-env-config "${GENERATED_ENV_DIR}/duplicate-get-config.env.config.jsx" >/tmp/mfe_runtime_generated_env_duplicate.out 2>&1; then
  fail "generated env.config.jsx with duplicate getConfig imports should fail"
fi
grep -q "duplicate getConfig" /tmp/mfe_runtime_generated_env_duplicate.out || fail "duplicate generated env.config.jsx did not flag duplicate getConfig"
pass "duplicate getConfig generated env.config.jsx fails build-time ownership verifier"

FAKEBIN="${TMPDIR}/bin"
mkdir -p "$FAKEBIN"

cat >"${FAKEBIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="body"
url=""
for arg in "$@"; do
  case "$arg" in
    http://*|https://*)
      url="$arg"
      ;;
    -I|-sI|-SI|-sSI|-Is|-i|-si|-is)
      mode="headers"
      ;;
  esac
done

if [[ " $* " == *" -o /dev/null "* && " $* " == *" -w %{http_code} "* ]]; then
  mode="status"
fi

if [[ -z "$url" ]]; then
  echo "fake curl missing URL" >&2
  exit 1
fi

parsed="$(URL="$url" python3 - <<'PY'
import os
from urllib.parse import urlsplit

parts = urlsplit(os.environ["URL"])
path = parts.path or "/"
if parts.query:
    path = f"{path}?{parts.query}"
print(parts.netloc)
print(path)
PY
)"
host="$(printf '%s\n' "$parsed" | sed -n '1p')"
path="$(printf '%s\n' "$parsed" | sed -n '2p')"
scenario="healthy"
case "$host" in
  broken.example) scenario="broken" ;;
  healthy.example) scenario="healthy" ;;
esac

bundle_body() {
  python3 - <<'PY'
marker_blob = "mereka_footer org.openedx.frontend.layout.footer.v1 mereka-dashboard-header-slot "
payload = marker_blob + ("x" * 120000)
print(payload, end="")
PY
}

dashboard_html() {
  cat <<'HTML'
<!doctype html>
<html>
  <head><script>window.PARAGON_THEME = 'mereka';</script></head>
  <body><script src="/learner-dashboard/app.1234567890abcdef.js"></script></body>
</html>
HTML
}

env_js() {
  python3 - <<'PY'
payload = "window.__ENV__ = {\"LMS_BASE_URL\":\"https://lms.example.test\",\"SITE_NAME\":\"Mereka\"};\n" + ("a" * 180)
print(payload, end="")
PY
}

authoring_config_json() {
  printf '{"BASE_URL":"https://healthy.example/authoring","LMS_BASE_URL":"https://lms.example.test"}'
}

case "$mode" in
  status)
    printf '200'
    ;;
  headers)
    case "$path" in
      /theme/logo-horizontal.svg|/theme/biji-biji-brand.min.css|/theme/sof-brand.min.css|/theme/core.min.css|/theme/biji-biji/logo-horizontal.svg|/theme/skillourfuture/logo-horizontal.svg)
        if [[ "$path" == *.svg ]]; then
          printf 'content-type: image/svg+xml\r\n'
        else
          printf 'content-type: text/css\r\n'
        fi
        ;;
      /env.config.jsx)
        printf 'content-type: application/javascript\r\n'
        ;;
      /learner-dashboard/env.config.js)
        if [[ "$scenario" == "broken" ]]; then
          printf 'content-type: text/html; charset=utf-8\r\n'
        else
          printf 'content-type: application/javascript\r\n'
        fi
        ;;
      /api/mfe_config/v1?mfe=authoring)
        printf 'content-type: application/json\r\n'
        ;;
      /learner-dashboard/)
        printf 'content-type: text/html; charset=utf-8\r\n'
        ;;
      /learner-dashboard/app.1234567890abcdef.js)
        printf 'content-type: application/javascript\r\n'
        ;;
      *)
        printf 'content-type: text/plain\r\n'
        ;;
    esac
    ;;
  body)
    case "$path" in
      /env.config.jsx)
        printf ''
        ;;
      /learner-dashboard/env.config.js)
        if [[ "$scenario" == "broken" ]]; then
          dashboard_html
        else
          env_js
        fi
        ;;
      /api/mfe_config/v1?mfe=authoring)
        authoring_config_json
        ;;
      /learner-dashboard/)
        dashboard_html
        ;;
      /learner-dashboard/app.1234567890abcdef.js)
        bundle_body
        ;;
      /theme/logo-horizontal.svg|/theme/biji-biji/logo-horizontal.svg|/theme/skillourfuture/logo-horizontal.svg)
        printf '<svg></svg>'
        ;;
      /theme/core.min.css|/theme/biji-biji-brand.min.css|/theme/sof-brand.min.css)
        printf 'body{color:#000;}'
        ;;
      *)
        printf ''
        ;;
    esac
    ;;
esac
EOF
chmod +x "${FAKEBIN}/curl"

PATH="${FAKEBIN}:$PATH" bash "$VERIFY_SCRIPT" --url https://healthy.example >/tmp/mfe_runtime_healthy.out 2>&1 || fail "healthy fake runtime contract should pass"
grep -q "prefixed learner-dashboard env.config.js does not advertise HTML Content-Type" /tmp/mfe_runtime_healthy.out || fail "healthy run did not validate non-HTML prefixed env config"
grep -q "prefixed learner-dashboard env.config.js body is not HTML shell content" /tmp/mfe_runtime_healthy.out || fail "healthy run did not validate non-HTML body"
pass "healthy prefixed env.config.js passes runtime verifier"

if PATH="${FAKEBIN}:$PATH" bash "$VERIFY_SCRIPT" --url https://broken.example >/tmp/mfe_runtime_broken.out 2>&1; then
  fail "broken fake runtime contract should fail"
fi
grep -q "prefixed learner-dashboard env.config.js returned HTML Content-Type" /tmp/mfe_runtime_broken.out || fail "broken run did not flag HTML Content-Type"
grep -q "prefixed learner-dashboard env.config.js body contains HTML shell content" /tmp/mfe_runtime_broken.out || fail "broken run did not flag HTML shell body"
pass "broken prefixed env.config.js fails runtime verifier"

echo "VERIFY_MFE_RUNTIME_CONTRACT_TEST_OK"
