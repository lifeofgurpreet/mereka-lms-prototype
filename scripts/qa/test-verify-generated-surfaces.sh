#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t verify-generated-surfaces.XXXXXX)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/repo"
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$REPO_ROOT" ls-files -z | (
    cd "$REPO_ROOT"
    tar --null -T - -cf -
  ) | (
    cd "$tmpdir/repo"
    tar -xf -
  )
elif command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.git' --exclude '.git/' "$REPO_ROOT/" "$tmpdir/repo/"
else
  (
    cd "$REPO_ROOT"
    tar --exclude='.git' --exclude='.git/*' -cf - .
  ) | (
    cd "$tmpdir/repo"
    tar -xf -
  )
fi
cd "$tmpdir/repo"

if ! bash scripts/qa/verify-generated-surfaces.sh >/tmp/test-verify-generated-surfaces-pass.log 2>&1; then
  echo "Expected generated-surface gate to pass on a clean copy."
  cat /tmp/test-verify-generated-surfaces-pass.log
  exit 1
fi

cat > .github/ci-scripts-runtime.txt <<'EOF_DRIFT'
# drift
EOF_DRIFT

if bash scripts/qa/verify-generated-surfaces.sh >/tmp/test-verify-generated-surfaces-runtime.log 2>&1; then
  echo "Expected generated-surface gate to fail on runtime inventory drift."
  cat /tmp/test-verify-generated-surfaces-runtime.log
  exit 1
fi

if ! rg -q ".github/ci-scripts-runtime.txt" /tmp/test-verify-generated-surfaces-runtime.log; then
  echo "Expected runtime inventory drift log to mention ci-scripts-runtime.txt."
  cat /tmp/test-verify-generated-surfaces-runtime.log
  exit 1
fi

if ! grep -q '^# drift$' .github/ci-scripts-runtime.txt; then
  echo "Expected runtime inventory check to remain read-only."
  cat .github/ci-scripts-runtime.txt
  exit 1
fi

python3 scripts/governance/generate-ci-runtime-inventory.py --write >/tmp/test-verify-generated-surfaces-regen.log 2>&1

cat > generated/tenant-runtime/browser-matrix-dev.json <<'EOF_DRIFT'
{}
EOF_DRIFT

if bash scripts/qa/verify-generated-surfaces.sh >/tmp/test-verify-generated-surfaces-matrix.log 2>&1; then
  echo "Expected generated-surface gate to fail on runtime-routing matrix drift."
  cat /tmp/test-verify-generated-surfaces-matrix.log
  exit 1
fi

if ! rg -q "generated/tenant-runtime/browser-matrix-dev.json" /tmp/test-verify-generated-surfaces-matrix.log; then
  echo "Expected runtime-routing matrix drift log to mention browser-matrix-dev.json."
  cat /tmp/test-verify-generated-surfaces-matrix.log
  exit 1
fi

if [[ "$(cat generated/tenant-runtime/browser-matrix-dev.json)" != "{}" ]]; then
  echo "Expected runtime-routing matrix check to remain read-only."
  cat generated/tenant-runtime/browser-matrix-dev.json
  exit 1
fi

echo "PASS test-verify-generated-surfaces"
