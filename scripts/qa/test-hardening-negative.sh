#!/usr/bin/env bash
# @covers AC-PROCESS-001
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

# test-hardening-negative.sh — Red-team the hardening system
#
# Seeds deliberate violations and verifies the contract system catches them.
# Every test creates a violation, runs the relevant verifier, and confirms
# it fails. Then cleans up.
#
# If any seeded violation passes undetected, the hardening system has a hole.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

PASSED=0
FAILED=0

pass() { echo "  [PASS] $*"; PASSED=$((PASSED + 1)); }
fail() { echo "  [FAIL] $*" >&2; FAILED=$((FAILED + 1)); }

echo "=== Hardening Negative Tests ==="
echo "Each test seeds a violation and verifies the system catches it."
echo ""

# ── Test 1: Ghost truth file mentioned as canonical ──────────────────
echo "--- Test 1: Ghost truth forbidden mention ---"
TRAP_FILE="config/_test_ghost_trap.yaml"
# Dynamically construct the trap content to avoid this test file itself triggering the scanner
_HOME_SKILLS='~/.factory/skills'
printf '# This is a test file\n# The canonical source for skills is %s\n' "$_HOME_SKILLS" > "$TRAP_FILE"

if bash scripts/qa/verify-ghost-truth-surfaces.sh >/dev/null 2>&1; then
  fail "ghost-truth verifier did NOT catch forbidden mention of home-dir skills"
else
  pass "ghost-truth verifier caught forbidden mention of home-dir skills"
fi
rm -f "$TRAP_FILE"

# ── Test 2: Skill routing contract with unknown skill ────────────────
echo "--- Test 2: Skill routing with unknown skill ---"
cp config/skill-routing-contract.yaml config/skill-routing-contract.yaml.bak
python3 -c "
import yaml
with open('config/skill-routing-contract.yaml') as f:
    d = yaml.safe_load(f)
d['routes'].append({
    'id': 'test-bad-route',
    'symptom': 'Test violation',
    'required_skills': ['layer-triage', 'nonexistent-skill'],
    'entry_point': 'layer-triage',
})
with open('config/skill-routing-contract.yaml', 'w') as f:
    yaml.dump(d, f, default_flow_style=False)
"

if bash scripts/qa/verify-skill-routing-contract.sh >/dev/null 2>&1; then
  fail "skill-routing verifier did NOT catch nonexistent skill reference"
else
  pass "skill-routing verifier caught nonexistent skill reference"
fi
cp config/skill-routing-contract.yaml.bak config/skill-routing-contract.yaml
rm -f config/skill-routing-contract.yaml.bak

# ── Test 3: Route resolver detects ghost truth file ──────────────────
echo "--- Test 3: Route resolver ghost truth detection ---"
OUTPUT=$(python3 scripts/agents/resolve-route.py --repo-root . --files deploy/k8s/overlays/production/kustomization.yaml --json 2>/dev/null)
if echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert any(r.get('type')=='ghost_truth_warning' for r in d['file_routes'])" 2>/dev/null; then
  pass "route resolver flagged ghost truth file"
else
  fail "route resolver did NOT flag ghost truth file"
fi

# ── Test 4: Structural debt register schema violation ────────────────
echo "--- Test 4: Structural debt register missing fields ---"
cp config/structural-debt-register.yaml config/structural-debt-register.yaml.bak
python3 -c "
import yaml
with open('config/structural-debt-register.yaml') as f:
    d = yaml.safe_load(f)
d['entries'].append({
    'id': 'DEBT-TEST-BAD',
    'title': 'Missing required fields',
    # Missing: severity, class, owner_repo, owner_layer, status, etc.
})
with open('config/structural-debt-register.yaml', 'w') as f:
    yaml.dump(d, f, default_flow_style=False)
"

if bash scripts/qa/verify-structural-debt-register.sh >/dev/null 2>&1; then
  fail "structural debt verifier did NOT catch missing fields"
else
  pass "structural debt verifier caught missing fields"
fi
cp config/structural-debt-register.yaml.bak config/structural-debt-register.yaml
rm -f config/structural-debt-register.yaml.bak

# ── Test 5: Branch protection contract invalid YAML ──────────────────
echo "--- Test 5: Branch protection contract invalid data ---"
cp config/branch-protection-contract.yaml config/branch-protection-contract.yaml.bak
echo "repos: [broken: yaml: here" > config/branch-protection-contract.yaml

if bash scripts/qa/verify-branch-protection-contract.sh >/dev/null 2>&1; then
  fail "branch-protection verifier did NOT catch invalid YAML"
else
  pass "branch-protection verifier caught invalid YAML"
fi
cp config/branch-protection-contract.yaml.bak config/branch-protection-contract.yaml
rm -f config/branch-protection-contract.yaml.bak

# ── Test 6: Route resolver returns correct bundle ────────────────────
echo "--- Test 6: Route resolver bundle accuracy ---"
OUTPUT=$(python3 scripts/agents/resolve-route.py --repo-root . --symptom "SSO redirect loop on Studio" --json 2>/dev/null)
if echo "$OUTPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
routes = d['symptom_routes']
assert len(routes) > 0, 'no routes returned'
top = routes[0]
assert 'settings-configmap' in top['required_skills'], f'missing settings-configmap in {top[\"required_skills\"]}'
assert top['entry_point'] == 'layer-triage', f'wrong entry point: {top[\"entry_point\"]}'
" 2>/dev/null; then
  pass "route resolver returns correct bundle for SSO symptom"
else
  fail "route resolver returned wrong bundle for SSO symptom"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "PASS: $PASSED | FAIL: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "HARDENING NEGATIVE TESTS FAILED — the system has holes."
  exit 1
fi

echo "All seeded violations were caught. Controls fail closed."
