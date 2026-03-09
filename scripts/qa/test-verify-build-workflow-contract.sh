#!/usr/bin/env bash
# Seeded-defect self-test for verify-build-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-build-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-build-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  workflow_dispatch:
    inputs:
      target_environment:
        type: choice
        options: [production, staging]
permissions:
  contents: write
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - run: ./bin/lms-ops proof --concern release-gate --lane prod --skip-cluster
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: |
            var/ci/build-provenance.json
            var/ci/release-gate-envelope.json
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-build-workflow-contract.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-build-workflow-contract.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-build-workflow-contract.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "build workflow contract passes with lms-ops proof + envelope upload"

# Remove lms-ops call => must fail
cat >"$tmpdir/.github/workflows/build-tutor-images.yml" <<'EOF'
name: build-tutor-images
on:
  workflow_dispatch:
    inputs:
      target_environment:
        type: choice
        options: [production, staging]
permissions:
  contents: write
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - run: echo "push ghcr.io/biji-biji-initiative/mereka-lms/openedx:sha"
      - uses: actions/upload-artifact@v4
        with:
          name: build-provenance
          path: var/ci/build-provenance.json
EOF
run_expect_fail "missing lms-ops proof emission is rejected"

echo "OK"
