#!/usr/bin/env bash
# Seeded-defect self-test for verify-csp-headers.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-csp-headers.sh"

tmpdir="$(mktemp -d -t verify-csp-headers.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/shared" "$tmpdir/plugins" "$tmpdir/docs/adr"

write_contract_helper() {
  cat >"$tmpdir/scripts/shared/mereka_plugin_contract.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mereka_plugin_has_fixed() {
  local repo_root="$1"
  local pattern="$2"
  grep -qF "$pattern" "$repo_root/plugins/mereka.py"
}

mereka_plugin_has_regex() {
  local repo_root="$1"
  local pattern="$2"
  grep -qE "$pattern" "$repo_root/plugins/mereka.py"
}
EOF
  chmod +x "$tmpdir/scripts/shared/mereka_plugin_contract.sh"
}

write_pass_fixtures() {
  write_contract_helper

  cat >"$tmpdir/plugins/mereka.py" <<'EOF'
CSP_SCRIPT_SRC = ("'self'", "'unsafe-inline'", "'unsafe-eval'")
CSP_DEFAULT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'")
CSP_IMG_SRC = ("'self'", "https://cdn.example.com")
CSP_CONNECT_SRC = ("'self'", "https://auth0.mereka.io")
CSP_OBJECT_SRC = ("'none'",)
CSP_REPORT_ONLY = True
CSP_REPORT_URI = ""
CSP_INCLUDE_NONCE_IN = ("script-src",)
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
EOF

  cat >"$tmpdir/docs/adr/025-csp-nonce-migration.md" <<'EOF'
# ADR-025: CSP nonce migration
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-csp-headers.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-csp-headers.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-csp-headers.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "required CSP plugin directives and ADR wiring pass"

cat >"$tmpdir/plugins/mereka.py" <<'EOF'
CSP_SCRIPT_SRC = ("'self'", "'unsafe-inline'", "'unsafe-eval'")
CSP_DEFAULT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'")
CSP_IMG_SRC = ("'self'", "https://cdn.example.com")
CSP_CONNECT_SRC = ("'self'", "https://auth0.mereka.io")
CSP_OBJECT_SRC = ("'none'",)
CSP_REPORT_ONLY = True
CSP_INCLUDE_NONCE_IN = ("script-src",)
MIDDLEWARE = ["csp.middleware.CSPMiddleware"]
EOF
run_expect_fail "missing CSP_REPORT_URI wiring is rejected"

echo "OK"
