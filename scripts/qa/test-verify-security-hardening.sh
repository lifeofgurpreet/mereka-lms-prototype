#!/usr/bin/env bash
# Seeded-defect self-test for verify-security-hardening.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-security-hardening.sh"

tmpdir="$(mktemp -d -t verify-security-hardening.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/scripts/shared" \
  "$tmpdir/plugins" \
  "$tmpdir/deploy/k8s/base/plugins/mfe/apps/mfe" \
  "$tmpdir/deploy/k8s/base/apps/openedx/settings/lms" \
  "$tmpdir/deploy/k8s/base/apps/openedx/settings/cms"

write_contract_helper() {
  cat >"$tmpdir/scripts/shared/mereka_plugin_contract.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mereka_plugin_main_file() {
  local repo_root="$1"
  echo "$repo_root/plugins/mereka.py"
}

mereka_plugin_has_any() {
  local repo_root="$1"
  [[ -f "$repo_root/plugins/mereka.py" ]]
}

mereka_plugin_has_fixed() {
  local repo_root="$1"
  local pattern="$2"
  grep -qF "$pattern" "$repo_root/plugins/mereka.py"
}
EOF
  chmod +x "$tmpdir/scripts/shared/mereka_plugin_contract.sh"
}

write_pass_fixtures() {
  write_contract_helper

  cat >"$tmpdir/plugins/mereka.py" <<'EOF'
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_REPORT_ONLY = False
DEFAULT_THROTTLE_RATES = {}
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_RATES", {})
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
CSP_INCLUDE_NONCE_IN = ("script-src",)
EOF

  cat >"$tmpdir/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile" <<'EOF'
header {
  Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
  X-Content-Type-Options "nosniff"
  X-Frame-Options "DENY"
  Content-Security-Policy "default-src 'self'"
  Referrer-Policy "strict-origin-when-cross-origin"
  Permissions-Policy "camera=(), microphone=()"
}
EOF

  cat >"$tmpdir/deploy/k8s/base/apps/openedx/settings/lms/production.py" <<'EOF'
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_REPORT_ONLY = False
CSP_OBJECT_SRC = ('none',)
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
CSP_INCLUDE_NONCE_IN = ("script-src",)
_auth_url = "https://auth0.mereka.io"
CSP_IMG_SRC = (
    "self",
    "https://cdn.example.com",
)
CSP_MEDIA_SRC = (
    "self",
    "blob:",
)
CSP_FORM_ACTION = ("'self'",)
DEFAULT_THROTTLE_RATES = {
    "login_and_register": "10/minute",
    "password_reset": "5/hour",
}
MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = 5
MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = 3600
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False
CORS_ALLOW_INSECURE = False
OAUTH_ENFORCE_SECURE = True
EOF

  cat >"$tmpdir/deploy/k8s/base/apps/openedx/settings/cms/production.py" <<'EOF'
CORS_ALLOW_INSECURE = False
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-security-hardening.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-security-hardening.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-security-hardening.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "fixture with required hardening settings passes"

cat >"$tmpdir/deploy/k8s/base/apps/openedx/settings/lms/production.py" <<'EOF'
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_REPORT_ONLY = False
CSP_OBJECT_SRC = ('none',)
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
CSP_INCLUDE_NONCE_IN = ("script-src",)
_auth_url = "https://auth0.mereka.io"
CSP_IMG_SRC = (
    "self",
    "https:",
)
CSP_MEDIA_SRC = (
    "self",
    "blob:",
)
CSP_FORM_ACTION = ("'self'",)
DEFAULT_THROTTLE_RATES = {
    "login_and_register": "10/minute",
    "password_reset": "5/hour",
}
MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = 5
MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = 3600
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False
CORS_ALLOW_INSECURE = False
OAUTH_ENFORCE_SECURE = True
EOF
run_expect_fail "CSP wildcard https in IMG_SRC is rejected"

cat >"$tmpdir/deploy/k8s/base/apps/openedx/settings/lms/production.py" <<'EOF'
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_REPORT_ONLY = False
CSP_OBJECT_SRC = ('none',)
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
CSP_INCLUDE_NONCE_IN = ("script-src",)
_auth_url = "https://auth0.mereka.io"
CSP_IMG_SRC = (
    "self",
    "https://cdn.example.com",
)
CSP_MEDIA_SRC = (
    "self",
    "blob:",
)
CSP_FORM_ACTION = ("'self'",)
DEFAULT_THROTTLE_RATES = {
    "login_and_register": "10/minute",
    "password_reset": "5/hour",
}
MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = 5
MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = 3600
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False
CORS_ALLOW_INSECURE = True
OAUTH_ENFORCE_SECURE = False
EOF
run_expect_fail "insecure LMS production defaults are rejected"

echo "OK"
