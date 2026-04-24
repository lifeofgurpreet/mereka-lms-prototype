#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_MODE="${VERIFY_MANIFEST_INTEGRITY_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_MANIFEST_INTEGRITY_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

CHECKS=(
  "scripts/qa/verify-ci-script-list.sh"
  "scripts/qa/verify-verification-catalog.sh"
  "scripts/qa/verify-deprecated-verification-hygiene.sh"
)

should_skip_scope() {
  local changed_path
  local workflow_file

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/ci-scripts-static.txt|\
      verification/catalogs/*|\
      verification/manifests/deprecated_verify_scripts.json|\
      scripts/*|\
      Makefile|\
      *.md|\
      *.txt|\
      *.json|\
      *.yml|\
      *.yaml|\
      *.sh|\
      *.py|\
      *.env)
        return 1
        ;;
      .github/workflows/*)
        workflow_file="$REPO_ROOT/$changed_path"
        if [[ ! -f "$workflow_file" ]]; then
          return 1
        fi

        if rg -q 'scripts/|ci-scripts-static|ci-scripts-runtime|run-release-verification-gates' "$workflow_file"; then
          return 1
        fi
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-manifest-integrity (scope skip: no manifest-integrity authority changes)"
  exit 0
fi

echo "=== Verification Manifest Integrity ==="
echo "Repo: $REPO_ROOT"
echo ""

tmpdir="$(mktemp -d -t verify-manifest-integrity.XXXXXX)"
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

WORK_ROOT="$tmpdir/repo"

for check in "${CHECKS[@]}"; do
  abs="$WORK_ROOT/$check"
  if [[ ! -f "$abs" ]]; then
    echo "FAIL missing check script: $check" >&2
    exit 1
  fi
  echo "--- Running: $check ---"
  "$abs"
  echo ""
done

echo "PASS verification manifest integrity checks"
