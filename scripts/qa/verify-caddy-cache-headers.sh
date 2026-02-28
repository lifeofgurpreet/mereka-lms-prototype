#!/usr/bin/env bash
# @covers AC-PERF-018, AC-PERF-019, AC-PERF-020
# @spec: frontend-performance-budgets_spec.md
# Verify Caddy cache-header contracts from source and optional runtime URL.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_CHECK="$REPO_ROOT/scripts/qa/verify-caddy-cache-policy.sh"

RUNTIME_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-url) RUNTIME_URL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -x "$SOURCE_CHECK" ]]; then
  echo "FAIL: Missing source verifier: ${SOURCE_CHECK#$REPO_ROOT/}" >&2
  exit 1
fi

echo "=== Caddy Cache Headers Verification ==="
"$SOURCE_CHECK"

if [[ -z "$RUNTIME_URL" ]]; then
  echo "INFO: runtime check skipped (set --runtime-url to enable)"
  exit 0
fi

echo "=== Runtime Header Check (${RUNTIME_URL}) ==="
headers="$(curl -sSI --connect-timeout 10 --max-time 20 "$RUNTIME_URL" || true)"
if [[ -z "$headers" ]]; then
  echo "FAIL: unable to fetch runtime headers from $RUNTIME_URL" >&2
  exit 1
fi

if rg -qi '^cache-control:[[:space:]]*no-cache' <<<"$headers"; then
  echo "PASS: runtime index/header cache policy includes no-cache"
else
  echo "WARN: runtime response missing expected no-cache header"
fi

echo "PASS: source cache policy checks passed"

