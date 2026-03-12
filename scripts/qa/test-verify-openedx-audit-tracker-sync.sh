#!/usr/bin/env bash
# Seeded-defect self-test for verify-openedx-audit-tracker-sync.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-openedx-audit-tracker-sync.sh"

tmpdir="$(mktemp -d -t verify-openedx-audit-tracker-sync.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

DOC_DIR="$tmpdir/docs/meta/docs-program/openedx-repo-audit"
mkdir -p "$DOC_DIR"

TRACKER="$DOC_DIR/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md"
BOARD="$DOC_DIR/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md"

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-openedx-audit-tracker-sync.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-openedx-audit-tracker-sync.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-openedx-audit-tracker-sync.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$TRACKER" <<'EOF'
# Tracker

### Post-Audit Implementation Status
| PR | Status |
| --- | --- |
| #101 | merged |
| #102 | open |
EOF

cat >"$BOARD" <<'EOF'
# Board

## Post-Merge Hardening Follow-ups
| PR | Task |
| --- | --- |
| #101 | hardening |
| #102 | follow-up |
EOF
run_expect_pass "tracker and board PR sets stay synchronized"

cat >"$BOARD" <<'EOF'
# Board

## Post-Merge Hardening Follow-ups
| PR | Task |
| --- | --- |
| #101 | hardening |
| #103 | drifted |
EOF
run_expect_fail "tracker/board PR drift is rejected"

echo "OK"
