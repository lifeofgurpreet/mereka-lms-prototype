#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_MODE="${VERIFY_VERIFICATION_CATALOG_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_VERIFICATION_CATALOG_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"
tmpdir="$(mktemp -d -t verify-verification-catalog.XXXXXX)"
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
      scripts/qa/*|scripts/governance/*|verification/*|specs/*)
        return 1
        ;;
    esac
  done <<<"$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS test-verify-verification-catalog (scope skip: no verification-catalog-relevant changes)"
  exit 0
fi

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
  rsync -a --delete --exclude '.git/' "$REPO_ROOT/" "$tmpdir/repo/"
else
  (
    cd "$REPO_ROOT"
    tar --exclude='.git' -cf - .
  ) | (
    cd "$tmpdir/repo"
    tar -xf -
  )
fi
cd "$tmpdir/repo"

python3 scripts/qa/generate-verification-catalog.py >/tmp/test-verify-catalog-generate.log 2>&1

if ./scripts/qa/verify-verification-catalog.sh >/tmp/test-verify-catalog-pass.log 2>&1; then
  :
else
  echo "Expected catalog check to pass after regeneration."
  cat /tmp/test-verify-catalog-pass.log
  exit 1
fi

git init -q
git add -f .
cat > scripts/qa/verify-untracked-runner-noise.sh <<'EOF_NOISE'
#!/usr/bin/env bash
echo "runner noise"
EOF_NOISE
chmod +x scripts/qa/verify-untracked-runner-noise.sh

if ./scripts/qa/verify-verification-catalog.sh >/tmp/test-verify-catalog-untracked-noise.log 2>&1; then
  :
else
  echo "Expected untracked verify-*.sh runner noise to stay out of catalog authority."
  cat /tmp/test-verify-catalog-untracked-noise.log
  exit 1
fi
rm -f scripts/qa/verify-untracked-runner-noise.sh

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

if ! rg -q "verification/catalogs/verification_catalog.json" /tmp/test-verify-catalog-fail.log; then
  echo "Expected failure log to list the changed catalog JSON file."
  cat /tmp/test-verify-catalog-fail.log
  exit 1
fi

if [[ "$(cat verification/catalogs/verification_catalog.json)" != "{}" ]]; then
  echo "Expected --check mode to remain read-only."
  cat verification/catalogs/verification_catalog.json
  exit 1
fi

echo "PASS test-verify-verification-catalog"
