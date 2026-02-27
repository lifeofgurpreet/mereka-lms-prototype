#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

log_pass() {
  echo "[PASS] $*"
}

log_fail() {
  echo "[FAIL] $*"
}

log_skip() {
  echo "[SKIP] $*"
}

fail_count=0

check_exists_and_pattern() {
  local file_path="$1"
  local pattern="$2"
  local description="$3"

  if [[ ! -f "$file_path" ]]; then
    log_fail "$description: missing $file_path"
    fail_count=$((fail_count + 1))
    return
  fi

  if [[ -n "$pattern" ]] && ! rg -q "$pattern" "$file_path" 2>/dev/null; then
    log_fail "$description: '$file_path' missing pattern '$pattern'"
    fail_count=$((fail_count + 1))
    return
  fi

  log_pass "$description"
}

LMS_RTL_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss"
CMS_RTL_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass/studio-main-v1-rtl.scss"

check_exists_and_pattern "$LMS_RTL_FILE" "@import ['\"]lms-main-v1['\"]" "LMS RTL entrypoint exists and imports lms-main-v1"
check_exists_and_pattern "$CMS_RTL_FILE" "@import \"build-v1\"" "Studio RTL entrypoint exists and imports build-v1"
check_exists_and_pattern "$CMS_RTL_FILE" "@import \"../../../scss/theme\"" "Studio RTL entrypoint includes shared theme import"

if [[ $fail_count -eq 0 ]]; then
  log_pass "RTL entrypoint import contracts validated"
fi

if [[ "${CHECK_RTL_LIVE:-}" == "1" ]]; then
  LMS_URL="${LMS_URL:-https://academyv2.mereka.dev}"
  APP_URL="${APP_URL:-https://apps.academyv2.mereka.dev}"
  TEST_PATH="${TEST_PATH:-/account/settings}"
  RTL_MARKER="${RTL_MARKER:-dir=\"rtl\"}"

  for target in "$LMS_URL" "$APP_URL"; do
    if ! command -v curl >/dev/null 2>&1; then
      log_skip "curl missing; skip live RTL probe"
      break
    fi

    response_code=""
    response_body=""
    response_code=$(curl -s -o /tmp/mereka_rtl_probe.html -w "%{http_code}" --max-time 25 "${target}${TEST_PATH}?lang=ar" || true)
    if [[ "$response_code" != "200" ]]; then
      log_fail "Live RTL smoke for ${target}: HTTP ${response_code}"
      fail_count=$((fail_count + 1))
      continue
    fi

    response_body=$(cat /tmp/mereka_rtl_probe.html)
    if printf '%s' "$response_body" | rg -q "$RTL_MARKER"; then
      log_pass "Live RTL smoke for ${target}: direction marker found"
    else
      log_fail "Live RTL smoke for ${target}: direction marker '${RTL_MARKER}' not present"
      fail_count=$((fail_count + 1))
    fi
  done
fi

if [[ $fail_count -gt 0 ]]; then
  log_fail "RTL theme validation failed with $fail_count issue(s)"
  exit 1
fi

log_pass "RTL theme validation completed"
