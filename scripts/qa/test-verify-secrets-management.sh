#!/usr/bin/env bash
# Seeded-defect self-test for verify-secrets-management.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secrets-management.sh"

tmpdir="$(mktemp -d -t verify-secrets-management.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts/qa" "$tmpdir/.githooks"

write_stub() {
  local path="$1"
  local body="$2"
  cat >"$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
${body}
EOF
  chmod +x "$path"
}

write_pass_fixtures() {
  write_stub "$tmpdir/scripts/qa/verify-no-hardcoded-secrets.sh" 'echo "ok"; exit 0'
  write_stub "$tmpdir/scripts/qa/verify-secrets-naming-convention.sh" 'echo "ok"; exit 0'
  write_stub "$tmpdir/scripts/qa/verify-k8s-secrets-hygiene.sh" 'echo "ok"; exit 0'
  write_stub "$tmpdir/scripts/qa/verify-k8s-externalsecrets.sh" 'echo "ok"; exit 0'

  cat >"$tmpdir/.githooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  chmod +x "$tmpdir/.githooks/pre-commit"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-management.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-management.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secrets-management.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "all child checks passing results in success"

write_stub "$tmpdir/scripts/qa/verify-k8s-externalsecrets.sh" 'echo "seeded failure"; exit 1'
run_expect_fail "child verifier failure is propagated"

echo "OK"
