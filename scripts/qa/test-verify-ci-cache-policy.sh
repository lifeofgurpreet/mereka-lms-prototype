#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t verify-ci-cache-policy.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/repo"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.benchmarks/' \
    --exclude '.venv/' \
    --exclude 'tutor_env/data/' \
    "$REPO_ROOT/" "$tmpdir/repo/"
else
  (
    cd "$REPO_ROOT"
    tar \
      --exclude='.git' \
      --exclude='.benchmarks' \
      --exclude='.venv' \
      --exclude='tutor_env/data' \
      -cf - .
  ) | (
    cd "$tmpdir/repo"
    tar -xf -
  )
fi
cd "$tmpdir/repo"

if ! bash scripts/qa/verify-ci-cache-policy.sh >/tmp/test-verify-ci-cache-policy-pass.log 2>&1; then
  echo "Expected cache policy check to pass on a clean copy."
  cat /tmp/test-verify-ci-cache-policy-pass.log
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

workflow = Path(".github/workflows/smoke-unauthenticated.yml")
text = workflow.read_text(encoding="utf-8")
text = text.replace("uses: ./.github/actions/setup-playwright", "uses: actions/setup-node@53b83947a5a98c8d113130e565377fae1a50d02f  # v6.3.0", 1)
workflow.write_text(text, encoding="utf-8")
PY

if bash scripts/qa/verify-ci-cache-policy.sh >/tmp/test-verify-ci-cache-policy-workflow.log 2>&1; then
  echo "Expected cache policy check to fail when smoke-unauthenticated bypasses setup-playwright."
  cat /tmp/test-verify-ci-cache-policy-workflow.log
  exit 1
fi

if ! rg -q "smoke-unauthenticated uses shared Node Playwright action" /tmp/test-verify-ci-cache-policy-workflow.log; then
  echo "Expected workflow drift log to mention the missing shared Playwright action."
  cat /tmp/test-verify-ci-cache-policy-workflow.log
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

build_script = Path("scripts/infra/build-openedx-image.sh")
text = build_script.read_text(encoding="utf-8")
text = text.replace('  --set "${BAKE_TARGET}.cache-from=type=gha,scope=${GHA_SCOPE}"\n', '', 1)
build_script.write_text(text, encoding="utf-8")
PY

if bash scripts/qa/verify-ci-cache-policy.sh >/tmp/test-verify-ci-cache-policy-build.log 2>&1; then
  echo "Expected cache policy check to fail when OpenEdX build loses gha cache restore."
  cat /tmp/test-verify-ci-cache-policy-build.log
  exit 1
fi

if ! rg -q "build-openedx-image uses profile-scoped GHA cache restore" /tmp/test-verify-ci-cache-policy-build.log; then
  echo "Expected build drift log to mention the missing OpenEdX GHA cache restore."
  cat /tmp/test-verify-ci-cache-policy-build.log
  exit 1
fi

if ! rg -q --fixed-strings '"${IMAGE_REPO}:${PRIMARY_TAG}"' scripts/infra/build-openedx-image.sh; then
  echo "Expected cache policy verifier to remain read-only."
  cat scripts/infra/build-openedx-image.sh
  exit 1
fi

echo "PASS test-verify-ci-cache-policy"
