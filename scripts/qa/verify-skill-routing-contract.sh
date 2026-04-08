#!/usr/bin/env bash
# @covers AC-PROCESS-001
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

# verify-skill-routing-contract.sh — Validate skill routing contract
#
# Checks:
#   1. Contract file exists and is valid YAML
#   2. Every route has required fields
#   3. Every referenced skill exists in skills-graph.yaml
#   4. entry_point is always in required_skills
#   5. No duplicate route IDs

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$REPO_ROOT/config/skill-routing-contract.yaml"
GRAPH="$REPO_ROOT/config/skills-graph.yaml"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*" >&2; failures=$((failures + 1)); }

echo "=== Skill Routing Contract Verification ==="

echo "--- Check 1: contract exists and is valid YAML ---"
if [[ -f "$CONTRACT" ]]; then
  pass "contract exists"
else
  fail "contract missing: $CONTRACT"
  echo "FAIL: $failures" && exit 1
fi

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT" 2>/dev/null; then
  pass "valid YAML"
else
  fail "invalid YAML"
fi

echo "--- Check 2: schema and field validation ---"
python3 - "$CONTRACT" "$GRAPH" <<'PY'
import sys
import yaml

contract = yaml.safe_load(open(sys.argv[1]))
graph = yaml.safe_load(open(sys.argv[2]))

routes = contract.get("routes", [])
if not routes:
    print("  [FAIL] no routes defined")
    sys.exit(1)

# Collect known skills from the graph
known_skills = set()
for dep in graph.get("dependencies", []):
    known_skills.add(dep["skill"])

errors = []
ids_seen = set()

for route in routes:
    rid = route.get("id", "<missing>")

    # Required fields
    for field in ("id", "symptom", "required_skills", "entry_point"):
        if field not in route:
            errors.append(f"route '{rid}': missing field '{field}'")

    # Duplicate IDs
    if rid in ids_seen:
        errors.append(f"duplicate route ID: {rid}")
    ids_seen.add(rid)

    # entry_point must be in required_skills
    required = route.get("required_skills", [])
    entry = route.get("entry_point")
    if entry and entry not in required:
        errors.append(f"route '{rid}': entry_point '{entry}' not in required_skills")

    # All referenced skills must exist in graph
    all_skills = required + route.get("recommended_skills", [])
    for skill in all_skills:
        if skill not in known_skills:
            errors.append(f"route '{rid}': skill '{skill}' not in skills-graph.yaml")

if errors:
    for e in errors:
        print(f"  [FAIL] {e}")
    sys.exit(1)

print(f"  [PASS] {len(routes)} routes validated, all skills resolve, no duplicates")
PY

if [[ $? -eq 0 ]]; then
  passes=$((passes + 1))
else
  failures=$((failures + 1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
echo "Skill routing contract checks pass."
