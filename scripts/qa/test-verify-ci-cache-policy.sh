#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_MODE="${TEST_VERIFY_CI_CACHE_POLICY_SCOPE:-}"
CHANGED_FILES_RAW="${TEST_VERIFY_CI_CACHE_POLICY_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"
tmpdir="$(mktemp -d -t verify-ci-cache-policy.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

should_skip_scope() {
  local changed_path

  if [[ "$SCOPE_MODE" != "changed" ]]; then
    return 1
  fi

  if [[ -z "${CHANGED_FILES_RAW//[[:space:]]/}" ]]; then
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -z "$changed_path" ]] && continue
    case "$changed_path" in
      .github/workflows/build-tutor-images.yml|\
      .github/workflows/e2e-tests.yml|\
      .github/workflows/operations-gates-runtime.yml|\
      .github/workflows/post-deploy-e2e.yml|\
      .github/workflows/smoke-authenticated.yml|\
      .github/workflows/smoke-unauthenticated.yml|\
      .github/workflows/ci.yml|\
      .github/actions/setup-playwright/*|\
      .github/actions/setup-python-playwright/*|\
      docker-bake.hcl|\
      scripts/infra/build-openedx-image.sh|\
      scripts/infra/build-mfe-image.sh|\
      scripts/qa/test-verify-ci-cache-policy.sh|\
      scripts/qa/verify-ci-cache-policy.sh)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS test-verify-ci-cache-policy (scope skip: no ci-cache-policy-relevant changes)"
  exit 0
fi

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

bake_file = Path("docker-bake.hcl")
text = bake_file.read_text(encoding="utf-8")
text = text.replace('    "type=gha,scope=${OPENEDX_PROOF_GHA_SCOPE}",\n', '', 1)
bake_file.write_text(text, encoding="utf-8")
PY

if bash scripts/qa/verify-ci-cache-policy.sh >/tmp/test-verify-ci-cache-policy-build.log 2>&1; then
  echo "Expected cache policy check to fail when OpenEdX build loses gha cache restore."
  cat /tmp/test-verify-ci-cache-policy-build.log
  exit 1
fi

if ! rg -q "openedx-proof resolves GHA cache restore" /tmp/test-verify-ci-cache-policy-build.log; then
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
