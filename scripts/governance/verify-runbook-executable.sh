#!/usr/bin/env bash
# verify-runbook-executable.sh
# -----------------------------------------------------------------------------
# Enforces Truth Repair Doctrine Rule 3: "A runbook is not executable until it
# has been run." For every runbook under docs/ops/runbooks/ with
# `status: executable` in its YAML frontmatter, assert that a matching
# evidence file exists under docs/ops/evidence/ within MAX_EVIDENCE_AGE days.
#
# An evidence file is considered matching if its filename starts with the
# runbook's basename (without extension) and contains a YYYY-MM-DD date.
# Examples:
#
#   runbook: docs/ops/runbooks/promotion-rollback-drill.md   (status: executable)
#   evidence: docs/ops/evidence/promotion-rollback-drill-2026-04-20.md  ✓ accepted
#
# Modes:
#   default (warn):  missing evidence emits a WARN line; script exits 0
#   --strict:        missing evidence emits a FAIL line; script exits 1
#
# Usage:
#   scripts/governance/verify-runbook-executable.sh [--strict] [--max-age-days N]
#
# Options:
#   --strict             Treat missing evidence as a hard failure (exit 1)
#   --max-age-days N     Maximum evidence age in days (default: 90)
#   --runbooks-dir PATH  Override runbooks directory (default: docs/ops/runbooks)
#   --evidence-dir PATH  Override evidence directory (default: docs/ops/evidence)
#   -h | --help          Show this help
#
# Exit codes:
#   0  OK (or warnings only)
#   1  FAIL (--strict mode and missing evidence)
#   2  Usage or environment error
#
# Related:
#   - Bead: mereka-lms-y69t.1
#   - Doctrine: docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md §Rule 3
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNBOOKS_DIR="${REPO_ROOT}/docs/ops/runbooks"
EVIDENCE_DIR="${REPO_ROOT}/docs/ops/evidence"
MAX_AGE_DAYS=90
STRICT=0

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)          STRICT=1; shift ;;
    --max-age-days)    MAX_AGE_DAYS="${2:-90}"; shift 2 ;;
    --runbooks-dir)    RUNBOOKS_DIR="${2:-}"; shift 2 ;;
    --evidence-dir)    EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help)         sed -n '1,45p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -d "$RUNBOOKS_DIR" ]] || die "runbooks directory does not exist: $RUNBOOKS_DIR"

mkdir -p "$EVIDENCE_DIR"  # evidence dir may legitimately not exist yet; create if absent

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

# today in seconds since epoch
NOW_EPOCH="$(date +%s)"
MAX_AGE_SECONDS=$(( MAX_AGE_DAYS * 86400 ))

check_runbook() {
  local runbook="$1"
  local basename status_line
  basename="$(basename "$runbook" .md)"

  # Extract frontmatter status field. Only read the first frontmatter block.
  status_line="$(awk '
    /^---$/ { if (in_fm) exit; in_fm=1; next }
    in_fm && /^status:/ { print; exit }
  ' "$runbook" | head -1)"

  if [[ -z "$status_line" ]]; then
    return 0  # no status field; nothing to check
  fi

  # Normalize: status: executable (or Status: executable, etc.)
  if ! echo "$status_line" | grep -iq 'executable'; then
    return 0  # status is something else (draft, active, canonical...); not in scope
  fi

  # Find evidence files matching <basename>-YYYY-MM-DD(...).md
  local pattern="${EVIDENCE_DIR}/${basename}-*.md"
  shopt -s nullglob
  # shellcheck disable=SC2206 # glob expansion is intentional here
  local matches=( $pattern )
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 0 ]]; then
    if [[ $STRICT -eq 1 ]]; then
      echo -e "  ${RED}[FAIL]${NC} $runbook (status: executable) — no evidence file found matching '$EVIDENCE_DIR/${basename}-*.md'"
      FAIL=$(( FAIL + 1 ))
    else
      echo -e "  ${YEL}[WARN]${NC} $runbook (status: executable) — no evidence file found matching '$EVIDENCE_DIR/${basename}-*.md' (would FAIL under --strict)"
      WARN=$(( WARN + 1 ))
    fi
    return
  fi

  # Find the most recent evidence file by embedded date (not mtime — filenames
  # carry the authoritative date and mtime can drift on rebase / clone).
  local latest_date="" latest_file=""
  for f in "${matches[@]}"; do
    # Extract YYYY-MM-DD from filename
    local d
    d="$(basename "$f" .md | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
    if [[ -n "$d" && "$d" > "$latest_date" ]]; then
      latest_date="$d"
      latest_file="$f"
    fi
  done

  if [[ -z "$latest_date" ]]; then
    # Found matching files but none had a YYYY-MM-DD in the name; treat as
    # structural violation (evidence files MUST carry a date).
    if [[ $STRICT -eq 1 ]]; then
      echo -e "  ${RED}[FAIL]${NC} $runbook (status: executable) — evidence files under '$EVIDENCE_DIR' matched but none had a YYYY-MM-DD date in filename"
      FAIL=$(( FAIL + 1 ))
    else
      echo -e "  ${YEL}[WARN]${NC} $runbook (status: executable) — evidence files matched but none carry a YYYY-MM-DD date"
      WARN=$(( WARN + 1 ))
    fi
    return
  fi

  # Age check: convert latest_date to epoch; require (NOW - latest) <= MAX_AGE_SECONDS
  local latest_epoch
  latest_epoch="$(date -d "$latest_date" +%s 2>/dev/null || echo 0)"
  if [[ "$latest_epoch" -eq 0 ]]; then
    echo -e "  ${YEL}[WARN]${NC} $runbook — could not parse evidence date '$latest_date' (file: $latest_file)"
    WARN=$(( WARN + 1 ))
    return
  fi
  local age_seconds=$(( NOW_EPOCH - latest_epoch ))
  if [[ $age_seconds -gt $MAX_AGE_SECONDS ]]; then
    local age_days=$(( age_seconds / 86400 ))
    if [[ $STRICT -eq 1 ]]; then
      echo -e "  ${RED}[FAIL]${NC} $runbook — evidence is ${age_days}d old (>${MAX_AGE_DAYS}d), latest: $latest_file"
      FAIL=$(( FAIL + 1 ))
    else
      echo -e "  ${YEL}[WARN]${NC} $runbook — evidence is ${age_days}d old (>${MAX_AGE_DAYS}d), latest: $latest_file"
      WARN=$(( WARN + 1 ))
    fi
    return
  fi

  local age_days=$(( age_seconds / 86400 ))
  echo -e "  ${GRN}[PASS]${NC} $runbook — evidence $latest_file is ${age_days}d old"
  PASS=$(( PASS + 1 ))
}

echo "=== Runbook Executable Evidence Verification ==="
echo "Runbooks dir: $RUNBOOKS_DIR"
echo "Evidence dir: $EVIDENCE_DIR"
echo "Max age:      ${MAX_AGE_DAYS} days"
echo "Mode:         $([[ $STRICT -eq 1 ]] && echo "STRICT (missing evidence = FAIL)" || echo "WARN (missing evidence = WARN, exits 0)")"
echo ""

shopt -s nullglob
runbooks=( "$RUNBOOKS_DIR"/*.md )
shopt -u nullglob

if [[ ${#runbooks[@]} -eq 0 ]]; then
  echo "No runbooks found; nothing to verify."
  exit 0
fi

for rb in "${runbooks[@]}"; do
  check_runbook "$rb"
done

echo ""
echo "=== Summary ==="
printf "  PASS: %d\n  WARN: %d\n  FAIL: %d\n" "$PASS" "$WARN" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC} — $FAIL runbook(s) marked executable without recent evidence"
  exit 1
fi
if [[ $WARN -gt 0 ]]; then
  echo -e "${YEL}RESULT: WARN${NC} — $WARN runbook(s) need evidence backfilled (run with --strict to enforce)"
  exit 0
fi
echo -e "${GRN}RESULT: PASS${NC} — all executable runbooks have recent evidence"
exit 0
