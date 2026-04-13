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

cat > "$tmpdir/.github/workflows/codeql.yml" <<'YAML'
name: CodeQL
on: [push]
jobs:
  analyze:
    runs-on: mereka-k8s-heavy-builders
    steps:
      - run: echo codeql
YAML

cd "$tmpdir"

run_verify() {
  env -u CI_CHANGED_FILES \
      -u VERIFY_CI_RUNNER_POLICY_SCOPE \
      -u VERIFY_CI_RUNNER_POLICY_CHANGED_FILES \
      ./scripts/qa/verify-ci-runner-policy.sh
}

if run_verify >/tmp/test-runner-policy-pass.log 2>&1; then
  :
else
  echo "Expected baseline ARC workflow to pass."
  cat /tmp/test-runner-policy-pass.log
  exit 1
fi

# Fastlane (PR #1518, #1524) allows lightweight orchestration jobs to use
# GitHub-hosted runners. The hard constraint is that *heavy build jobs* must
# still run on ARC (heavy-builders or fastlane selector which falls back to
# heavy-builders). The old "any ubuntu-latest fails" test is no longer
# accurate — we now test that heavy-build jobs CANNOT escape ARC.
cat > ".github/workflows/fail-heavy-hosted.yml" <<'YAML'
name: fail-heavy-hosted
on: [push]
jobs:
  build-openedx:
    runs-on: ubuntu-latest
    steps:
      - run: echo bad
YAML

if run_verify >/tmp/test-runner-policy-fail.log 2>&1; then
  echo "Expected heavy build job on hosted runner to fail, but verifier passed."
  cat /tmp/test-runner-policy-fail.log
  exit 1
fi

if ! rg -q "heavy build job and must not use GitHub-hosted runner" /tmp/test-runner-policy-fail.log; then
  echo "Expected failure log to mention heavy build job violation."
  cat /tmp/test-runner-policy-fail.log
  exit 1
fi

rm -f ".github/workflows/fail-heavy-hosted.yml"

# Expression-based runs-on must also be rejected when it's not a recognized
# fastlane selector (arbitrary expressions are not allowed).
cat > ".github/workflows/fail-unknown-expr.yml" <<'YAML'
name: fail-unknown-expr
on: [push]
jobs:
  bad:
    runs-on: ${{ env.SOME_RANDOM_LABEL }}
    steps:
      - run: echo bad
YAML

if run_verify >/tmp/test-runner-policy-expr-fail.log 2>&1; then
  echo "Expected unknown-expression runs-on to fail, but verifier passed."
  cat /tmp/test-runner-policy-expr-fail.log
  exit 1
fi

if ! rg -q "not a recognized fastlane selector" /tmp/test-runner-policy-expr-fail.log; then
  echo "Expected failure log to mention unrecognized fastlane selector."
  cat /tmp/test-runner-policy-expr-fail.log
  exit 1
fi

rm -f ".github/workflows/fail-unknown-expr.yml"

# Fastlane selector expression is ALLOWED for heavy build jobs.
cat > ".github/workflows/pass-fastlane.yml" <<'YAML'
name: pass-fastlane
on: [push]
jobs:
  select-build-lane:
    runs-on: ubuntu-latest
    outputs:
      runner_label: mereka-k8s-heavy-builders
    steps:
      - run: echo select
  build-mfe:
    needs: select-build-lane
    runs-on: ${{ needs.select-build-lane.outputs.runner_label }}
    steps:
      - run: echo build
YAML

if ! run_verify >/tmp/test-runner-policy-fastlane.log 2>&1; then
  echo "Expected fastlane selector pattern to pass, but verifier failed."
  cat /tmp/test-runner-policy-fastlane.log
  exit 1
fi

rm -f ".github/workflows/pass-fastlane.yml"

# Lightweight orchestration jobs using ubuntu-latest should still pass.
cat > ".github/workflows/pass-lightweight.yml" <<'YAML'
name: pass-lightweight
on: [push]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: echo lint
YAML

if ! run_verify >/tmp/test-runner-policy-lightweight.log 2>&1; then
  echo "Expected lightweight hosted job to pass under fastlane policy."
  cat /tmp/test-runner-policy-lightweight.log
  exit 1
fi

rm -f ".github/workflows/pass-lightweight.yml"

echo "PASS test-verify-ci-runner-policy"
