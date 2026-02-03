#!/usr/bin/env bash
# Simple smoke test against the GKE URLs.
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

check academyv2.mereka.io /
check studio.academyv2.mereka.io /
check apps.academyv2.mereka.io /authn/login
check skillourfuture.academy.mereka.io /
check academy.biji-biji.com /

echo "Smoke tests completed successfully."
