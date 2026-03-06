#!/usr/bin/env bash
# verify-tutor-version-pin.sh
# Scans the repo for Tutor version pins and verifies all references are consistent.
# Usage: ./scripts/qa/verify-tutor-version-pin.sh
# Exit code: 0 = all consistent, 1 = mismatch or unexpected version found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Canonical versions — update these when intentionally upgrading
# Updated to Tutor 21.0.0 (Ulmo) from 18.2.2 (Redwood) — 2026-03-06
EXPECTED_TUTOR_VERSION="21.0.0"
EXPECTED_MFE_VERSION="21.0.0"

PASS=0
FAIL=1
exit_code=0

# ANSI colours (safe — only used when stdout is a terminal)
if [ -t 1 ]; then
  GREEN="\033[0;32m"
  RED="\033[0;31m"
  YELLOW="\033[0;33m"
  RESET="\033[0m"
  BOLD="\033[1m"
else
  GREEN="" RED="" YELLOW="" RESET="" BOLD=""
fi

ok()   { printf "  ${GREEN}PASS${RESET}  %s\n" "$*"; }
fail() { printf "  ${RED}FAIL${RESET}  %s\n" "$*"; exit_code=1; }
warn() { printf "  ${YELLOW}WARN${RESET}  %s\n" "$*"; }
info() { printf "        %s\n" "$*"; }

echo ""
printf "${BOLD}Tutor Version Pin Verification${RESET}\n"
printf "Expected  tutor[full]: %s\n" "$EXPECTED_TUTOR_VERSION"
printf "Expected  tutor-mfe  : %s\n" "$EXPECTED_MFE_VERSION"
echo ""

# ---------------------------------------------------------------------------
# Collect all tutor[full]==x.y.z references
# ---------------------------------------------------------------------------
echo "Scanning .github/, docs/, infrastructure/, scripts/ ..."
echo "(Excluding: docs/archive — deprecated historical snapshots)"
echo ""

declare -A tutor_refs   # file -> version
declare -A mfe_refs     # file -> version

while IFS=: read -r file _rest; do
  version="$(echo "$_rest" | grep -oE 'tutor\[full\]==[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d= -f3)"
  [ -n "$version" ] && tutor_refs["$file"]="$version"
done < <(grep -rn --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.md' \
  --exclude-dir='archive' \
  --exclude-dir='deep-research' \
  'tutor\[full\]==[0-9]' \
  "$REPO_ROOT/.github" \
  "$REPO_ROOT/docs" \
  "$REPO_ROOT/infrastructure" \
  "$REPO_ROOT/scripts" 2>/dev/null \
  | grep -v 'Previous incident' \
  || true)

while IFS=: read -r file _rest; do
  version="$(echo "$_rest" | grep -oE 'tutor-mfe==[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d= -f3)"
  [ -n "$version" ] && mfe_refs["$file"]="$version"
done < <(grep -rn --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.md' \
  --exclude-dir='archive' \
  --exclude-dir='deep-research' \
  'tutor-mfe==[0-9]' \
  "$REPO_ROOT/.github" \
  "$REPO_ROOT/docs" \
  "$REPO_ROOT/infrastructure" \
  "$REPO_ROOT/scripts" 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Print summary table — tutor[full]
# ---------------------------------------------------------------------------
printf "${BOLD}%-70s  %-10s  %s${RESET}\n" "File" "Version" "Status"
printf '%s\n' "$(printf '%.0s-' {1..95})"

if [ "${#tutor_refs[@]}" -eq 0 ]; then
  warn "No tutor[full]==x.y.z references found in scanned directories."
else
  for file in $(printf '%s\n' "${!tutor_refs[@]}" | sort); do
    ver="${tutor_refs[$file]}"
    rel_file="${file#"$REPO_ROOT/"}"
    if [ "$ver" = "$EXPECTED_TUTOR_VERSION" ]; then
      printf "  ${GREEN}%-70s  %-10s  PASS${RESET}\n" "$rel_file" "$ver"
    else
      printf "  ${RED}%-70s  %-10s  FAIL (expected %s)${RESET}\n" \
        "$rel_file" "$ver" "$EXPECTED_TUTOR_VERSION"
      exit_code=1
    fi
  done
fi

echo ""
printf "${BOLD}tutor-mfe references${RESET}\n"
printf "${BOLD}%-70s  %-10s  %s${RESET}\n" "File" "Version" "Status"
printf '%s\n' "$(printf '%.0s-' {1..95})"

if [ "${#mfe_refs[@]}" -eq 0 ]; then
  warn "No tutor-mfe==x.y.z references found in scanned directories."
else
  for file in $(printf '%s\n' "${!mfe_refs[@]}" | sort); do
    ver="${mfe_refs[$file]}"
    rel_file="${file#"$REPO_ROOT/"}"
    if [ "$ver" = "$EXPECTED_MFE_VERSION" ]; then
      printf "  ${GREEN}%-70s  %-10s  PASS${RESET}\n" "$rel_file" "$ver"
    else
      printf "  ${RED}%-70s  %-10s  FAIL (expected %s)${RESET}\n" \
        "$rel_file" "$ver" "$EXPECTED_MFE_VERSION"
      exit_code=1
    fi
  done
fi

echo ""

# ---------------------------------------------------------------------------
# Count summary
# ---------------------------------------------------------------------------
tutor_total="${#tutor_refs[@]}"
mfe_total="${#mfe_refs[@]}"

tutor_ok=0
for ver in "${tutor_refs[@]}"; do
  [ "$ver" = "$EXPECTED_TUTOR_VERSION" ] && (( tutor_ok++ )) || true
done

mfe_ok=0
for ver in "${mfe_refs[@]}"; do
  [ "$ver" = "$EXPECTED_MFE_VERSION" ] && (( mfe_ok++ )) || true
done

printf "${BOLD}Summary${RESET}\n"
printf "  tutor[full]: %d/%d references match %s\n" "$tutor_ok" "$tutor_total" "$EXPECTED_TUTOR_VERSION"
printf "  tutor-mfe  : %d/%d references match %s\n" "$mfe_ok"   "$mfe_total"   "$EXPECTED_MFE_VERSION"
echo ""

if [ "$exit_code" -eq 0 ]; then
  printf "${GREEN}${BOLD}All version pins are consistent.${RESET}\n\n"
else
  printf "${RED}${BOLD}Version pin mismatch detected. Update mismatched files to use:${RESET}\n"
  printf "  pip install \"tutor[full]==%s\" tutor-mfe==%s\n\n" \
    "$EXPECTED_TUTOR_VERSION" "$EXPECTED_MFE_VERSION"
fi

exit "$exit_code"
