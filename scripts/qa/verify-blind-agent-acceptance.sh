#!/usr/bin/env bash
# verify-blind-agent-acceptance.sh — Blind-agent acceptance harness
#
# Simulates 5 questions a fresh agent would ask and verifies
# the contract system routes each to the correct authority surface.
# This is a static test: it checks file existence, content pointers,
# and skill graph completeness — no cluster access needed.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

echo "=== Blind Agent Acceptance Harness ==="
echo "Repo root: ${REPO_ROOT}"
echo

# ---------------------------------------------------------------------------
# Q1: "The MFE login page is blank. What do I do?"
# Expected: layer-triage skill is discoverable, routes to runtime-proof
# ---------------------------------------------------------------------------
echo '--- Q1: "MFE login page is blank" → layer-triage + runtime-proof ---'

if [[ -f "$REPO_ROOT/.factory/skills/layer-triage/SKILL.md" ]]; then
  pass "layer-triage skill exists"
else
  fail "layer-triage skill missing"
fi

if grep -q 'runtime-proof' "$REPO_ROOT/config/skills-graph.yaml" 2>/dev/null; then
  pass "skills-graph routes to runtime-proof"
else
  fail "skills-graph does not mention runtime-proof"
fi

if grep -q 'frontend-mfe-change' "$REPO_ROOT/config/skills-graph.yaml" 2>/dev/null; then
  pass "skills-graph has frontend-mfe-change with dependency chain"
else
  fail "skills-graph missing frontend-mfe-change"
fi

# ---------------------------------------------------------------------------
# Q2: "I need to change LMS_BASE in settings. Where?"
# Expected: settings-configmap skill, points to mereka_lms.py as source
# ---------------------------------------------------------------------------
echo '--- Q2: "Change LMS_BASE" → settings-configmap ---'

if [[ -f "$REPO_ROOT/.factory/skills/settings-configmap/SKILL.md" ]]; then
  if grep -q 'mereka_lms.py' "$REPO_ROOT/.factory/skills/settings-configmap/SKILL.md"; then
    pass "settings-configmap routes to mereka_lms.py"
  else
    fail "settings-configmap does not mention mereka_lms.py"
  fi
else
  fail "settings-configmap skill missing"
fi

if grep -q 'cross-repo-authority' "$REPO_ROOT/config/skills-graph.yaml" 2>/dev/null && \
   grep -A2 'settings-configmap' "$REPO_ROOT/config/skills-graph.yaml" | grep -q 'cross-repo-authority'; then
  pass "settings-configmap requires cross-repo-authority in graph"
else
  fail "settings-configmap missing cross-repo-authority dependency"
fi

# ---------------------------------------------------------------------------
# Q3: "How do I promote a new image to dev?"
# Expected: gitops-promotion skill, cross-repo-authority, proof gate contract
# ---------------------------------------------------------------------------
echo '--- Q3: "Promote image to dev" → gitops-promotion ---'

if [[ -f "$REPO_ROOT/.factory/skills/gitops-promotion/SKILL.md" ]]; then
  pass "gitops-promotion skill exists"
else
  fail "gitops-promotion skill missing"
fi

if [[ -f "$REPO_ROOT/config/proof-gate-contract.yaml" ]]; then
  if grep -q 'release-object-before-promotion' "$REPO_ROOT/config/proof-gate-contract.yaml"; then
    pass "proof-gate-contract has release-object-before-promotion gate"
  else
    fail "proof-gate-contract missing release-object-before-promotion gate"
  fi
else
  fail "proof-gate-contract.yaml missing"
fi

if [[ -f "$REPO_ROOT/config/repo-boundary-contract.yaml" ]]; then
  if grep -q 'bbi-infrastructure' "$REPO_ROOT/config/repo-boundary-contract.yaml"; then
    pass "repo-boundary-contract mentions bbi-infrastructure"
  else
    fail "repo-boundary-contract missing bbi-infrastructure"
  fi
else
  fail "repo-boundary-contract.yaml missing"
fi

# ---------------------------------------------------------------------------
# Q4: "I want to add a new CI check. What's the process?"
# Expected: ci-scope-and-timing skill, ci-scope-contract, script-registry path
# ---------------------------------------------------------------------------
echo '--- Q4: "Add new CI check" → ci-scope-and-timing ---'

if [[ -f "$REPO_ROOT/.factory/skills/ci-scope-and-timing/SKILL.md" ]]; then
  if grep -q 'script-registry.yaml' "$REPO_ROOT/.factory/skills/ci-scope-and-timing/SKILL.md"; then
    pass "ci-scope-and-timing mentions script-registry.yaml"
  else
    fail "ci-scope-and-timing does not mention script-registry.yaml"
  fi
else
  fail "ci-scope-and-timing skill missing"
fi

if [[ -f "$REPO_ROOT/config/ci-scope-contract.yaml" ]]; then
  pass "ci-scope-contract.yaml exists"
else
  fail "ci-scope-contract.yaml missing"
fi

if [[ -f "$REPO_ROOT/config/generated-surface-lineage.yaml" ]]; then
  if grep -q 'ci-static-inventory' "$REPO_ROOT/config/generated-surface-lineage.yaml"; then
    pass "generated-surface-lineage tracks ci-static-inventory"
  else
    fail "generated-surface-lineage missing ci-static-inventory entry"
  fi
else
  fail "generated-surface-lineage.yaml missing"
fi

# ---------------------------------------------------------------------------
# Q5: "Should I edit the overlay in this repo or bbi-infrastructure?"
# Expected: cross-repo-authority skill, repo-boundary-contract
# ---------------------------------------------------------------------------
echo '--- Q5: "Which repo owns overlays?" → cross-repo-authority ---'

if [[ -f "$REPO_ROOT/.factory/skills/cross-repo-authority/SKILL.md" ]]; then
  if grep -q 'bbi-infrastructure' "$REPO_ROOT/.factory/skills/cross-repo-authority/SKILL.md"; then
    pass "cross-repo-authority skill mentions bbi-infrastructure"
  else
    fail "cross-repo-authority skill does not mention bbi-infrastructure"
  fi
else
  fail "cross-repo-authority skill missing"
fi

if [[ -f "$REPO_ROOT/config/repo-boundary-contract.yaml" ]]; then
  if grep -q 'transitional' "$REPO_ROOT/config/repo-boundary-contract.yaml"; then
    pass "repo-boundary-contract has transitional classification"
  else
    fail "repo-boundary-contract missing transitional entries"
  fi
else
  fail "repo-boundary-contract.yaml missing"
fi

# ---------------------------------------------------------------------------
# Meta: contract system completeness
# ---------------------------------------------------------------------------
echo '--- Meta: Contract system completeness ---'

REQUIRED_CONTRACTS=(
  "config/skills-index.yaml"
  "config/skills-graph.yaml"
  "config/generated-surface-lineage.yaml"
  "config/repo-boundary-contract.yaml"
  "config/proof-gate-contract.yaml"
  "config/ci-scope-contract.yaml"
  "config/change-surface-contracts.yaml"
  "config/process-invariants.yaml"
)

for contract in "${REQUIRED_CONTRACTS[@]}"; do
  if [[ -f "$REPO_ROOT/$contract" ]]; then
    pass "$contract exists"
  else
    fail "$contract missing"
  fi
done

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: ${PASSED} | ${RED}FAIL${NC}: ${FAILED}"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Blind agent acceptance harness FAILED."
  exit 1
fi

echo "All blind agent acceptance checks pass."
