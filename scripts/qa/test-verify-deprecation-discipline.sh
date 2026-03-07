#!/usr/bin/env bash
# Seeded-defect self-test for verify-deprecation-discipline.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-deprecation-discipline.sh"

tmpdir="$(mktemp -d -t verify-deprecation-discipline.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/scripts" "$tmpdir/deploy" "$tmpdir/infrastructure/tutor"

write_valid_depr() {
  cat >"$tmpdir/DEPR.md" <<'EOF'
# Deprecations

### DEPR-001
- Target removal: 2026-12-31
- Reason: superseded by canonical gate
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-deprecation-discipline.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-deprecation-discipline.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-deprecation-discipline.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_depr
run_expect_pass "valid deprecation registry passes"

cat >"$tmpdir/DEPR.md" <<'EOF'
# Deprecations

### DEPR-001
- Reason: missing target date
EOF
run_expect_fail "entries without target/removal dates are rejected"

write_valid_depr
mkdir -p "$tmpdir/scripts/qa"
cat >"$tmpdir/scripts/qa/bad-reference.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source tools/legacy.sh
EOF
chmod +x "$tmpdir/scripts/qa/bad-reference.sh"
run_expect_fail "active scripts sourcing deprecated tools paths are rejected"

echo "OK"
