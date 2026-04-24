#!/usr/bin/env bash
# @covers AC-012
# @spec: secrets-management_spec.md
# Verify there are no obvious hardcoded secrets under deploy/k8s/.
#
# This is a scoped variant of scripts/qa/scan-secrets-fast.sh.
#
# Usage:
#   ./scripts/qa/verify-no-hardcoded-secrets.sh
set -euo pipefail

ROOT_DIR="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/shared/ci-skip-guards.sh"
require_command rg || exit 0

if [[ ! -d "deploy/k8s" ]]; then
  echo "Missing deploy/k8s" >&2
  exit 1
fi

tmpdir="$(mktemp -d -t verify-no-hardcoded-secrets.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

hits=0

declare -A PATTERNS=(
  ["aws_access_key"]="AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}"
  ["private_key"]="-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----"
  ["github_token"]="ghp_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{20,}"
  ["slack_token"]="xox[baprs]-[0-9A-Za-z-]{10,}"
  ["google_api_key"]="AIza[0-9A-Za-z_-]{20,}"
  ["stripe_live_key"]="sk_live_[0-9A-Za-z]{16,}|rk_live_[0-9A-Za-z]{16,}"
  ["mongo_uri_with_password"]="mongodb\\+srv://[^[:space:]]+:[^[:space:]@]+@"
)

allowlist_line() {
  local line="$1"
  if [[ "$line" =~ \<password\> || "$line" =~ \*\*\* || "$line" =~ user:pass || "$line" =~ example || "$line" =~ \$\{[A-Z0-9_]+\} ]]; then
    return 0
  fi
  return 1
}

for name in "${!PATTERNS[@]}"; do
  pattern="${PATTERNS[$name]}"
  out="$tmpdir/${name}.txt"

  set +e
  rg -n \
    --glob '!.git/**' \
    --glob '!tutor_env/**' \
    --glob '!var/**' \
    -- "$pattern" deploy/k8s >"$out"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
    echo "Scanner failed for pattern [$name]" >&2
    exit "$rc"
  fi
  if [[ ! -s "$out" ]]; then
    continue
  fi
  while IFS= read -r line; do
    if allowlist_line "$line"; then
      continue
    fi
    if [[ "$hits" -eq 0 ]]; then
      echo "Potential hardcoded secret findings under deploy/k8s/:"
    fi
    echo "[$name] $line"
    hits=$((hits + 1))
  done <"$out"
done

if [[ "$hits" -gt 0 ]]; then
  echo ""
  echo "Result: FAIL ($hits findings)"
  exit 1
fi

echo "OK"

