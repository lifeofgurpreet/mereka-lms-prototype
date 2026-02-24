#!/usr/bin/env bash
# Verify commit signing status for recent commits on the current branch.
#
# Checks:
#   1. Count signed vs unsigned commits in the last N commits (default: 20)
#   2. Report percentage of signed commits
#   3. Warn if percentage < configurable threshold (default: 50%)
#
# Signature status codes from git (%G?):
#   G = good signature
#   U = good signature, unknown key
#   X = good signature, expired key
#   Y = good signature, key expired at signing time
#   N = no signature
#   E = cannot check (missing/wrong key)
#   B = bad signature
#
# Usage:
#   ./scripts/qa/verify-commit-signing.sh [--count N] [--threshold N] [--strict]
#
# Options:
#   --count N       Number of recent commits to check (default: 20)
#   --threshold N   Minimum percentage of signed commits to pass (default: 50)
#   --strict        Exit 1 on threshold failure (default: exit 0, soft gate)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARNED=$((WARNED + 1)); }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
COUNT=20
THRESHOLD=50
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--count N] [--threshold N] [--strict]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Verify git is available
# ---------------------------------------------------------------------------
echo "== Commit Signing Verification =="
echo "   Checking last ${COUNT} commits  |  threshold: ${THRESHOLD}%  |  mode: $([ "$STRICT" -eq 1 ] && echo strict || echo soft)"
echo ""

if ! command -v git &>/dev/null; then
  fail "git is not available on PATH"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED} WARNED=${WARNED}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Fetch commit signature statuses
# ---------------------------------------------------------------------------
# Format: <short-hash> <G?-code> <signer-identity>
# We capture each field separately to avoid word-splitting issues.

SIGNED=0
UNSIGNED=0
ERROR_COUNT=0
TOTAL=0

echo "== Signature status per commit =="

while IFS=' ' read -r hash status signer; do
  TOTAL=$((TOTAL + 1))
  # Normalise: trim any trailing whitespace from status
  status="${status//[[:space:]]/}"

  case "$status" in
    G|U|X|Y)
      # Good / unknown key / expired / key expired at sign time — all "signed"
      label="signed"
      if [[ -n "$signer" ]]; then
        echo -e "  ${GREEN}${status}${NC}  ${hash}  (${signer})"
      else
        echo -e "  ${GREEN}${status}${NC}  ${hash}"
      fi
      SIGNED=$((SIGNED + 1))
      ;;
    N)
      label="unsigned"
      echo -e "  ${YELLOW}N${NC}  ${hash}  (no signature)"
      UNSIGNED=$((UNSIGNED + 1))
      ;;
    E|B)
      label="error"
      echo -e "  ${RED}${status}${NC}  ${hash}  (signature error)"
      ERROR_COUNT=$((ERROR_COUNT + 1))
      ;;
    *)
      # Empty or unexpected — treat as unsigned
      label="unsigned"
      echo -e "  ${YELLOW}?${NC}  ${hash}  (status: '${status}')"
      UNSIGNED=$((UNSIGNED + 1))
      ;;
  esac
done < <(git log --format="%h %G? %GS" -n "$COUNT" 2>/dev/null)

echo ""

# ---------------------------------------------------------------------------
# 3. Guard against empty history
# ---------------------------------------------------------------------------
if [[ "$TOTAL" -eq 0 ]]; then
  warn "No commits found — repository may be shallow or empty"
  echo ""
  echo "=============================="
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED} WARNED=${WARNED}"
  echo "=============================="
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. Calculate percentage and report
# ---------------------------------------------------------------------------
echo "== Results =="

# Integer arithmetic (bash), floor division
PCT=$(( (SIGNED * 100) / TOTAL ))

echo "  Total commits checked : ${TOTAL}"
echo "  Signed (G/U/X/Y)      : ${SIGNED}"
echo "  Unsigned (N)          : ${UNSIGNED}"
echo "  Error (E/B)           : ${ERROR_COUNT}"
echo "  Signed percentage     : ${PCT}%  (threshold: ${THRESHOLD}%)"
echo ""

THRESHOLD_MET=1
if [[ "$SIGNED" -eq "$TOTAL" ]]; then
  pass "All ${TOTAL} commits are signed (${PCT}%)"
elif [[ "$PCT" -ge "$THRESHOLD" ]]; then
  pass "Signed commit percentage ${PCT}% meets threshold ${THRESHOLD}%"
else
  THRESHOLD_MET=0
  warn "Signed commit percentage ${PCT}% is below threshold ${THRESHOLD}%"
fi

if [[ "$ERROR_COUNT" -gt 0 ]]; then
  warn "${ERROR_COUNT} commit(s) have bad or unverifiable signatures (E/B status)"
fi

if [[ "$UNSIGNED" -gt 0 ]]; then
  warn "${UNSIGNED} unsigned commit(s) found — see docs/operations/COMMIT_SIGNING.md to get started"
fi

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Summary: PASSED=${PASSED} FAILED=${FAILED} WARNED=${WARNED}"
echo "=============================="

if [[ "$STRICT" -eq 1 ]] && [[ "$FAILED" -gt 0 || "$THRESHOLD_MET" -eq 0 ]]; then
  exit 1
fi

# Soft gate: always exit 0 unless --strict and there are hard failures
exit 0
