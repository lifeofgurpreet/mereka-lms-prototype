#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t verify-verification-catalog.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

git clone -q "$REPO_ROOT" "$tmpdir/repo"
cd "$tmpdir/repo"

python3 scripts/qa/generate-verification-catalog.py >/tmp/test-verify-catalog-generate.log 2>&1

if ./scripts/qa/verify-verification-catalog.sh >/tmp/test-verify-catalog-pass.log 2>&1; then
  :
else
  echo "Expected catalog check to pass after regeneration."
  cat /tmp/test-verify-catalog-pass.log
  exit 1
fi

cat > verification/catalogs/verification_catalog.json <<'EOF_DRIFT'
{}
EOF_DRIFT

if ./scripts/qa/verify-verification-catalog.sh >/tmp/test-verify-catalog-fail.log 2>&1; then
  echo "Expected failure when catalog JSON drifts from generator output."
  cat /tmp/test-verify-catalog-fail.log
  exit 1
fi

if ! rg -qi "drift|up to date|catalog" /tmp/test-verify-catalog-fail.log; then
  echo "Expected failure log to mention catalog drift."
  cat /tmp/test-verify-catalog-fail.log
  exit 1
fi

echo "PASS test-verify-verification-catalog"
