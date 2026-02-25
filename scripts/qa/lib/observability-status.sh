#!/usr/bin/env bash

# Shared observability status parsing helpers for evidence text artifacts.
# Keeps status checks resilient to ANSI color escapes and accidental substrings.

has_observability_status_line() {
  local evidence_file="$1"
  local token_pattern='(^|[^A-Za-z])(PASS|FAIL|WARN)([^A-Za-z]|$)'
  local line
  local plain

  while IFS= read -r line; do
    plain="$(printf '%s' "$line" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
    if [[ "$plain" =~ $token_pattern ]]; then
      return 0
    fi
  done < "$evidence_file"

  return 1
}

has_observability_required_headers() {
  local evidence_file="$1"
  local line
  local plain
  local found_x_request_id=0
  local found_traceparent=0

  while IFS= read -r line; do
    plain="$(printf '%s' "$line" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
    local normalized="$(printf '%s' "$plain" | tr '[:upper:]' '[:lower:]')"
    if [[ "$normalized" == *"x-request-id"* ]]; then
      found_x_request_id=1
    fi
    if [[ "$normalized" == *"traceparent"* ]]; then
      found_traceparent=1
    fi
  done < "$evidence_file"

  [[ "$found_x_request_id" -eq 1 && "$found_traceparent" -eq 1 ]]
}
