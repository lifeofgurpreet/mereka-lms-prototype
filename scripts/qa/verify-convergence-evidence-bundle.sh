#!/usr/bin/env bash
# verify-convergence-evidence-bundle.sh
#
# CI-safe verifier for the convergence evidence bundle pack.
# Ensures all required files exist, required claim classes are present,
# local proof is labeled non-canonical, and phase advance is explicitly blocked.
#
# @covers AC-CEB-001, AC-CEB-002, AC-CEB-003, AC-CEB-004
# @spec: convergence-evidence-bundle_spec.md
#
# Exit codes:
#   0  all checks pass
#   1  one or more checks fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1" >&2; }

require_file() {
  if [[ -f "${REPO_ROOT}/$1" ]]; then
    pass "exists: $1"
  else
    fail "missing: $1"
  fi
}

require_text() {
  local text="$1"
  local path="$2"
  if grep -Fq "$text" "${REPO_ROOT}/${path}" 2>/dev/null; then
    pass "found '${text}' in ${path}"
  else
    fail "missing '${text}' in ${path}"
  fi
}

require_regex() {
  local pattern="$1"
  local path="$2"
  if grep -Eq "$pattern" "${REPO_ROOT}/${path}" 2>/dev/null; then
    pass "matched /${pattern}/ in ${path}"
  else
    fail "no match for /${pattern}/ in ${path}"
  fi
}

CONTRACT="docs/stabilization/CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md"
BUNDLE="docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md"
MANIFEST="docs/stabilization/dev-runtime-convergence-bundle.v1.yaml"
HANDOFF="docs/reviews/CONVERGENCE_EVIDENCE_PROMOTION_HANDOFF.md"

echo "=== Convergence Evidence Bundle Verification ==="
echo ""

# ── 1. Required files ────────────────────────────────────────────────────────
echo "--- Required Files ---"
require_file "${CONTRACT}"
require_file "${BUNDLE}"
require_file "${MANIFEST}"
require_file "${HANDOFF}"
require_file "scripts/qa/verify-convergence-evidence-bundle.sh"
echo ""

# ── 2. Contract has all five claim status classes ────────────────────────────
echo "--- Contract: Claim Status Classes ---"
for cls in CONFIRMED PROVISIONAL CONTRADICTED EXTERNAL_BLOCKER PARKED; do
  require_text "${cls}" "${CONTRACT}"
done
echo ""

# ── 3. Contract has all three durability classes ─────────────────────────────
echo "--- Contract: Durability Classes ---"
for cls in DURABLE MANUAL_STATE TEMPORARY_RUNTIME_MITIGATION; do
  require_text "${cls}" "${CONTRACT}"
done
echo ""

# ── 4. Bundle covers all seven evidence domains ─────────────────────────────
echo "--- Bundle: Evidence Domains ---"
for domain in "Admin Portal" "Learner Portal.*Primary" "Learner Portal.*Secondary" \
              "Build Truth" "GitOps Truth" "Image Truth" "Data-Layer Truth"; do
  require_regex "${domain}" "${BUNDLE}"
done
echo ""

# ── 5. Bundle has required meta-sections ─────────────────────────────────────
echo "--- Bundle: Required Sections ---"
require_regex "Durable Truths" "${BUNDLE}"
require_regex "Provisional Truths" "${BUNDLE}"
require_regex "Contradicted Truths" "${BUNDLE}"
require_regex "Exact Blockers" "${BUNDLE}"
require_regex "Evidence Lane A Must Produce" "${BUNDLE}"
require_regex "What NOT to Claim" "${BUNDLE}"
echo ""

# ── 6. Manifest structure ────────────────────────────────────────────────────
echo "--- Manifest: Structure ---"
require_text "phase: Stabilization" "${MANIFEST}"
require_text "next_allowed_phase: Convergence" "${MANIFEST}"
require_text "phase_gate_status: BLOCKED" "${MANIFEST}"
require_text "promoted_claims:" "${MANIFEST}"
require_text "provisional_claims:" "${MANIFEST}"
require_text "contradicted_claims:" "${MANIFEST}"
require_text "blockers:" "${MANIFEST}"
require_text "promotion_rules:" "${MANIFEST}"
require_text "contradiction_policy:" "${MANIFEST}"
echo ""

# ── 7. Local proof labeled non-canonical ─────────────────────────────────────
echo "--- Contract: Local Proof Policy ---"
# Contract must reference var/proofs AND state they are not canonical (may be on separate lines)
require_text "var/proofs" "${CONTRACT}"
require_text "NOT canonical truth" "${CONTRACT}"
# Contract must reference screenshots AND state they are not durable
require_text "Screenshots" "${CONTRACT}"
require_text "NOT durable closure" "${CONTRACT}"
echo ""

# ── 8. Phase advance explicitly blocked ──────────────────────────────────────
echo "--- Phase Blocking ---"
require_text "BLOCKED" "${BUNDLE}"
require_text "BLOCKED" "${MANIFEST}"
echo ""

# ── 9. Handoff has required content ──────────────────────────────────────────
echo "--- Handoff: Required Sections ---"
require_text "What This Pack Does" "${HANDOFF}"
require_regex "What This Pack Does NOT" "${HANDOFF}"
require_text "What Is Now Canonical" "${HANDOFF}"
require_text "What Still Depends" "${HANDOFF}"
require_regex "What Exact Evidence Is Missing" "${HANDOFF}"
echo ""

# ── 10. No forbidden vague statuses ──────────────────────────────────────────
echo "--- Forbidden Vague Statuses ---"
VAGUE_FOUND=false
for status in BASICALLY_FIXED MOSTLY_DONE ALMOST_THERE GOOD_ENOUGH PROBABLY_WORKS CLOSE_ENOUGH MOSTLY_FIXED GREENISH; do
  for f in "${CONTRACT}" "${BUNDLE}" "${MANIFEST}" "${HANDOFF}"; do
    if grep -Fiq "${status}" "${REPO_ROOT}/${f}" 2>/dev/null; then
      fail "forbidden vague status '${status}' in ${f}"
      VAGUE_FOUND=true
    fi
  done
done
if [[ "${VAGUE_FOUND}" == "false" ]]; then
  pass "no forbidden vague statuses found"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
  echo "VERDICT: FAIL — ${FAIL} check(s) failed"
  exit 1
else
  echo "PASS: convergence evidence bundle pack is present and internally coherent"
  exit 0
fi
