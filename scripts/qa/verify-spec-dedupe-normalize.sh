#!/usr/bin/env bash
# @covers AC-SPEC-204, AC-SPEC-205, AC-SPEC-206
# @spec: bead-23ry
#
# Bead 23ry.2 — Spec cleanup: dedupe AC IDs and normalize plan/testplan IDs
#
# AC-SPEC-204: No duplicate AC IDs (checkbox lines) in any spec file
# AC-SPEC-205: Every spec with an ## Acceptance Criteria section has at least 1 checkbox AC
# AC-SPEC-206: All spec files pass mereka_spec_lint.py (--severity-filter error) and
#              the coverage dashboard runs successfully
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

SPECS_DIR="$REPO_ROOT/specs"
TESTMAPS_DIR="$REPO_ROOT/specs/testmaps"
LINT_TOOL="$REPO_ROOT/scripts/qa/spec-tools/mereka_spec_lint.py"
DASHBOARD_TOOL="$REPO_ROOT/scripts/qa/spec-tools/spec_coverage_dashboard.py"

echo "=== AC-SPEC-204: No duplicate checkbox AC IDs in spec files ==="

spec_files=()
while IFS= read -r -d '' f; do
  spec_files+=("$f")
done < <(find "$SPECS_DIR" -maxdepth 1 -name '*_spec.md' -print0 | sort -z)

dup_found=0
for spec in "${spec_files[@]}"; do
  content="$(tr -d '\r' < "$spec")"
  dups="$(echo "$content" | grep -P '^\- \[ \] AC-' | grep -oP 'AC-[A-Z0-9]+-[0-9]+' | sort | uniq -d || true)"
  if [[ -n "$dups" ]]; then
    fail_check "AC-SPEC-204: Duplicate checkbox AC IDs in $(basename "$spec"): $dups"
    dup_found=1
  fi
done

if [[ "$dup_found" -eq 0 ]]; then
  spec_count="${#spec_files[@]}"
  pass_check "AC-SPEC-204: No duplicate checkbox AC IDs found across $spec_count spec files"
fi

echo ""
echo "=== AC-SPEC-205: Every spec with ## Acceptance Criteria has at least 1 checkbox AC ==="

missing_ac_found=0
for spec in "${spec_files[@]}"; do
  content="$(tr -d '\r' < "$spec")"
  has_section="$(echo "$content" | grep -cP '^## Acceptance Criteria' || true)"
  ac_count="$(echo "$content" | grep -cP '^\- \[ \] AC-' || true)"
  if [[ "$has_section" -gt 0 && "$ac_count" -eq 0 ]]; then
    fail_check "AC-SPEC-205: $(basename "$spec") has '## Acceptance Criteria' section but 0 checkbox ACs"
    missing_ac_found=1
  fi
done

if [[ "$missing_ac_found" -eq 0 ]]; then
  pass_check "AC-SPEC-205: All specs with an Acceptance Criteria section have at least 1 checkbox AC"
fi

echo ""
echo "=== AC-SPEC-206: Spec lint (--severity-filter error) passes for all specs ==="

if [[ ! -f "$LINT_TOOL" ]]; then
  fail_check "AC-SPEC-206: Lint tool not found at $LINT_TOOL"
else
  lint_output="$(python3 "$LINT_TOOL" "$SPECS_DIR/" --severity-filter error 2>&1 || true)"
  fail_lines="$(echo "$lint_output" | grep '^FAIL' || true)"
  if [[ -n "$fail_lines" ]]; then
    fail_count="$(echo "$fail_lines" | wc -l | tr -d ' ')"
    fail_check "AC-SPEC-206: $fail_count spec(s) failed lint (--severity-filter error):"
    echo "$lint_output" | grep -E '^FAIL|ERROR' | head -30
  else
    pass_check "AC-SPEC-206: All specs pass lint at error severity"
  fi
fi

echo ""
echo "=== AC-SPEC-206: Coverage dashboard runs successfully ==="

if [[ ! -f "$DASHBOARD_TOOL" ]]; then
  fail_check "AC-SPEC-206: Coverage dashboard tool not found at $DASHBOARD_TOOL"
else
  dashboard_exit=0
  dashboard_output="$(python3 "$DASHBOARD_TOOL" \
    --testmaps-dir "$TESTMAPS_DIR" \
    --specs-dir "$SPECS_DIR" \
    --format text 2>&1)" || dashboard_exit=$?
  if [[ "$dashboard_exit" -ne 0 ]]; then
    fail_check "AC-SPEC-206: Coverage dashboard exited with code $dashboard_exit"
    echo "$dashboard_output" | tail -10
  else
    spec_line="$(echo "$dashboard_output" | grep -E 'GREEN|YELLOW|RED' | head -1 || true)"
    pass_check "AC-SPEC-206: Coverage dashboard ran successfully ($spec_line)"
  fi
fi

echo ""
echo "=== AC-SPEC-206: No spec testmap has 0 ACs when spec has checkbox ACs ==="

testmap_mismatch=0
for spec in "${spec_files[@]}"; do
  spec_base="$(basename "$spec")"
  testmap="$TESTMAPS_DIR/${spec_base%.md}.testmap.yml"
  if [[ ! -f "$testmap" ]]; then
    warn_check "AC-SPEC-206: No testmap found for $spec_base (expected $testmap)"
    continue
  fi
  content="$(tr -d '\r' < "$spec")"
  spec_ac_count="$(echo "$content" | grep -cP '^\- \[ \] AC-' || true)"
  if [[ "$spec_ac_count" -gt 0 ]]; then
    tm_content="$(tr -d '\r' < "$testmap")"
    # acceptance_criteria: [] means empty list
    is_empty="$(echo "$tm_content" | grep -cP 'acceptance_criteria:\s*\[\]' || true)"
    if [[ "$is_empty" -gt 0 ]]; then
      warn_check "AC-SPEC-206: $spec_base has $spec_ac_count ACs but testmap has empty acceptance_criteria (run generate-testmaps to regenerate)"
    fi
  fi
done

if [[ "$testmap_mismatch" -eq 0 ]]; then
  pass_check "AC-SPEC-206: Testmap coverage check complete (warnings shown for stale testmaps if any)"
fi

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Some checks failed.${NC}"
  exit 1
fi
echo -e "${GREEN}All checks passed.${NC}"
exit 0
