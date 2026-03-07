#!/usr/bin/env bash
# Seeded-defect self-test for verify-no-hardcoded-secrets.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-no-hardcoded-secrets.sh"

tmpdir="$(mktemp -d -t verify-no-hardcoded-secrets.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s" "$tmpdir/scripts/shared"

cat >"$tmpdir/scripts/shared/ci-skip-guards.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
EOF
chmod +x "$tmpdir/scripts/shared/ci-skip-guards.sh"

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-no-hardcoded-secrets.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-no-hardcoded-secrets.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-no-hardcoded-secrets.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

# Placeholder values should pass.
cat >"$tmpdir/deploy/k8s/values.yaml" <<'EOF'
env:
  AWS_ACCESS_KEY_ID: "${AWS_ACCESS_KEY_ID}"
  NOTE: "example"
EOF
run_expect_pass "placeholder/env-var references are allowlisted"

# Real-looking secrets should fail.
cat >"$tmpdir/deploy/k8s/values.yaml" <<'EOF'
env:
  AWS_ACCESS_KEY_ID: "AKIA1234567890ABCDEF"
EOF
run_expect_fail "hardcoded secret-like values are rejected"

echo "OK"
