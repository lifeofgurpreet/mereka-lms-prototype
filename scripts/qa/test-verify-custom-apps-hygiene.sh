#!/usr/bin/env bash
# Seeded-defect self-test for verify-custom-apps-hygiene.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-custom-apps-hygiene.sh"

tmpdir="$(mktemp -d -t custom-apps-hygiene.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/infrastructure/tutor/custom-apps/app_one"
cat >"$tmpdir/infrastructure/tutor/custom-apps/app_one/setup.py" <<'EOF'
from setuptools import setup
setup(name="app-one", version="0.0.1")
EOF
cat >"$tmpdir/infrastructure/tutor/custom-apps/app_one/runtime.db" <<'EOF'
sqlite
EOF

git init -q "$tmpdir"
(
  cd "$tmpdir"
  git add infrastructure/tutor/custom-apps/app_one/setup.py \
    infrastructure/tutor/custom-apps/app_one/runtime.db
)

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-custom-apps-hygiene.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-custom-apps-hygiene.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-custom-apps-hygiene.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail "tracked runtime db file is rejected"

(
  cd "$tmpdir"
  git rm --cached -q infrastructure/tutor/custom-apps/app_one/runtime.db
)
run_expect_pass "clean tracked custom-app surface passes"

echo "OK"
