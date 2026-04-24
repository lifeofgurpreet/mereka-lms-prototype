#!/usr/bin/env bash
# Verify that no Active security exception in docs/policies/operations/SECURITY_EXCEPTIONS.md
# is past its expiry date.
#
# Exit codes:
#   0 — all Active exceptions are within their expiry window (warnings allowed)
#   1 — one or more Active exceptions are expired
#
# Usage:
#   ./scripts/qa/verify-security-exceptions.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTER="${ROOT_DIR}/docs/policies/operations/SECURITY_EXCEPTIONS.md"

if [[ ! -f "${REGISTER}" ]]; then
  echo "ERROR: Register not found: ${REGISTER}" >&2
  exit 1
fi

TODAY="$(date -u +%Y-%m-%d)"

# Convert a YYYY-MM-DD date to an integer YYYYMMDD for easy numeric comparison.
date_to_int() {
  echo "${1//-/}"
}

TODAY_INT="$(date_to_int "${TODAY}")"
WARN_DATE_INT="$(date_to_int "$(date -u -d "${TODAY} + 30 days" +%Y-%m-%d 2>/dev/null || date -u -v+30d +%Y-%m-%d)")"

expired_count=0
warn_count=0

printf "\nSecurity Exceptions Register — %s\n" "${TODAY}"
printf "%-10s  %-12s  %-12s  %-10s  %s\n" "ID" "Expiry" "Risk" "Status" "Result"
printf -- "%-10s  %-12s  %-12s  %-10s  %s\n" "----------" "------------" "------------" "----------" "------"

# Parse the markdown table.  We look for lines that start with | SEC- to pick up
# only data rows (skipping the header and separator rows).
while IFS='|' read -r _ id description risk justification owner accepted expiry status _; do
  # Strip leading/trailing whitespace from each field.
  id="$(echo "${id}" | xargs)"
  risk="$(echo "${risk}" | xargs)"
  expiry="$(echo "${expiry}" | xargs)"
  status="$(echo "${status}" | xargs)"

  # Skip rows that don't look like real data (header, separator, empty).
  if [[ ! "${id}" =~ ^SEC-[0-9]+ ]]; then
    continue
  fi

  # Only enforce Active exceptions.
  if [[ "${status}" != "Active" ]]; then
    printf "%-10s  %-12s  %-12s  %-10s  SKIP (status=%s)\n" \
      "${id}" "${expiry}" "${risk}" "${status}" "${status}"
    continue
  fi

  expiry_int="$(date_to_int "${expiry}")"

  if (( expiry_int < TODAY_INT )); then
    result="EXPIRED"
    expired_count=$(( expired_count + 1 ))
  elif (( expiry_int <= WARN_DATE_INT )); then
    result="EXPIRING SOON"
    warn_count=$(( warn_count + 1 ))
  else
    result="OK"
  fi

  printf "%-10s  %-12s  %-12s  %-10s  %s\n" \
    "${id}" "${expiry}" "${risk}" "${status}" "${result}"

done < <(grep '^\s*|' "${REGISTER}")

printf "\n"
printf "Summary: %d expired, %d expiring within 30 days\n" \
  "${expired_count}" "${warn_count}"

if (( warn_count > 0 )); then
  printf "\nWARNING: %d exception(s) expire within 30 days — renew before expiry.\n" \
    "${warn_count}"
fi

if (( expired_count > 0 )); then
  printf "\nFAIL: %d Active exception(s) are past their expiry date.\n" \
    "${expired_count}"
  printf "Renew or revoke them in %s before re-running.\n" \
    "docs/policies/operations/SECURITY_EXCEPTIONS.md"
  exit 1
fi

printf "\nOK — all Active exceptions are within their expiry window.\n"
