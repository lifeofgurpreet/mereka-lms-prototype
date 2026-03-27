#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-siteconfig-authority.sh"
ALLOWLIST_FILE="${REPO_ROOT}/scripts/qa/fixtures/siteconfig-authority-allowlist.txt"

"$VERIFY_SCRIPT" >/dev/null
echo "PASS baseline SiteConfiguration authority allowlist passes"

ENTRY_COUNT="$(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ALLOWLIST_FILE" | wc -l | tr -d ' '
)"

EMPTY_ALLOWLIST="$(mktemp)"
trap 'rm -f "$EMPTY_ALLOWLIST"' EXIT

if [[ "$ENTRY_COUNT" -gt 0 ]]; then
  if ALLOWLIST_FILE_OVERRIDE="$EMPTY_ALLOWLIST" "$VERIFY_SCRIPT" >/dev/null 2>&1; then
    echo "FAIL expected failure with empty SiteConfiguration authority allowlist" >&2
    exit 1
  fi
  echo "PASS empty SiteConfiguration authority allowlist fails as expected"
else
  ALLOWLIST_FILE_OVERRIDE="$EMPTY_ALLOWLIST" "$VERIFY_SCRIPT" >/dev/null
  echo "PASS empty SiteConfiguration authority allowlist passes because candidate count is zero"
fi

echo "OK"
