#!/usr/bin/env bash
# verify-skill-evals-schema.sh — Validate evals/evals.yaml schema and completeness
#
# Ensures that:
# 1. evals/evals.yaml exists and is valid YAML
# 2. schema_version is present
# 3. Each skill has at least 3 trigger_evals and at least 1 quality_eval
# 4. Each trigger_eval has: id, prompt, should_trigger, reason
# 5. Each quality_eval has: id, prompt, expected_behavior, assertions
# 6. All 9 skills from config/skills-index.yaml are present
# 7. should_trigger is a boolean (true/false)
# 8. No duplicate eval IDs within a skill
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

EVALS_FILE="$REPO_ROOT/evals/evals.yaml"
SKILLS_INDEX="$REPO_ROOT/config/skills-index.yaml"

echo "=== Skill Evals Schema Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

# ---------------------------------------------------------------------------
# 1. evals/evals.yaml exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 1: evals/evals.yaml exists and is valid YAML ---"
if [[ ! -f "$EVALS_FILE" ]]; then
  fail "evals/evals.yaml does not exist"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "evals/evals.yaml exists"

if ! python3 -c "import yaml; yaml.safe_load(open('${EVALS_FILE}'))" 2>/dev/null; then
  fail "evals/evals.yaml is not valid YAML"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "evals/evals.yaml is valid YAML"

# ---------------------------------------------------------------------------
# 2. schema_version is present
# ---------------------------------------------------------------------------
echo "--- Check 2: schema_version is present ---"
if python3 -c "
import yaml, sys
data = yaml.safe_load(open('${EVALS_FILE}'))
sys.exit(0 if data.get('schema_version') else 1)
" 2>/dev/null; then
  pass "schema_version is present"
else
  fail "schema_version is missing from evals/evals.yaml"
fi

# ---------------------------------------------------------------------------
# 3-8. Validate structure, completeness, booleans, duplicates via Python
# ---------------------------------------------------------------------------
echo "--- Check 3-8: Skill eval structure, completeness, and uniqueness ---"

# Export REPO_ROOT for the Python script
export VERIFY_REPO_ROOT="$REPO_ROOT"

PYRESULT=$(python3 - << 'PYEOF'
import yaml
import sys
import os

repo_root = os.environ["VERIFY_REPO_ROOT"]
evals_file = os.path.join(repo_root, "evals", "evals.yaml")
skills_index_file = os.path.join(repo_root, "config", "skills-index.yaml")

RED = "\033[0;31m"
GREEN = "\033[0;32m"
NC = "\033[0m"

passed = 0
failed = 0
output_lines = []

def pass_check(msg):
    global passed
    passed += 1
    output_lines.append(f"  {GREEN}PASS{NC}: {msg}")

def fail_check(msg):
    global failed
    failed += 1
    output_lines.append(f"  {RED}FAIL{NC}: {msg}")

# Load files
with open(evals_file) as f:
    evals_data = yaml.safe_load(f)
with open(skills_index_file) as f:
    index_data = yaml.safe_load(f)

# Check 6: All skills from skills-index.yaml are present
expected_skills = {s["id"] for s in index_data.get("skills", [])}
eval_skills = {s["skill_name"] for s in evals_data.get("skills", [])}

missing_skills = expected_skills - eval_skills
extra_skills = eval_skills - expected_skills

if not missing_skills:
    pass_check(f"All {len(expected_skills)} skills from skills-index.yaml are present in evals")
else:
    for s in sorted(missing_skills):
        fail_check(f"Skill '{s}' from skills-index.yaml is missing in evals/evals.yaml")

if extra_skills:
    for s in sorted(extra_skills):
        fail_check(f"Skill '{s}' in evals/evals.yaml is not in skills-index.yaml")

# Validate each skill
for skill in evals_data.get("skills", []):
    name = skill.get("skill_name", "<unknown>")
    trigger_evals = skill.get("trigger_evals", [])
    quality_evals = skill.get("quality_evals", [])

    # Check 3: At least 3 trigger_evals and at least 1 quality_eval
    if len(trigger_evals) >= 3:
        pass_check(f"{name}: has {len(trigger_evals)} trigger_evals (>= 3)")
    else:
        fail_check(f"{name}: has {len(trigger_evals)} trigger_evals (need >= 3)")

    if len(quality_evals) >= 1:
        pass_check(f"{name}: has {len(quality_evals)} quality_evals (>= 1)")
    else:
        fail_check(f"{name}: has {len(quality_evals)} quality_evals (need >= 1)")

    # Check 4: Each trigger_eval has required fields
    trigger_ids = []
    for te in trigger_evals:
        te_id = te.get("id", "?")
        missing_fields = []
        for field in ("id", "prompt", "should_trigger", "reason"):
            if field not in te:
                missing_fields.append(field)
        if missing_fields:
            fail_check(f"{name}/trigger_eval#{te_id}: missing fields: {', '.join(missing_fields)}")
        else:
            pass_check(f"{name}/trigger_eval#{te_id}: has all required fields")

        # Check 7: should_trigger is a boolean
        st = te.get("should_trigger")
        if st is not None:
            if isinstance(st, bool):
                pass_check(f"{name}/trigger_eval#{te_id}: should_trigger is boolean ({st})")
            else:
                fail_check(f"{name}/trigger_eval#{te_id}: should_trigger is not boolean (got {type(st).__name__}: {st})")

        trigger_ids.append(te_id)

    # Check 5: Each quality_eval has required fields
    quality_ids = []
    for qe in quality_evals:
        qe_id = qe.get("id", "?")
        missing_fields = []
        for field in ("id", "prompt", "expected_behavior", "assertions"):
            if field not in qe:
                missing_fields.append(field)
        if missing_fields:
            fail_check(f"{name}/quality_eval#{qe_id}: missing fields: {', '.join(missing_fields)}")
        else:
            pass_check(f"{name}/quality_eval#{qe_id}: has all required fields")

        # Verify assertions is a non-empty list
        assertions = qe.get("assertions", [])
        if isinstance(assertions, list) and len(assertions) > 0:
            pass_check(f"{name}/quality_eval#{qe_id}: assertions is non-empty list ({len(assertions)} items)")
        else:
            fail_check(f"{name}/quality_eval#{qe_id}: assertions must be a non-empty list")

        quality_ids.append(qe_id)

    # Check 8: No duplicate eval IDs within a skill
    if len(trigger_ids) != len(set(trigger_ids)):
        dupes = [x for x in trigger_ids if trigger_ids.count(x) > 1]
        fail_check(f"{name}: duplicate trigger_eval IDs: {sorted(set(dupes))}")
    else:
        pass_check(f"{name}: no duplicate trigger_eval IDs")

    if len(quality_ids) != len(set(quality_ids)):
        dupes = [x for x in quality_ids if quality_ids.count(x) > 1]
        fail_check(f"{name}: duplicate quality_eval IDs: {sorted(set(dupes))}")
    else:
        pass_check(f"{name}: no duplicate quality_eval IDs")

# Print all output
for line in output_lines:
    print(line)

# Print result marker for bash to parse
print(f"__RESULT__:{passed}:{failed}")
PYEOF
)

# Print Python output (excluding the result marker)
echo "$PYRESULT" | grep -v '^__RESULT__:'

# Parse Python results
PY_LINE=$(echo "$PYRESULT" | grep '^__RESULT__:')
PY_PASSED=$(echo "$PY_LINE" | cut -d: -f2)
PY_FAILED=$(echo "$PY_LINE" | cut -d: -f3)

PASSED=$((PASSED + PY_PASSED))
FAILED=$((FAILED + PY_FAILED))

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Skill evals schema violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All skill evals schema checks pass."
exit 0
