#!/usr/bin/env bash
# Verify ARC runner capability contract for mereka-lms CI jobs.
# Checks required binaries, known-acceptable absences (xz), Python lzma
# fallback, lsb_release availability, and PATH cache directory.
#
# Exit 0 if minimum requirements are met.
# Missing xz is acceptable when Python lzma module is available (fallback).
#
# Usage:
#   scripts/qa/verify-arc-runner-contract.sh

set -euo pipefail

PASS=0
FAIL=0
WARN=0
SKIP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC}  $1"
  WARN=$((WARN + 1))
}

skip() {
  echo -e "      ${CYAN}SKIP${NC}  $1"
  SKIP=$((SKIP + 1))
}

bin_version() {
  local cmd="$1"
  local version_flag="${2:---version}"
  "${cmd}" "${version_flag}" 2>&1 | head -1 | tr -d '\n' || echo "(version unknown)"
}

echo "=== ARC Runner Capability Matrix ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Required binaries
# ---------------------------------------------------------------------------
echo "--- Required binaries ---"

REQUIRED_BINS=(bash git curl python3 node pip npm)

printf "  %-12s %-8s %s\n" "BINARY" "STATUS" "VERSION"
printf "  %-12s %-8s %s\n" "------" "------" "-------"

for bin in "${REQUIRED_BINS[@]}"; do
  if command -v "${bin}" >/dev/null 2>&1; then
    version="$(bin_version "${bin}")"
    printf "  %-12s ${GREEN}%-8s${NC} %s\n" "${bin}" "FOUND" "${version}"
    PASS=$((PASS + 1))
  else
    printf "  %-12s ${RED}%-8s${NC} %s\n" "${bin}" "MISSING" "(not found)"
    FAIL=$((FAIL + 1))
  fi
done

# ---------------------------------------------------------------------------
# 2. Known-acceptable absences
# ---------------------------------------------------------------------------
echo ""
echo "--- Known-acceptable absences ---"

XZ_PRESENT=0
if command -v xz >/dev/null 2>&1; then
  XZ_VERSION="$(bin_version xz)"
  pass "xz present (bonus): ${XZ_VERSION}"
  XZ_PRESENT=1
else
  warn "xz not found — expected on lightweight ARC runners (lzma fallback applies)"
fi

# ---------------------------------------------------------------------------
# 3. Python lzma module (fallback for missing xz)
# ---------------------------------------------------------------------------
echo ""
echo "--- Python lzma fallback ---"

if python3 -c "import lzma" 2>/dev/null; then
  pass "python3 lzma module available (xz fallback confirmed)"
elif [[ "${XZ_PRESENT}" -eq 1 ]]; then
  warn "python3 lzma module not available — but xz binary is present, so fallback not required"
  WARN=$((WARN - 1))   # Undo warn() increment — not a real problem
  skip "lzma fallback not needed (xz binary present)"
else
  fail "python3 lzma module NOT available and xz binary NOT present — no decompression path"
fi

# ---------------------------------------------------------------------------
# 4. lsb_release availability
# ---------------------------------------------------------------------------
echo ""
echo "--- OS identification ---"

if command -v lsb_release >/dev/null 2>&1; then
  LSB_OUT="$(lsb_release -ds 2>/dev/null || echo "(lsb_release returned non-zero)")"
  pass "lsb_release available: ${LSB_OUT}"
else
  warn "lsb_release not found — stub or /etc/os-release should be available"
  if [[ -f /etc/os-release ]]; then
    OS_NAME="$(. /etc/os-release && echo "${PRETTY_NAME:-${NAME:-unknown}}")"
    pass "/etc/os-release fallback available: ${OS_NAME}"
  else
    fail "Neither lsb_release nor /etc/os-release found — OS identification unavailable"
  fi
fi

# ---------------------------------------------------------------------------
# 5. $GITHUB_WORKSPACE/.cache/bin is in PATH or can be created
# ---------------------------------------------------------------------------
echo ""
echo "--- PATH cache directory ---"

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  CACHE_BIN="${GITHUB_WORKSPACE}/.cache/bin"
  if echo "${PATH}" | tr ':' '\n' | grep -qxF "${CACHE_BIN}"; then
    pass "\$GITHUB_WORKSPACE/.cache/bin is already in PATH"
  else
    warn "\$GITHUB_WORKSPACE/.cache/bin is NOT in PATH — checking if it can be created"
    if mkdir -p "${CACHE_BIN}" 2>/dev/null; then
      pass "\$GITHUB_WORKSPACE/.cache/bin can be created (writable)"
      rmdir "${CACHE_BIN}" 2>/dev/null || true
    else
      fail "\$GITHUB_WORKSPACE/.cache/bin cannot be created (permission denied)"
    fi
  fi
else
  skip "\$GITHUB_WORKSPACE not set (not running inside a GitHub Actions runner) — skipping cache bin check"
fi

# ---------------------------------------------------------------------------
# 6. Print capability matrix summary
# ---------------------------------------------------------------------------
echo ""
echo "--- Capability matrix ---"
printf "  %-30s %s\n" "CAPABILITY" "STATUS"
printf "  %-30s %s\n" "-----------" "------"

capabilities=(
  "bash|$(command -v bash >/dev/null 2>&1 && echo OK || echo MISSING)"
  "git|$(command -v git >/dev/null 2>&1 && echo OK || echo MISSING)"
  "curl|$(command -v curl >/dev/null 2>&1 && echo OK || echo MISSING)"
  "python3|$(command -v python3 >/dev/null 2>&1 && echo OK || echo MISSING)"
  "node|$(command -v node >/dev/null 2>&1 && echo OK || echo MISSING)"
  "pip|$(command -v pip >/dev/null 2>&1 && echo OK || echo MISSING)"
  "npm|$(command -v npm >/dev/null 2>&1 && echo OK || echo MISSING)"
  "xz|$(command -v xz >/dev/null 2>&1 && echo OK || echo ABSENT-EXPECTED)"
  "python3.lzma|$(python3 -c 'import lzma' 2>/dev/null && echo OK || echo MISSING)"
  "lsb_release|$(command -v lsb_release >/dev/null 2>&1 && echo OK || echo ABSENT)"
)

for cap in "${capabilities[@]}"; do
  name="${cap%%|*}"
  status="${cap##*|}"
  printf "  %-30s " "${name}"
  case "${status}" in
    OK)              echo -e "${GREEN}${status}${NC}" ;;
    ABSENT-EXPECTED) echo -e "${YELLOW}${status}${NC}" ;;
    *)               echo -e "${RED}${status}${NC}" ;;
  esac
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "Passed:   ${GREEN}${PASS}${NC}"
echo -e "Warnings: ${YELLOW}${WARN}${NC}"
echo -e "Skipped:  ${CYAN}${SKIP}${NC}"
echo -e "Failed:   ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}ARC runner meets minimum requirements for mereka-lms CI.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} requirement(s) not met — runner may not be able to execute CI jobs correctly.${NC}"
  exit 1
fi
