#!/usr/bin/env bash
# @covers AC-023
# @spec: slo-sla-service-level-management_spec.md
# Validate SLA evidence bundles do not contain obvious secret patterns.
#
# Usage:
#   ./scripts/qa/verify-sla-report-security.sh var/slo-sla/<stamp>
set -euo pipefail

DIR="${1:-}"
if [[ -z "$DIR" ]]; then
  echo "SKIP: No artifact directory provided (usage: $0 <artifact_dir>)"
  exit 0
fi
if [[ ! -d "$DIR" ]]; then
  echo "SKIP: Artifact directory not found: $DIR"
  exit 0
fi

# Reuse the same patterns as scan-secrets-fast.
declare -A PATTERNS=(
  ["aws_access_key"]="AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}"
  ["private_key"]="-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----"
  ["github_token"]="ghp_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{20,}"
  ["slack_token"]="xox[baprs]-[0-9A-Za-z-]{10,}"
  ["google_api_key"]="AIza[0-9A-Za-z_-]{20,}"
  ["stripe_live_key"]="sk_live_[0-9A-Za-z]{16,}|rk_live_[0-9A-Za-z]{16,}"
  ["mongo_uri_with_password"]="mongodb\\+srv://[^[:space:]]+:[^[:space:]@]+@"
)

hits=0
for name in "${!PATTERNS[@]}"; do
  pattern="${PATTERNS[$name]}"
  if rg -n -- "$pattern" "$DIR" >/dev/null 2>&1; then
    echo "[FAIL] Secret-like pattern detected in SLA evidence bundle: $name" >&2
    hits=$((hits + 1))
  fi
done

if [[ "$hits" -gt 0 ]]; then
  exit 1
fi

echo "OK"

