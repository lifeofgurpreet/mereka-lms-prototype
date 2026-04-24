#!/usr/bin/env bash
# @covers AC-Y69T.2
# @spec: truth-repair-doctrine_spec.md
# verify-retraction-sweep.sh
# -----------------------------------------------------------------------------
# Enforces Truth Repair Doctrine Rule 2: "Retractions patch source, not
# margins." Given a retracted term (a hypothesis, escalation condition,
# technical claim, or theory that has been disproven), this verifier
# ripgrep's the term across the canonical artifact set and fails if any
# occurrence survives that is NOT explicitly annotated as historical.
#
# Annotated-as-historical means the occurrence is preceded (within 10 lines)
# by one of these markers:
#
#   - a line containing "retracted" or "retraction" (case-insensitive)
#   - a line containing "historical:" or "(historical)"
#   - a line matching "^> \*\*Retracted" (markdown blockquote warning)
#
# If you retracted a claim, patch every canonical occurrence in the same
# tranche as the retraction. An annotation note next to the claim is fine
# IN ADDITION TO patching the claim, not as a substitute.
#
# Canonical artifact set (scanned by default):
#   - docs/**
#   - scripts/governance/**
#   - scripts/qa/**
# (tunable via --scope PATH, repeatable)
#
# Modes:
#   default (warn):  surviving occurrences emit WARN, script exits 0
#   --strict:        surviving occurrences emit FAIL, script exits 1
#
# Usage:
#   scripts/governance/verify-retraction-sweep.sh --term "managedFields=null" [--strict]
#   scripts/governance/verify-retraction-sweep.sh --terms-file retractions.txt
#
# Options:
#   --term TERM          Retracted term to sweep for (repeatable)
#   --terms-file PATH    File with one retracted term per line (# comments ok)
#   --scope PATH         Directory or glob to scan (repeatable, default: docs scripts/governance scripts/qa)
#   --strict             Missing retraction annotation → FAIL (exit 1)
#   --context-lines N    Lines of context to check for annotation (default: 10)
#   -h | --help          Show this help
#
# Exit codes:
#   0  OK (or warnings only)
#   1  FAIL (--strict mode and unannotated occurrences found)
#   2  Usage or environment error
#
# Related:
#   - Bead: mereka-lms-y69t.2
#   - Doctrine: docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md §Rule 2
#   - Prior instance this rule would have caught: ArgoAppSelfHealStuck.md
#     retained `managedFields=null` as L3 escalation condition AFTER the
#     hypothesis was retracted at §Symptom. Patched in bbi-infrastructure#3229.
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STRICT=0
CONTEXT_LINES=10
TERMS=()
SCOPES=()

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --term)         TERMS+=("${2:-}"); shift 2 ;;
    --terms-file)
      [[ -f "${2:-}" ]] || die "terms file not found: ${2:-}"
      while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        TERMS+=("$line")
      done < "$2"
      shift 2
      ;;
    --scope)        SCOPES+=("${2:-}"); shift 2 ;;
    --strict)       STRICT=1; shift ;;
    --context-lines) CONTEXT_LINES="${2:-10}"; shift 2 ;;
    -h|--help)      sed -n '1,55p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ ${#TERMS[@]} -gt 0 ]] || die "no retracted terms provided (use --term or --terms-file)"

command -v rg >/dev/null 2>&1 || die "ripgrep (rg) not found in PATH"

if [[ ${#SCOPES[@]} -eq 0 ]]; then
  SCOPES=(
    "${REPO_ROOT}/docs"
    "${REPO_ROOT}/scripts/governance"
    "${REPO_ROOT}/scripts/qa"
  )
fi

for s in "${SCOPES[@]}"; do
  [[ -d "$s" || -f "$s" ]] || die "scope not found: $s"
done

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

# Regex for "annotated-as-historical" markers. Case-insensitive.
ANNOTATION_PATTERN='retracted|retraction|\(historical\)|^historical:|^> \*\*Retracted'

sweep_term() {
  local term="$1"
  echo ""
  echo "--- Term: '$term' ---"

  # Get all matches with filename:line:content
  # Use fixed-string search (-F) so regex metacharacters in the term are literal.
  # -n (line numbers) -H (always show filename), one file per line.
  local matches
  matches="$(rg -F -n -H --no-heading "$term" "${SCOPES[@]}" 2>/dev/null || true)"

  if [[ -z "$matches" ]]; then
    echo -e "  ${GRN}[PASS]${NC} no occurrences found"
    PASS=$(( PASS + 1 ))
    return
  fi

  local total_occurrences annotated unannotated
  total_occurrences=0
  annotated=0
  unannotated=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    total_occurrences=$(( total_occurrences + 1 ))
    # Parse: path:lineno:content
    local path lineno
    path="$(echo "$line" | cut -d: -f1)"
    lineno="$(echo "$line" | cut -d: -f2)"

    # Extract context window around the match
    local start end context
    start=$(( lineno - CONTEXT_LINES )); [[ $start -lt 1 ]] && start=1
    end=$(( lineno + CONTEXT_LINES ))
    context="$(sed -n "${start},${end}p" "$path" 2>/dev/null || echo "")"

    if echo "$context" | rg -iq "$ANNOTATION_PATTERN"; then
      annotated=$(( annotated + 1 ))
    else
      unannotated=$(( unannotated + 1 ))
      if [[ $STRICT -eq 1 ]]; then
        echo -e "  ${RED}[FAIL]${NC} ${path}:${lineno} — unannotated occurrence"
      else
        echo -e "  ${YEL}[WARN]${NC} ${path}:${lineno} — unannotated occurrence (would FAIL under --strict)"
      fi
    fi
  done <<< "$matches"

  echo "  total=$total_occurrences annotated=$annotated unannotated=$unannotated"

  if [[ $unannotated -gt 0 ]]; then
    if [[ $STRICT -eq 1 ]]; then
      FAIL=$(( FAIL + 1 ))
    else
      WARN=$(( WARN + 1 ))
    fi
  else
    PASS=$(( PASS + 1 ))
  fi
}

echo "=== Retraction Sweep ==="
echo "Repo root:       $REPO_ROOT"
echo "Scopes:          ${SCOPES[*]}"
echo "Terms:           ${#TERMS[@]}"
echo "Context lines:   $CONTEXT_LINES"
echo "Mode:            $([[ $STRICT -eq 1 ]] && echo "STRICT (unannotated = FAIL)" || echo "WARN (unannotated = WARN, exits 0)")"
echo "Annotation rule: an occurrence is considered annotated if a line matching '${ANNOTATION_PATTERN}' appears within ${CONTEXT_LINES} lines of the match (case-insensitive)."

for t in "${TERMS[@]}"; do
  sweep_term "$t"
done

echo ""
echo "=== Summary ==="
printf "  terms PASS:  %d\n  terms WARN:  %d\n  terms FAIL:  %d\n" "$PASS" "$WARN" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC} — $FAIL term(s) have unannotated surviving occurrences"
  exit 1
fi
if [[ $WARN -gt 0 ]]; then
  echo -e "${YEL}RESULT: WARN${NC} — $WARN term(s) have unannotated surviving occurrences (run with --strict to enforce)"
  exit 0
fi
echo -e "${GRN}RESULT: PASS${NC} — all terms are clean or fully annotated"
exit 0
