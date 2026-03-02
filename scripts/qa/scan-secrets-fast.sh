#!/usr/bin/env bash
# @covers AC-012
# @spec: secrets-management_spec.md
# Fast local secret hygiene scan (deterministic, repo-safe output).
#
# Purpose:
# - Catch obvious committed secrets quickly during local checks.
# - Keep output safe by printing file:line context only (no shell expansion).
#
# Notes:
# - CI also runs trufflehog (see .github/workflows/ci.yml).
# - This script is a lightweight complement for rapid operator checks.
#
# Usage:
#   ./scripts/qa/scan-secrets-fast.sh
#   STRICT=1 ./scripts/qa/scan-secrets-fast.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

STRICT="${STRICT:-0}"
tmpdir="$(mktemp -d -t scan-secrets-fast.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

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

hits=0
for name in "${!PATTERNS[@]}"; do
  pattern="${PATTERNS[$name]}"
  out="$tmpdir/${name}.txt"

  set +e
  rg -n --pcre2 \
    --glob '!.git/**' \
    --glob '!node_modules/**' \
    --glob '!tutor_env/**' \
    --glob '!var/**' \
    --glob '!tmp/**' \
    -- "$pattern" . >"$out"
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
      echo "Potential secret findings:"
    fi
    echo "[$name] $line"
    hits=$((hits + 1))
  done <"$out"
done

if [[ "$hits" -gt 0 ]]; then
  echo ""
  echo "Result: FAIL ($hits findings)"
  echo "Action: rotate in Infisical, sync to GCP/K8s, then invalidate old credentials."
  exit 1
fi

if [[ "$STRICT" == "1" ]]; then
  echo "Result: PASS (strict mode, no findings)"
else
  echo "Result: PASS (no findings)"
fi
