#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-siteconfig-authority.sh"
ALLOWLIST_FILE="${REPO_ROOT}/scripts/qa/fixtures/siteconfig-authority-allowlist.txt"
SCOPE_MODE="${TEST_VERIFY_SITECONFIG_AUTHORITY_SCOPE:-}"
CHANGED_FILES_RAW="${TEST_VERIFY_SITECONFIG_AUTHORITY_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

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
      scripts/*|\
      infrastructure/*|\
      .github/workflows/ci.yml)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS test-verify-siteconfig-authority (scope skip: no siteconfig-authority-relevant changes)"
  exit 0
fi

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
