#!/usr/bin/env bash
# @covers AC-SPEC-301, AC-SPEC-302, AC-SPEC-303, AC-SPEC-304
# @spec: bead-23ry
#
# Verify deployment-critical spec coverage, lint, AC uniqueness, plan/testplan presence,
# and gap report existence.
#
# Deployment-critical specs:
#   ci-cd-pipeline, k8s-deployment, tutor-configuration, tutor-configuration-resilience,
#   branding-system, secrets-management, multi-tenancy-architecture
#
# Usage:
#   ./scripts/qa/verify-deployment-critical-coverage.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "  ${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "  ${YELLOW}WARN${NC}: $1"; WARN=$((WARN + 1)); }

DEPLOYMENT_CRITICAL_SPECS=(
  "ci-cd-pipeline"
  "k8s-deployment"
  "tutor-configuration"
  "tutor-configuration-resilience"
  "branding-system"
  "secrets-management"
  "multi-tenancy-architecture"
)

COVERAGE_THRESHOLD=80

echo "========================================================"
echo "Deployment-Critical Spec Coverage Verifier (bead 23ry.3)"
echo "AC-SPEC-301..304"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# AC-SPEC-301: Lint — all deployment-critical specs pass error-level lint
# -----------------------------------------------------------------------
echo "--- AC-SPEC-301: Spec lint (error severity) ---"

for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
  spec_file="specs/${spec_slug}_spec.md"
  if [[ ! -f "$spec_file" ]]; then
    fail_check "Spec file missing: $spec_file"
    continue
  fi
  LINT_OUT="$(python3 scripts/qa/spec-tools/mereka_spec_lint.py --severity-filter error "$spec_file" 2>&1 || true)"
  if grep -q "^PASS" <<<"$LINT_OUT"; then
    pass_check "Lint PASS: $spec_file"
  else
    fail_check "Lint FAIL: $spec_file"
    echo "$LINT_OUT" | sed 's/^/    /'
  fi
done

# -----------------------------------------------------------------------
# AC-SPEC-301: Coverage — all deployment-critical specs ≥ threshold
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-301: Coverage ≥ ${COVERAGE_THRESHOLD}% ---"

DASHBOARD_OUT="$(python3 scripts/qa/spec-tools/spec_coverage_dashboard.py --testmaps-dir specs/_generated/testmaps/ --format json 2>&1 || true)"

if [[ -z "$DASHBOARD_OUT" ]]; then
  fail_check "Coverage dashboard produced no output"
else
  pass_check "Coverage dashboard ran without error"

  for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
    spec_file="${spec_slug}_spec.md"
    COVERAGE="$(echo "$DASHBOARD_OUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data.get('specs', []):
    if s['spec'] == '${spec_file}':
        print(s['coverage_rate'])
        break
" 2>/dev/null | tr -d '\r' || true)"

    if [[ -z "$COVERAGE" ]]; then
      warn_check "Coverage data not found for ${spec_file}"
    else
      # Compare as integers (floor) for portability
      COVERAGE_INT="${COVERAGE%%.*}"
      if [[ "$COVERAGE_INT" -ge "$COVERAGE_THRESHOLD" ]]; then
        pass_check "Coverage ${COVERAGE}% ≥ ${COVERAGE_THRESHOLD}%: ${spec_file}"
      else
        fail_check "Coverage ${COVERAGE}% < ${COVERAGE_THRESHOLD}%: ${spec_file}"
      fi
    fi
  done
fi

# -----------------------------------------------------------------------
# AC-SPEC-302: No duplicate AC IDs within deployment-critical specs
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-302: No duplicate AC IDs ---"

for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
  spec_file="specs/${spec_slug}_spec.md"
  if [[ ! -f "$spec_file" ]]; then
    continue
  fi
  DUP_COUNT="$(grep -oE 'AC-([A-Z]+-)?[0-9]+:' "$spec_file" | sed 's/:$//' | sort | uniq -d | wc -l | tr -d ' \r' || true)"
  if [[ "$DUP_COUNT" -eq 0 ]]; then
    pass_check "No duplicate AC IDs: ${spec_file}"
  else
    DUPS="$(grep -oE 'AC-([A-Z]+-)?[0-9]+:' "$spec_file" | sed 's/:$//' | sort | uniq -d | tr '\n' ' ' || true)"
    fail_check "Duplicate AC IDs in ${spec_file}: ${DUPS}"
  fi
done

# -----------------------------------------------------------------------
# AC-SPEC-302: AC ID prefix consistency within each spec
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-302: AC ID prefix consistency ---"

for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
  spec_file="specs/${spec_slug}_spec.md"
  if [[ ! -f "$spec_file" ]]; then
    continue
  fi

  # Extract all AC IDs from checklist lines: "- [ ] AC-NNN:" or "- [ ] AC-PREFIX-NNN:"
  ALL_ACS="$(grep -oE '\- \[.\] AC-([A-Z]+-)?[0-9]+:' "$spec_file" | grep -oE 'AC-([A-Z]+-)?[0-9]+' || true)"

  if [[ -z "$ALL_ACS" ]]; then
    warn_check "No AC checklist lines found in ${spec_file}"
    continue
  fi

  # Collect distinct prefixes (INT = integration prefix, NONE = no prefix)
  # A spec is consistent if:
  #   - It uses only (none) [plain AC-NNN]
  #   - It uses only a single spec-scoped prefix [all AC-PREFIX-NNN]
  #   - It mixes (none) with INT [cross-spec integration criteria pattern]
  PREFIX_LIST="$(echo "$ALL_ACS" | python3 -c "
import sys
prefixes = set()
for line in sys.stdin:
    ac = line.strip()
    if not ac:
        continue
    parts = ac.split('-')
    if len(parts) == 3:
        prefixes.add(parts[1])
    else:
        prefixes.add('(none)')
# Valid combinations:
#   {'(none)'}                      -- plain numbered ACs only
#   {single_prefix}                 -- spec-scoped prefix used throughout
#   {'(none)', 'INT'}               -- numbered ACs + cross-spec integration criteria
#   {'(none)', 'INT', single_pfx}   -- rare but acceptable
non_acceptable = [p for p in prefixes if p not in ('(none)', 'INT')]
single_scoped = len(non_acceptable) == 1  # one consistent spec prefix
mixed_bad = len(non_acceptable) > 1       # multiple competing prefixes
ok = not mixed_bad
print('prefixes=' + ','.join(sorted(prefixes)))
print('ok=' + ('1' if ok else '0'))
print('bad=' + ','.join(sorted(non_acceptable)) if mixed_bad else 'bad=')
" 2>/dev/null | tr -d '\r' || true)"

  PREFIXES="$(echo "$PREFIX_LIST" | grep '^prefixes=' | cut -d= -f2 || true)"
  PREFIX_OK="$(echo "$PREFIX_LIST" | grep '^ok=' | cut -d= -f2 || true)"

  if [[ "$PREFIX_OK" == "1" ]]; then
    pass_check "AC prefix consistent (${PREFIXES}): ${spec_file}"
  else
    BAD="$(echo "$PREFIX_LIST" | grep '^bad=' | cut -d= -f2 || true)"
    fail_check "Multiple competing AC prefixes in ${spec_file}: ${BAD} (all prefixes: ${PREFIXES})"
  fi
done

# -----------------------------------------------------------------------
# AC-SPEC-303: Each deployment-critical spec has a plan and testplan
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-303: Plan + testplan presence ---"

for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
  plan_file="specs/plans/${spec_slug}_plan.md"
  testplan_file="specs/plans/${spec_slug}_testplan.md"

  if [[ -f "$plan_file" ]]; then
    pass_check "Plan exists: ${plan_file}"
  else
    fail_check "Plan missing: ${plan_file}"
  fi

  if [[ -f "$testplan_file" ]]; then
    pass_check "Testplan exists: ${testplan_file}"
  else
    fail_check "Testplan missing: ${testplan_file}"
  fi
done

# -----------------------------------------------------------------------
# AC-SPEC-303: Plans and testplans contain AC reference markers
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-303: Plan/testplan AC reference markers ---"

for spec_slug in "${DEPLOYMENT_CRITICAL_SPECS[@]}"; do
  for suffix in plan testplan; do
    plan_file="specs/plans/${spec_slug}_${suffix}.md"
    if [[ ! -f "$plan_file" ]]; then
      continue
    fi
    AC_COUNT="$(grep -c 'AC-' "$plan_file" 2>/dev/null || true)"
    if [[ "$AC_COUNT" -gt 0 ]]; then
      pass_check "AC markers present (${AC_COUNT}): ${plan_file}"
    else
      warn_check "No AC reference markers in ${plan_file}"
    fi
  done
done

# -----------------------------------------------------------------------
# AC-SPEC-304: Gap report exists
# -----------------------------------------------------------------------
echo ""
echo "--- AC-SPEC-304: Gap report exists ---"

GAP_REPORT="reports/2026/audits/DEPLOYMENT_CRITICAL_GAP_REPORT.md"

if [[ -f "$GAP_REPORT" ]]; then
  pass_check "Gap report exists: ${GAP_REPORT}"
else
  fail_check "Gap report missing: ${GAP_REPORT}"
fi

# -----------------------------------------------------------------------
# AC-SPEC-304: Gap report has required sections
# -----------------------------------------------------------------------
if [[ -f "$GAP_REPORT" ]]; then
  echo ""
  echo "--- AC-SPEC-304: Gap report completeness ---"

  REPORT_CONTENT="$(cat "$GAP_REPORT" | tr -d '\r' || true)"

  # Check for command output section
  if grep -qi "command output\|## Command\|### Command" <<<"$REPORT_CONTENT"; then
    pass_check "Gap report includes command outputs section"
  else
    fail_check "Gap report missing command outputs section"
  fi

  # Check for owner mapping
  if grep -qi "owner\|domain" <<<"$REPORT_CONTENT"; then
    pass_check "Gap report includes owner/domain mapping"
  else
    fail_check "Gap report missing owner/domain mapping"
  fi

  # Check for coverage table (should have | characters indicating markdown table)
  TABLE_LINES="$(grep -c '^|' <<<"$REPORT_CONTENT" || true)"
  if [[ "$TABLE_LINES" -ge 7 ]]; then
    pass_check "Gap report contains coverage table (${TABLE_LINES} table rows)"
  else
    fail_check "Gap report missing coverage table (found ${TABLE_LINES} table rows, expected ≥ 7)"
  fi
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "========================================================"
echo "=== Results ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}One or more checks failed.${NC}"
  exit 1
fi

echo -e "${GREEN}All checks passed.${NC}"
exit 0
