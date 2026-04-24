#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
BLOCKED_PREFIX="/home/gurpreet/"
ALLOWLIST_FILE="${ALLOWLIST_FILE_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/hardcoded-user-path-allowlist.txt}"

echo "=== Hardcoded User Path Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo "Blocked prefix: ${BLOCKED_PREFIX}"
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
  cd "$REPO_ROOT"
  rg -nF \
    --glob '*.py' \
    --glob '*.sh' \
    --glob '!scripts/qa/verify-no-hardcoded-user-paths.sh' \
    --glob '!scripts/qa/test-verify-no-hardcoded-user-paths.sh' \
    "$BLOCKED_PREFIX" \
    scripts \
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
  echo "PASS: no hardcoded user-local paths found in scripts."
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
  echo "FAIL: hardcoded user-local path drift detected."
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

echo "PASS: hardcoded user-local paths match the allowlisted baseline."
