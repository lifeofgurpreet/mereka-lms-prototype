#!/usr/bin/env bash
# verify-spec-coverage.sh — Spec coverage floor enforcement (T066)
#
# Scans specs/*.md for acceptance criteria and checks whether testmaps/tests
# reference each AC.  Exits 1 if coverage is below SPEC_COVERAGE_FLOOR.
#
# Usage:
#   ./scripts/qa/verify-spec-coverage.sh
#   SPEC_COVERAGE_FLOOR=60 ./scripts/qa/verify-spec-coverage.sh
#
# Environment variables:
#   SPEC_COVERAGE_FLOOR   Integer percentage floor (default: 40)
#   REPO_ROOT             Override repo root detection (optional)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
FLOOR="${SPEC_COVERAGE_FLOOR:-40}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

SPECS_DIR="${REPO_ROOT}/specs"
TESTS_DIR="${REPO_ROOT}/tests"
TESTMAPS_DIR="${REPO_ROOT}/specs/_generated/testmaps"

# ---------------------------------------------------------------------------
# Colour helpers (degrade gracefully when not a tty)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
count_acs_in_spec() {
  local file="$1"
  # Count lines that look like acceptance criteria:
  #   - Lines starting with "- [ ]" or "- [x]" (checkbox style)
  #   - Lines containing MUST or SHALL as a standalone word
  #   - Lines starting with "AC-" (explicit AC label)
  local checkbox must_shall ac_prefix total
  checkbox=$(grep -cP '^\s*-\s+\[[ xX]\]' "$file" 2>/dev/null || true)
  must_shall=$(grep -cP '\b(MUST|SHALL)\b' "$file" 2>/dev/null || true)
  ac_prefix=$(grep -cP '^\s*AC-' "$file" 2>/dev/null || true)
  # Sum but de-duplicate lines that might match multiple patterns by taking max
  # Strategy: if a file has checkbox ACs use those; else fall back to MUST/SHALL
  if [ "${checkbox}" -gt 0 ]; then
    total="${checkbox}"
  elif [ "${ac_prefix}" -gt 0 ]; then
    total="${ac_prefix}"
  else
    total="${must_shall}"
  fi
  echo "${total}"
}

# Check whether a given spec file's ACs appear in testmaps or tests/
# Returns the count of ACs that have at least one reference.
count_covered_acs_in_spec() {
  local spec_file="$1"
  local spec_basename
  spec_basename="$(basename "${spec_file}" .md)"

  # 1) If a testmap exists for this spec, count ACs listed in it that have
  #    at least one 'verify' entry of type 'automated' OR have any file: ref.
  local testmap="${TESTMAPS_DIR}/${spec_basename}.testmap.yml"
  if [ -f "${testmap}" ]; then
    # Count AC blocks that contain a "file:" line (meaning a test file is wired)
    # or an automated verify entry.
    # Approach: count "- id: AC" blocks that are followed (within 20 lines) by "file:"
    python3 - "${testmap}" <<'PYEOF'
import sys, re

path = sys.argv[1]
text = open(path).read()

# Split by AC entry
blocks = re.split(r'\n(?=\s*-\s+id:\s+AC)', text)
covered = 0
for block in blocks:
    if not re.search(r'-\s+id:\s+AC', block):
        continue
    # covered = has automated type OR has a file: reference
    if re.search(r'type:\s+automated', block) or re.search(r'\bfile:\s+\S', block):
        covered += 1
print(covered)
PYEOF
    return
  fi

  # 2) No testmap: fall back to grep for the spec basename in tests/ and
  #    scripts/qa/verify-*.sh files.
  local refs
  refs=$(grep -rl "${spec_basename}" "${TESTS_DIR}" "${SPECS_DIR}/plans/manual_verifications.yaml" \
    2>/dev/null | wc -l || true)
  if [ "${refs}" -gt 0 ]; then
    # At least referenced — count total ACs as covered (coarse approximation)
    count_acs_in_spec "${spec_file}"
  else
    echo 0
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo ""
  echo -e "${BOLD}=== Spec Coverage Report ===${RESET}"
  echo -e "Repo:  ${REPO_ROOT}"
  echo -e "Floor: ${YELLOW}${FLOOR}%${RESET}  (override with SPEC_COVERAGE_FLOOR=N)"
  echo ""

  # Table header
  printf "%-52s %8s %8s %8s\n" "Spec File" "Total ACs" "Covered" "Coverage"
  printf '%s\n' "$(printf '%-52s %8s %8s %8s' '' '' '' '' | tr ' ' '-')"

  local grand_total=0
  local grand_covered=0
  local any_below_floor=0

  # Collect and sort spec files
  local spec_files
  mapfile -t spec_files < <(find "${SPECS_DIR}" -maxdepth 1 -name '*_spec.md' -o -name '*.md' \
    | grep -v '_TEMPLATE\|INDEX\|IMPLEMENTATION_ORDER' | sort)

  # Also include legacy-named specs (secrets-management.md etc.)
  while IFS= read -r f; do
    spec_files+=("$f")
  done < <(find "${SPECS_DIR}" -maxdepth 1 -name '*.md' \
    | grep -v '_spec\.md\|_TEMPLATE\|INDEX\|IMPLEMENTATION_ORDER' | sort)

  # De-duplicate
  local -A seen=()
  local deduped=()
  for f in "${spec_files[@]}"; do
    if [[ -z "${seen[$f]+_}" ]]; then
      seen[$f]=1
      deduped+=("$f")
    fi
  done

  for spec_file in "${deduped[@]}"; do
    [ -f "${spec_file}" ] || continue

    local total covered pct colour label
    total=$(count_acs_in_spec "${spec_file}")
    [ "${total}" -eq 0 ] && continue   # skip files with no ACs

    covered=$(count_covered_acs_in_spec "${spec_file}")
    # Guard: covered cannot exceed total
    [ "${covered}" -gt "${total}" ] && covered="${total}"

    grand_total=$(( grand_total + total ))
    grand_covered=$(( grand_covered + covered ))

    if [ "${total}" -gt 0 ]; then
      pct=$(( covered * 100 / total ))
    else
      pct=0
    fi

    if [ "${pct}" -lt "${FLOOR}" ]; then
      colour="${RED}"; label=" <FLOOR"; any_below_floor=1
    elif [ "${pct}" -lt 80 ]; then
      colour="${YELLOW}"; label=""
    else
      colour="${GREEN}"; label=""
    fi

    local short_name
    short_name="$(basename "${spec_file}")"
    printf "%-52s %8d %8d ${colour}%7d%%%s${RESET}\n" \
      "${short_name}" "${total}" "${covered}" "${pct}" "${label}"
  done

  echo ""
  printf '%s\n' "$(printf '%-52s %8s %8s %8s' '' '' '' '' | tr ' ' '-')"

  local overall_pct=0
  if [ "${grand_total}" -gt 0 ]; then
    overall_pct=$(( grand_covered * 100 / grand_total ))
  fi

  local overall_colour
  if [ "${overall_pct}" -ge "${FLOOR}" ]; then
    overall_colour="${GREEN}"
  else
    overall_colour="${RED}"
  fi

  printf "%-52s %8d %8d ${overall_colour}${BOLD}%7d%%${RESET}\n" \
    "TOTAL" "${grand_total}" "${grand_covered}" "${overall_pct}"
  echo ""

  if [ "${overall_pct}" -ge "${FLOOR}" ]; then
    echo -e "${GREEN}${BOLD}PASS${RESET}  Overall coverage ${overall_pct}% >= floor ${FLOOR}%"
    echo ""
    exit 0
  else
    echo -e "${RED}${BOLD}FAIL${RESET}  Overall coverage ${overall_pct}% is below floor ${FLOOR}%"
    echo ""
    echo "To raise coverage:"
    echo "  1. Add generated testmap entries in specs/_generated/testmaps/<spec>.testmap.yml"
    echo "  2. Wire test files under tests/ that reference the spec"
    echo "  3. Once coverage improves, ratchet the floor:"
    echo "     SPEC_COVERAGE_FLOOR=50 → SPEC_COVERAGE_FLOOR=60 etc."
    echo ""
    exit 1
  fi
}

main "$@"
