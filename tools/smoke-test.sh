#!/usr/bin/env bash
# Simple smoke test against the staging URLs.
set -euo pipefail

echo "Running smoke tests against live domains"

check() {
  local host="$1"
  local path="${2:-/}"
  local expected="${3:-200}"
  local status

  status="$(curl -s -o /dev/null -w "%{http_code}" "https://${host}${path}")"
  if [[ "${status}" != "${expected}" ]]; then
    echo "❌ ${host}${path} expected ${expected} got ${status}"
    exit 1
  fi
  echo "✅ ${host}${path} -> ${status}"
}

check staging.academy.mereka.io /
check studio.staging.academy.mereka.io /
check apps.staging.academy.mereka.io /account

echo "Smoke tests completed successfully."
