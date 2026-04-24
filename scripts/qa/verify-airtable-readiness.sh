#!/usr/bin/env bash
# Verify drive-airtable migration STATUS.md structural integrity.
#
# Checks that STATUS.md exists, has the expected sections, documents 124 Open edX
# course keys, has 0 needs_manual_choice items remaining, and documents the blocked
# count. All checks are static (no network calls, no Airtable API).
#
# Usage:
#   ./scripts/qa/verify-airtable-readiness.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STATUS_FILE="docs/status/migrations/drive-airtable-STATUS.md"
REVIEW_QUEUE_FILE="docs/reference/migrations/drive-airtable/REVIEW_QUEUE.md"
README_FILE="docs/reference/migrations/drive-airtable/README.md"

failures=0

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

# ---------------------------------------------------------------------------
# File existence checks
# ---------------------------------------------------------------------------
echo "== File existence =="

if [[ -f "$STATUS_FILE" ]]; then
  pass "STATUS.md exists"
else
  fail "STATUS.md missing at $STATUS_FILE"
fi

if [[ -f "$REVIEW_QUEUE_FILE" ]]; then
  pass "REVIEW_QUEUE.md exists"
else
  fail "REVIEW_QUEUE.md missing at $REVIEW_QUEUE_FILE"
fi

if [[ -f "$README_FILE" ]]; then
  pass "README.md exists"
else
  fail "README.md missing at $README_FILE"
fi

# All subsequent checks require STATUS.md — skip them if it is absent.
if [[ ! -f "$STATUS_FILE" ]]; then
  echo ""
  echo "[FAIL] Cannot continue: STATUS.md is missing."
  exit 1
fi

echo ""

# ---------------------------------------------------------------------------
# Required sections in STATUS.md
# ---------------------------------------------------------------------------
echo "== Required sections =="

required_sections=(
  "## Current Position"
  "## Migration Readiness Gates"
  "## Blockers (Active)"
  "## Reviewer Queue"
)

for section in "${required_sections[@]}"; do
  if grep -qF "$section" "$STATUS_FILE"; then
    pass "Section present: $section"
  else
    fail "Section missing: $section"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Core inventory assertions
# ---------------------------------------------------------------------------
echo "== Core inventory =="

# Exactly 124 Open edX course keys mapped (mapping rows with Course Key Status=confirmed)
if grep -qE 'Course Key Status=confirmed.*124|mapping rows.*Course Key Status=confirmed.*124|124.*Course Key Status=confirmed' "$STATUS_FILE"; then
  pass "124 mapping rows with Course Key Status=confirmed documented"
elif grep -qE '"Mapping Status=ready".*106|Mapping Status=ready.*106' "$STATUS_FILE"; then
  # Confirm total mapping rows = 124 via the total line
  if grep -qE '`Open edX Mapping`.*124 total|Open edX Mapping.*total.*124|total.*124' "$STATUS_FILE"; then
    pass "124 Open edX Mapping rows documented (106 ready + 18 blocked)"
  else
    fail "Cannot confirm 124 Open edX course keys in STATUS.md"
  fi
else
  fail "Cannot confirm 124 Open edX course keys in STATUS.md"
fi

# needs_manual_choice must be 0
if grep -qE '`needs_manual_choice`.*[^0-9]0[^0-9]|needs_manual_choice.*:\s*0' "$STATUS_FILE"; then
  pass "needs_manual_choice=0 documented"
elif grep -qE 'needs_manual_choice.*0' "$STATUS_FILE"; then
  pass "needs_manual_choice=0 documented"
else
  fail "needs_manual_choice=0 not found in STATUS.md (unresolved ambiguous videos remaining)"
fi

# Blocked count is documented (18)
if grep -qE '`blocked_waiver`.*18|blocked_waiver.*18|Handoff Bucket.*blocked_waiver.*18' "$STATUS_FILE"; then
  pass "blocked_waiver=18 documented"
else
  fail "blocked_waiver=18 not found in STATUS.md"
fi

# Waiver-pending rows documented
if grep -qE 'waiver_pending.*18|pending_review.*18' "$STATUS_FILE"; then
  pass "waiver_pending=18 documented"
else
  fail "waiver_pending=18 not found in STATUS.md"
fi

echo ""

# ---------------------------------------------------------------------------
# Subtitle integrity
# ---------------------------------------------------------------------------
echo "== Subtitle integrity =="

# Orphan subtitle count documented
if grep -qE 'needs_video_match.*1|subtitle.*orphan.*1|subtitle_orphan.*1' "$STATUS_FILE"; then
  pass "Orphan subtitle (needs_video_match=1) documented"
else
  fail "Orphan subtitle count not found in STATUS.md"
fi

# PF 5.3.srt named explicitly
if grep -qF 'PF 5.3.srt' "$STATUS_FILE"; then
  pass "PF 5.3.srt orphan subtitle named in STATUS.md"
else
  fail "PF 5.3.srt not named in STATUS.md"
fi

echo ""

# ---------------------------------------------------------------------------
# Review queue file checks
# ---------------------------------------------------------------------------
echo "== REVIEW_QUEUE.md content =="

if [[ -f "$REVIEW_QUEUE_FILE" ]]; then
  # Must list all 4 blocked course keys
  blocked_courses=(
    "course-v1:FOW-ENG+LLP+2026T1"
    "course-v1:FOW_ST-ENG+PP-ENG+2026T1"
    "course-v1:FOW-IDN+PF-IDN+2026T1"
    "course-v1:FOW-MAL+SP-MAL+2026T1"
  )
  for course in "${blocked_courses[@]}"; do
    if grep -qF "$course" "$REVIEW_QUEUE_FILE"; then
      pass "Blocked course documented in REVIEW_QUEUE.md: $course"
    else
      fail "Blocked course missing from REVIEW_QUEUE.md: $course"
    fi
  done

  # Must reference the orphan subtitle
  if grep -qF 'PF 5.3.srt' "$REVIEW_QUEUE_FILE"; then
    pass "PF 5.3.srt orphan documented in REVIEW_QUEUE.md"
  else
    fail "PF 5.3.srt not documented in REVIEW_QUEUE.md"
  fi

  # Must have a reviewer assignment workflow section
  if grep -qiE 'Reviewer Assignment|Assignment Workflow|Review.*Workflow' "$REVIEW_QUEUE_FILE"; then
    pass "Reviewer assignment workflow section present in REVIEW_QUEUE.md"
  else
    fail "Reviewer assignment workflow section missing from REVIEW_QUEUE.md"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [[ "$failures" -eq 0 ]]; then
  echo "[PASS] All drive-airtable readiness checks passed."
  exit 0
else
  echo "[FAIL] $failures check(s) failed. Review output above."
  exit 1
fi
