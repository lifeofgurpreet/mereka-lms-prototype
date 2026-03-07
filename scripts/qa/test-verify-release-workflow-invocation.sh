#!/usr/bin/env bash
# Seeded-defect self-test for verify-release-workflow-invocation.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-release-workflow-invocation.sh"

tmpdir="$(mktemp -d -t verify-release-workflow-invocation.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/infra" "$tmpdir/docs/operations"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/release.yml" <<'EOF'
name: release
on:
  workflow_dispatch:
  push:
    tags:
      - 'v*'
EOF

  cat >"$tmpdir/scripts/infra/create-release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "release helper"
EOF
  chmod +x "$tmpdir/scripts/infra/create-release.sh"

  cat >"$tmpdir/docs/operations/RELEASE_PROCESS.md" <<'EOF'
# Release Process
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-workflow-invocation.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-release-workflow-invocation.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-release-workflow-invocation.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "release workflow invocation requirements pass"

cat >"$tmpdir/.github/workflows/release.yml" <<'EOF'
name: release
jobs:
  noop:
    runs-on: ubuntu-latest
EOF
run_expect_fail "missing workflow trigger is rejected"

echo "OK"
