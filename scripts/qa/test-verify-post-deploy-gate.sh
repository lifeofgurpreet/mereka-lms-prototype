#!/usr/bin/env bash
# Seeded-defect self-test for verify-post-deploy-gate.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-post-deploy-gate.sh"

tmpdir="$(mktemp -d -t verify-post-deploy-gate.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/qa" "$tmpdir/docs/operations"

write_pass_fixtures() {
  cat >"$tmpdir/.github/workflows/post-deploy-e2e.yml" <<'EOF'
name: post-deploy-e2e
on:
  workflow_run:
    workflows: ["deploy"]
    types: [completed]
  workflow_dispatch:
concurrency:
  group: post-deploy-e2e
permissions:
  statuses: write
jobs:
  e2e:
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - run: echo "set should_run output"
      - run: echo "post commit status to /statuses/"
      - run: echo "critical login enroll video forum certificate paths"
      - uses: actions/upload-artifact@v4
EOF

  cat >"$tmpdir/scripts/qa/verify-post-deploy-gate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "fixture"
EOF
  chmod +x "$tmpdir/scripts/qa/verify-post-deploy-gate.sh"

  cat >"$tmpdir/docs/operations/POST_DEPLOY_GATE.md" <<'EOF'
# Post Deploy Gate
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" --mode offline >/tmp/verify-post-deploy-gate.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" --mode offline >/tmp/verify-post-deploy-gate.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-post-deploy-gate.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "offline gate wiring fixture passes"

cat >"$tmpdir/.github/workflows/post-deploy-e2e.yml" <<'EOF'
name: post-deploy-e2e
on:
  workflow_run:
    workflows: ["deploy"]
    types: [completed]
concurrency:
  group: post-deploy-e2e
permissions:
  statuses: write
jobs:
  e2e:
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - run: echo "set should_run output"
      - run: echo "post commit status to /statuses/"
      - run: echo "critical login enroll video forum paths"
      - uses: actions/upload-artifact@v4
EOF
run_expect_fail "missing workflow_dispatch and certificate critical path are rejected"

echo "OK"
