#!/usr/bin/env bash
# Seeded-defect self-test for verify-evidence-redaction.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-evidence-redaction.sh"

tmpdir="$(mktemp -d -t verify-evidence-redaction.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/docs/evidence/operations"

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" STRICT=1 bash "$VERIFY" >/tmp/verify-evidence-redaction.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" STRICT=1 bash "$VERIFY" >/tmp/verify-evidence-redaction.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-evidence-redaction.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/docs/evidence/operations/safe.md" <<'EOF'
# Evidence
Set-Cookie: <REDACTED>
Cookie: <REDACTED>
Authorization: Bearer <REDACTED>
EOF
run_expect_pass "redacted evidence passes"

cat >"$tmpdir/docs/evidence/operations/leak.log" <<'EOF'
HTTP/1.1 200 OK
Set-Cookie: sessionid=abc123def456ghi789; Path=/; Secure
EOF
run_expect_fail "raw set-cookie material is rejected"

echo "OK"
