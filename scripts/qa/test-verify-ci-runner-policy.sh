#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/scripts/qa/verify-ci-runner-policy.sh"

tmpdir="$(mktemp -d -t verify-ci-runner-policy.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/scripts/qa" "$tmpdir/.github/workflows" "$tmpdir/docs/ops/ci-cd" "$tmpdir/docs/policies/operations"
cp "$SOURCE_SCRIPT" "$tmpdir/scripts/qa/verify-ci-runner-policy.sh"
chmod +x "$tmpdir/scripts/qa/verify-ci-runner-policy.sh"

cat > "$tmpdir/docs/policies/operations/CI_RUNNER_POLICY.md" <<'MD'
# CI Runner Policy
ARC-first policy document (test fixture).
MD

cat > "$tmpdir/.github/workflows/pass.yml" <<'YAML'
name: pass
on: [push]
jobs:
  good:
    runs-on: mereka-k8s-runners
    steps:
      - run: echo ok
YAML

cd "$tmpdir"

if ./scripts/qa/verify-ci-runner-policy.sh >/tmp/test-runner-policy-pass.log 2>&1; then
  :
else
  echo "Expected baseline ARC workflow to pass."
  cat /tmp/test-runner-policy-pass.log
  exit 1
fi

cat > ".github/workflows/fail-linux.yml" <<'YAML'
name: fail-linux
on: [push]
jobs:
  bad:
    runs-on: ubuntu-latest
    steps:
      - run: echo bad
YAML

if ./scripts/qa/verify-ci-runner-policy.sh >/tmp/test-runner-policy-fail.log 2>&1; then
  echo "Expected ubuntu-latest policy violation to fail, but verifier passed."
  cat /tmp/test-runner-policy-fail.log
  exit 1
fi

if ! rg -q "GitHub-hosted Linux runner" /tmp/test-runner-policy-fail.log; then
  echo "Expected failure log to mention GitHub-hosted Linux runner violation."
  cat /tmp/test-runner-policy-fail.log
  exit 1
fi

rm -f ".github/workflows/fail-linux.yml"

echo "PASS test-verify-ci-runner-policy"
