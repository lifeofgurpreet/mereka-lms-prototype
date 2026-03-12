#!/usr/bin/env bash
# @covers AC-SCB-001, AC-SCB-002, AC-SCB-003, AC-SCB-004
# @spec: stabilization-control-board_spec.md
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

require_grep() {
  local pattern="$1"
  local path="$2"
  grep -Eq "$pattern" "${REPO_ROOT}/${path}" || fail "missing pattern '${pattern}' in ${path}"
}

require_literal() {
  local text="$1"
  local path="$2"
  grep -Fq "$text" "${REPO_ROOT}/${path}" || fail "missing text '${text}' in ${path}"
}

BOARD="docs/stabilization/STABILIZATION_CONTROL_BOARD.md"
GATES="docs/stabilization/STABILIZATION_PHASE_GATES.md"
STATE_MATRIX="docs/stabilization/DURABLE_VS_MANUAL_STATE_MATRIX.md"
MANIFEST="docs/stabilization/stabilization-control-board.v1.yaml"
RELEASE_CONTRACT="docs/stabilization/RELEASE_EVIDENCE_BUNDLE_CONTRACT.md"
HANDOFF="docs/reviews/STABILIZATION_CONTROL_BOARD_HANDOFF.md"

require_file "${BOARD}"
require_file "${GATES}"
require_file "${STATE_MATRIX}"
require_file "${MANIFEST}"
require_file "${RELEASE_CONTRACT}"
require_file "${HANDOFF}"

for phase in "Stabilization" "Convergence" "Architecture Hardening"; do
  require_literal "${phase}" "${BOARD}"
done

for status in "COMPLETE" "ACTIVE" "BLOCKED" "PARKED"; do
  require_literal "${status}" "${BOARD}"
done

for truth in "CONFIRMED" "PROVISIONAL" "CONTRADICTED" "EXTERNAL_BLOCKER"; do
  require_literal "${truth}" "${BOARD}"
done

for state_class in "DURABLE" "MANUAL_STATE" "TEMPORARY_RUNTIME_MITIGATION"; do
  require_literal "${state_class}" "${BOARD}"
  require_literal "${state_class}" "${STATE_MATRIX}"
done

require_literal "Stabilization -> Convergence" "${GATES}"
require_literal "Convergence -> Architecture Hardening" "${GATES}"
require_literal "admin merge != semantic proof" "${STATE_MATRIX}"
require_literal "browser proof outranks curl for user-visible success" "${STATE_MATRIX}"
require_literal "pod-local hot-patch != closure" "${STATE_MATRIX}"
require_literal "DB write != architecture closure" "${STATE_MATRIX}"
require_literal "latest are not authoritative" "${RELEASE_CONTRACT}"
require_literal "manual runtime mitigations must not appear inside the release bundle as if they were durable" "${RELEASE_CONTRACT}"

for key in "current_phase:" "next_allowed_phase:" "phase_gate_status:" "lanes:" "open_blockers:" "gate_owners:" "local_proof_policy:"; do
  require_literal "${key}" "${MANIFEST}"
done

for truth in "CONFIRMED" "PROVISIONAL" "CONTRADICTED" "EXTERNAL_BLOCKER" "PARKED"; do
  require_literal "${truth}" "${MANIFEST}"
done

for state_class in "DURABLE" "MANUAL_STATE" "TEMPORARY_RUNTIME_MITIGATION"; do
  require_literal "${state_class}" "${MANIFEST}"
done

require_literal "external lane evidence" "${BOARD}"
require_literal "local proof input" "${BOARD}"
require_literal "not independently reverified by this lane" "${BOARD}"

if grep -RInEq '\b(IN_PROGRESS|READY_FOR_REVIEW|DONE|RESOLVED|NON_DURABLE)\b' \
  "${REPO_ROOT}/${BOARD}" \
  "${REPO_ROOT}/${GATES}" \
  "${REPO_ROOT}/${STATE_MATRIX}" \
  "${REPO_ROOT}/${MANIFEST}" \
  "${REPO_ROOT}/${RELEASE_CONTRACT}" \
  "${REPO_ROOT}/${HANDOFF}"; then
  fail "found forbidden duplicate/contradictory status naming in control-board pack"
fi

if grep -RInq 'var/proofs/' \
  "${REPO_ROOT}/${BOARD}" \
  "${REPO_ROOT}/${GATES}" \
  "${REPO_ROOT}/${STATE_MATRIX}" \
  "${REPO_ROOT}/${MANIFEST}" \
  "${REPO_ROOT}/${RELEASE_CONTRACT}" \
  "${REPO_ROOT}/${HANDOFF}"; then
  require_literal "non-canonical" "${BOARD}"
  require_literal "local proof input" "${BOARD}"
fi

python3 - <<'PY' "${REPO_ROOT}/${MANIFEST}" || fail "manifest validation failed"
import sys
from pathlib import Path

manifest = Path(sys.argv[1]).read_text(encoding="utf-8")
if not manifest.strip():
    raise SystemExit("manifest is empty")
if "version: v1" not in manifest:
    raise SystemExit("manifest missing version")
if "current_phase: Stabilization" not in manifest:
    raise SystemExit("manifest missing current phase")
if "next_allowed_phase: Convergence" not in manifest:
    raise SystemExit("manifest missing next allowed phase")
PY

echo "PASS: stabilization control board pack is present and internally coherent"
