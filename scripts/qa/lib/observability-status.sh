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
