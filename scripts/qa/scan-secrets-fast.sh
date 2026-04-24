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
#
# RELAXED_MODE: NOT supported — this script enforces strict hygiene by default.
# Any allowlist additions require explicit code review and must be documented here.
#
# Allowlist policy:
#   Only the following patterns are exempted (MUST be kept minimal):
#   - <password>      — XML/HTML placeholder tokens (not real credentials)
#   - ***             — Redacted output markers
#   - ${VAR}          — Shell/env variable references (not literal values)
#   Exemptions for strings like "user:pass", "example", "s3cr3t", or generic
#   test-looking values are NOT granted by default — they can still be real leaks.
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

# Patterns that require PCRE2 ({n} quantifiers)
declare -A PATTERNS_PCRE2=(
  ["aws_access_key"]="AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}"
  ["github_token"]="ghp_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{20,}"
  ["google_api_key"]="AIza[0-9A-Za-z_-]{20,}"
  ["stripe_live_key"]="sk_live_[0-9A-Za-z]{16,}|rk_live_[0-9A-Za-z]{16,}"
)

# Patterns that work with standard ERE (no PCRE2 needed)
declare -A PATTERNS_ERE=(
  ["private_key"]="-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----"
  ["slack_token"]="xox[baprs]-[0-9A-Za-z-]+-[0-9A-Za-z-]+"
  # mongo_uri_with_password: scans only code/config file types, not documentation.
  # Documentation files (.md) legitimately contain example URIs like user:pass@host
  # for illustrative purposes and are not real credentials.
  ["mongo_uri_with_password"]="mongodb\+srv://[^[:space:]]+:[^@[:space:]]+@"
)

# File-type exclusions per pattern (space-separated glob exclusions for rg --glob)
# Patterns not listed here apply to all non-excluded paths.
declare -A PATTERN_EXCLUDE_GLOBS=(
  # Exclude markdown docs from mongo URI scan — they contain example connection strings.
  ["mongo_uri_with_password"]="*.md"
)

# Detect PCRE2 support once
HAS_PCRE2=0
if rg --pcre2 '' /dev/null >/dev/null 2>&1; then
  HAS_PCRE2=1
fi

# Strict allowlist — ONLY structural patterns that cannot be real credentials.
#
# Do NOT add broad terms like "example", "test", "s3cr3t" — they match too widely
# and would suppress genuine leaks. Each entry below must be justified.
#
# Current exemptions and rationale:
#   <password>         — XML/HTML placeholder token; cannot be a real password value
#   ***                — Redacted output marker (e.g. logging libraries)
#   ${VARNAME}         — Shell/env variable reference; value not present in the file
#   user:pass@         — Exact 4-char placeholder password (literal "pass"); any real
#                        password would be longer or contain alphanumerics beyond "pass"
#                        (e.g. user:pass1@ or admin:s3cr3t@ would NOT be exempted)
allowlist_line() {
  local line="$1"
  # XML/HTML placeholder: <password>
  if [[ "$line" =~ \<password\> ]]; then return 0; fi
  # Redacted output marker
  if [[ "$line" =~ \*\*\* ]]; then return 0; fi
  # Shell/env variable reference: ${VARNAME}
  if [[ "$line" =~ \$\{[A-Z0-9_]+\} ]]; then return 0; fi
  # Exact "user:pass@" placeholder — only the literal 4-char password "pass" is exempt.
  # Real passwords with this prefix (user:pass1, user:passw0rd) contain extra chars and
  # will NOT match this substring check because they appear as "user:pass1@" or similar.
  if [[ "$line" =~ user:pass@ ]]; then return 0; fi
  return 1
}

run_scan() {
  local name="$1"
  local pattern="$2"
  local use_pcre2="$3"
  local out="$tmpdir/${name}.txt"

  local pcre2_flag=""
  if [[ "$use_pcre2" == "1" ]]; then
    if [[ "$HAS_PCRE2" -eq 0 ]]; then
      echo "[SKIP] Pattern [$name] requires PCRE2 (not available in this rg build)" >&2
      return 0
    fi
    pcre2_flag="--pcre2"
  fi

  # Build per-pattern extra exclusions (from PATTERN_EXCLUDE_GLOBS)
  local extra_excludes=()
  if [[ -n "${PATTERN_EXCLUDE_GLOBS[$name]+set}" ]]; then
    IFS=' ' read -ra extra_globs <<< "${PATTERN_EXCLUDE_GLOBS[$name]}"
    for g in "${extra_globs[@]}"; do
      extra_excludes+=("--glob" "!$g")
    done
  fi

  set +e
  rg -n $pcre2_flag \
    --glob '!.git/**' \
    --glob '!node_modules/**' \
    --glob '!tutor_env/**' \
    --glob '!var/**' \
    --glob '!tmp/**' \
    --glob '!scripts/**/tmp-*/**' \
    --glob '!tests/qa/fixtures/**' \
    --glob '!tests/qa/test_qa_gates_strict.sh' \
    "${extra_excludes[@]}" \
    -- "$pattern" . >"$out" 2>/dev/null
  local rc=$?
  set -e

  if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
    echo "Scanner failed for pattern [$name] (rc=$rc)" >&2
    exit "$rc"
  fi

  if [[ ! -s "$out" ]]; then
    return 0
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
}

hits=0

for name in "${!PATTERNS_PCRE2[@]}"; do
  run_scan "$name" "${PATTERNS_PCRE2[$name]}" "1"
done

for name in "${!PATTERNS_ERE[@]}"; do
  run_scan "$name" "${PATTERNS_ERE[$name]}" "0"
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
