#!/usr/bin/env bash
# verify-skill-graph-coverage.sh — Verify skill graph coverage and index integrity
#
# Ensures that:
# 1. .factory/skills/ directory exists
# 2. Every skill directory has a SKILL.md
# 3. config/skills-index.yaml exists and is valid YAML
# 4. config/skills-graph.yaml exists and is valid YAML
# 5. Every skill in .factory/skills/ is listed in skills-index.yaml
# 6. Every skill in skills-graph.yaml exists in .factory/skills/
# 7. No skill in the graph has an unresolved dependency
# 8. Count of indexed skills >= 9
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

echo "=== Skill Graph Coverage Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

SKILLS_DIR=".factory/skills"
INDEX_FILE="config/skills-index.yaml"
GRAPH_FILE="config/skills-graph.yaml"

# ---------------------------------------------------------------------------
# 1. .factory/skills/ directory exists
# ---------------------------------------------------------------------------
echo "--- Check 1: Skills directory exists ---"
if [[ -d "$SKILLS_DIR" ]]; then
  pass "$SKILLS_DIR directory exists"
else
  fail "$SKILLS_DIR directory does not exist"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Every skill directory has a SKILL.md
# ---------------------------------------------------------------------------
echo "--- Check 2: Every skill directory has a SKILL.md ---"
check2_failed=0
shopt -s nullglob
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    pass "$skill_name has SKILL.md"
  else
    fail "$skill_name is missing SKILL.md"
    check2_failed=$((check2_failed + 1))
  fi
done
shopt -u nullglob

# ---------------------------------------------------------------------------
# 3. config/skills-index.yaml exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 3: Skills index exists and is valid YAML ---"
if [[ ! -f "$INDEX_FILE" ]]; then
  fail "$INDEX_FILE does not exist"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "$INDEX_FILE exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$INDEX_FILE" 2>/dev/null; then
  pass "$INDEX_FILE is valid YAML"
else
  fail "$INDEX_FILE is not valid YAML"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. config/skills-graph.yaml exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 4: Skills graph exists and is valid YAML ---"
if [[ ! -f "$GRAPH_FILE" ]]; then
  fail "$GRAPH_FILE does not exist"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "$GRAPH_FILE exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$GRAPH_FILE" 2>/dev/null; then
  pass "$GRAPH_FILE is valid YAML"
else
  fail "$GRAPH_FILE is not valid YAML"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# 5. Every skill in .factory/skills/ is listed in skills-index.yaml
# ---------------------------------------------------------------------------
echo "--- Check 5: Every on-disk skill is listed in skills-index.yaml ---"
index_check=$(python3 -c "
import yaml, os, sys

with open('$INDEX_FILE') as f:
    data = yaml.safe_load(f)

# Collect all skill IDs from the index
indexed = set()
for skill in data.get('skills', []):
    sid = skill.get('id', '')
    if sid:
        indexed.add(sid)

# List on-disk skills
on_disk = set()
skills_dir = '$SKILLS_DIR'
for entry in os.listdir(skills_dir):
    if os.path.isdir(os.path.join(skills_dir, entry)):
        on_disk.add(entry)

missing = on_disk - indexed
for m in sorted(missing):
    print(f'MISSING_FROM_INDEX:{m}')

print(f'COUNT:{len(indexed)}')
" 2>/dev/null)

missing_from_index=$(echo "$index_check" | grep "^MISSING_FROM_INDEX:" || true)
if [[ -z "$missing_from_index" ]]; then
  pass "All on-disk skills are listed in skills-index.yaml"
else
  while IFS= read -r line; do
    skill_name="${line#MISSING_FROM_INDEX:}"
    fail "Skill '$skill_name' exists on disk but is not in skills-index.yaml"
  done <<< "$missing_from_index"
fi

# ---------------------------------------------------------------------------
# 6. Every skill in skills-graph.yaml exists in .factory/skills/
# ---------------------------------------------------------------------------
echo "--- Check 6: Every skill in graph exists on disk ---"
graph_check=$(python3 -c "
import yaml, os, sys

with open('$GRAPH_FILE') as f:
    data = yaml.safe_load(f)

skills_dir = '$SKILLS_DIR'
on_disk = set()
for entry in os.listdir(skills_dir):
    if os.path.isdir(os.path.join(skills_dir, entry)):
        on_disk.add(entry)

# Collect all node IDs from the graph
graph_nodes = set()
for node in data.get('nodes', data.get('skills', [])):
    nid = node.get('id', '')
    if nid:
        graph_nodes.add(nid)

missing = graph_nodes - on_disk
for m in sorted(missing):
    print(f'MISSING_ON_DISK:{m}')
" 2>/dev/null)

missing_on_disk=$(echo "$graph_check" | grep "^MISSING_ON_DISK:" || true)
if [[ -z "$missing_on_disk" ]]; then
  pass "All skills in graph exist on disk"
else
  while IFS= read -r line; do
    skill_name="${line#MISSING_ON_DISK:}"
    fail "Skill '$skill_name' in skills-graph.yaml does not exist in $SKILLS_DIR"
  done <<< "$missing_on_disk"
fi

# ---------------------------------------------------------------------------
# 7. No unresolved dependencies in graph
# ---------------------------------------------------------------------------
echo "--- Check 7: No unresolved dependencies in graph ---"
dep_check=$(python3 -c "
import yaml, sys

with open('$GRAPH_FILE') as f:
    data = yaml.safe_load(f)

nodes = data.get('nodes', data.get('skills', []))
all_ids = set()
for node in nodes:
    nid = node.get('id', '')
    if nid:
        all_ids.add(nid)

unresolved = []
for node in nodes:
    nid = node.get('id', 'unknown')
    for dep in node.get('requires', node.get('dependencies', [])):
        if dep not in all_ids:
            unresolved.append(f'UNRESOLVED:{nid}:{dep}')

for u in unresolved:
    print(u)
" 2>/dev/null)

if [[ -z "$dep_check" ]]; then
  pass "No unresolved dependencies in skills-graph.yaml"
else
  while IFS= read -r line; do
    parts="${line#UNRESOLVED:}"
    skill_id="${parts%%:*}"
    dep_id="${parts#*:}"
    fail "Skill '$skill_id' requires '$dep_id' which does not exist in the graph"
  done <<< "$dep_check"
fi

# ---------------------------------------------------------------------------
# 8. Count of indexed skills >= 9
# ---------------------------------------------------------------------------
echo "--- Check 8: Minimum indexed skill count ---"
indexed_count=$(echo "$index_check" | grep "^COUNT:" | head -1 | cut -d: -f2)
if [[ "${indexed_count:-0}" -ge 9 ]]; then
  pass "Indexed skill count ($indexed_count) >= 9"
else
  fail "Indexed skill count (${indexed_count:-0}) < 9 minimum"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Skill graph coverage violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All skill graph coverage checks pass."
exit 0
