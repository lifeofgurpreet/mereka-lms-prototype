#!/usr/bin/env bash
# Guardrail: block hardcoded local developer repo paths in tracked scripts.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
TARGET_PATH="/home/dev/code/mereka-lms"
ALLOWLIST_FILE="${ALLOWLIST_FILE_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/hardcoded-dev-path-allowlist.txt}"

echo "=== Hardcoded Dev Path Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo "Blocked pattern: ${TARGET_PATH}"
echo "Allowlist: ${ALLOWLIST_FILE}"
echo

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: ${REPO_ROOT} is not a git worktree" >&2
  exit 2
fi

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "ERROR: allowlist file not found: $ALLOWLIST_FILE" >&2
  exit 2
fi

matches_raw="$(
  git -C "$REPO_ROOT" grep -nF "$TARGET_PATH" -- \
    scripts \
    ':(exclude)scripts/qa/verify-no-hardcoded-dev-paths.sh' \
    ':(exclude)scripts/qa/test-verify-no-hardcoded-dev-paths.sh' \
  || true
)"
mapfile -t allowlisted_files < <(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ALLOWLIST_FILE"
)

if [[ -z "$matches_raw" ]]; then
  if [[ "${#allowlisted_files[@]}" -gt 0 ]]; then
    echo "WARN: allowlist contains stale entries but no matches remain:"
    printf '  %s\n' "${allowlisted_files[@]}"
  fi
  echo "PASS: no hardcoded developer-local repo paths found in scripts."
  exit 0
fi

mapfile -t matched_files < <(printf '%s\n' "$matches_raw" | cut -d: -f1 | sort -u)

unexpected=()
for file in "${matched_files[@]}"; do
  if ! printf '%s\n' "${allowlisted_files[@]}" | grep -Fxq "$file"; then
    unexpected+=("$file")
  fi
done

stale=()
for file in "${allowlisted_files[@]}"; do
  if ! printf '%s\n' "${matched_files[@]}" | grep -Fxq "$file"; then
    stale+=("$file")
  fi
done

if [[ "${#unexpected[@]}" -gt 0 ]]; then
  echo "FAIL: hardcoded developer-local path contract drift detected."
  echo
  echo "New non-allowlisted files:"
  printf '  %s\n' "${unexpected[@]}"
  echo
  echo "Current matches:"
  printf '%s\n' "$matches_raw"
  exit 1
fi

if [[ "${#stale[@]}" -gt 0 ]]; then
  echo "WARN: stale allowlist entries detected (safe to remove):"
  printf '  %s\n' "${stale[@]}"
fi

echo "PASS: hardcoded developer-local paths match the allowlisted baseline."
