#!/usr/bin/env bash
# @covers AC-CEB-001, AC-CEB-002, AC-CEB-003, AC-CEB-004
# @spec: convergence-evidence-bundle_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${REPO_ROOT}/${path}" ]] || fail "missing required file: ${path}"
}

require_literal() {
  local text="$1"
  local path="$2"
  grep -Fq "$text" "${REPO_ROOT}/${path}" || fail "missing text '${text}' in ${path}"
}

CONTRACT="docs/stabilization/CONVERGENCE_EVIDENCE_BUNDLE_CONTRACT.md"
BUNDLE="docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md"
MANIFEST="docs/stabilization/dev-runtime-convergence-bundle.v1.yaml"
HANDOFF="docs/reviews/CONVERGENCE_EVIDENCE_PROMOTION_HANDOFF.md"

require_file "${CONTRACT}"
require_file "${BUNDLE}"
require_file "${MANIFEST}"
require_file "${HANDOFF}"

for truth in "CONFIRMED" "PROVISIONAL" "CONTRADICTED" "EXTERNAL_BLOCKER" "PARKED"; do
  require_literal "${truth}" "${CONTRACT}"
done

for state_class in "DURABLE" "MANUAL_STATE" "TEMPORARY_RUNTIME_MITIGATION"; do
  require_literal "${state_class}" "${CONTRACT}"
done

for section in \
  "Durable Truths Already Promotable" \
  "Provisional Truths Still Awaiting Promotion" \
  "Contradicted Truths That Must Stay Open" \
  "Exact Blockers Preventing \`Stabilization -> Convergence\`" \
  "Exact Evidence Lane A Must Produce Next" \
  "What Not To Claim Yet"; do
  require_literal "${section}" "${BUNDLE}"
done

for label in "external lane evidence" "local proof input" "not independently reverified by this lane"; do
  require_literal "${label}" "${BUNDLE}"
  require_literal "${label}" "${MANIFEST}"
done

require_literal "phase: Stabilization" "${MANIFEST}"
require_literal "next_allowed_phase: Convergence" "${MANIFEST}"
require_literal "phase_gate_status: BLOCKED" "${MANIFEST}"
require_literal "promoted_claims:" "${MANIFEST}"
require_literal "provisional_claims:" "${MANIFEST}"
require_literal "contradicted_claims:" "${MANIFEST}"
require_literal "blockers:" "${MANIFEST}"
require_literal "promotion_rules:" "${MANIFEST}"
require_literal "contradiction_policy:" "${MANIFEST}"
require_literal "screenshots_alone_are_insufficient: true" "${MANIFEST}"
require_literal "admin_merge_is_not_runtime_proof: true" "${MANIFEST}"

require_literal "remains blocked in \`Stabilization\`" "${HANDOFF}"
require_literal "does not claim learner portal closure" "${HANDOFF}"

if grep -RInEq '\b(MOSTLY_FIXED|BASICALLY_FIXED|ALMOST_DONE|GREENISH|CLOSE_ENOUGH)\b' \
  "${REPO_ROOT}/${CONTRACT}" \
  "${REPO_ROOT}/${BUNDLE}" \
  "${REPO_ROOT}/${MANIFEST}" \
  "${REPO_ROOT}/${HANDOFF}"; then
  fail "found forbidden vague status naming in convergence bundle pack"
fi

python3 - <<'PY' "${REPO_ROOT}/${MANIFEST}" || fail "manifest validation failed"
import sys
from pathlib import Path

manifest = Path(sys.argv[1]).read_text(encoding="utf-8")
for snippet in (
    "version: v1",
    "phase: Stabilization",
    "next_allowed_phase: Convergence",
    "phase_gate_status: BLOCKED",
):
    if snippet not in manifest:
        raise SystemExit(f"missing manifest snippet: {snippet}")
PY

echo "PASS: convergence evidence bundle pack is present and internally coherent"
