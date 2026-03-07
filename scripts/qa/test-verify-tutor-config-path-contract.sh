#!/usr/bin/env bash
# Seeded-defect self-test for verify-tutor-config-path-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-tutor-config-path-contract.sh"

tmpdir="$(mktemp -d -t verify-tutor-config-path.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/infrastructure/tutor" "$tmpdir/docs" "$tmpdir/specs"

cat >"$tmpdir/infrastructure/tutor/config.example.yml" <<'EOF'
# Canonical config template
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-tutor-config-path.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-tutor-config-path.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-tutor-config-path.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/docs/ok.md" <<'EOF'
# Docs

Use infrastructure/tutor/config.example.yml.
EOF
run_expect_pass "canonical path references pass"

cat >"$tmpdir/docs/bad.md" <<'EOF'
# Docs

Legacy path: tutor_env/config.example.yml
EOF
run_expect_fail "stale tutor_env config template path is rejected"

echo "OK"
