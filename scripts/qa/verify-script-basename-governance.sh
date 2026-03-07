#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Enforce explicit governance for duplicate executable script basenames.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALLOWLIST="$SCRIPT_DIR/duplicate-script-basenames.allowlist"

if [[ ! -f "$ALLOWLIST" ]]; then
  echo "FAIL missing allowlist file: $ALLOWLIST"
  exit 1
fi

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "WARN $1"; WARN=$((WARN + 1)); }

declare -A allow=()
while IFS= read -r raw; do
  line="${raw%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  allow["$line"]=1
done < "$ALLOWLIST"

declare -A count=()
declare -A paths=()

while IFS= read -r abs_path; do
  rel_path="${abs_path#"$REPO_ROOT"/}"
  base="$(basename "$rel_path")"
  count["$base"]=$(( ${count["$base"]:-0} + 1 ))
  paths["$base"]+="${paths["$base"]:+$'\n'}${rel_path}"
done < <(find "$REPO_ROOT/scripts" -type f -perm /111 | sort)

for base in "${!count[@]}"; do
  if (( count["$base"] > 1 )); then
    if [[ -n "${allow[$base]+x}" ]]; then
      pass
    else
      fail "duplicate executable basename not allowlisted: $base"$'\n'"${paths["$base"]}"
    fi
  fi
done

for base in "${!allow[@]}"; do
  if (( ${count["$base"]:-0} <= 1 )); then
    warn "allowlist entry is stale (no duplicate found): $base"
  fi
done

echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
if (( FAIL > 0 )); then
  exit 1
fi

exit 0
