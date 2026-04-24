#!/usr/bin/env bash
# @covers AC-EIP-001, AC-EIP-002, AC-EIP-003, AC-EIP-004
# @spec: execution-invariants-pack_spec.md
# verify-execution-invariants-pack.sh
#
# CI-safe verifier for the execution invariants pack.
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

required_files=(
  "docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md"
  "docs/reference/operations/EXECUTION_CONTEXT_LOCK.md"
  "docs/reference/operations/MUTATION_CLASS_MATRIX.md"
  "docs/reference/operations/PROOF_REPAIR_SEPARATION_PROTOCOL.md"
  "docs/reference/operations/REAL_ACCOUNT_AND_CREDENTIAL_BOUNDARY.md"
  "docs/reference/operations/LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md"
  "docs/reference/operations/RUNNER_CAPABILITY_CONTRACT.md"
  "docs/reference/operations/BUILD_TRUTH_CONTRACT.md"
  "docs/reference/operations/execution-invariants-pack.v1.yaml"
  "docs/reviews/EXECUTION_INVARIANTS_PACK_REVIEW_SUMMARY.md"
)

violations=0

fail() {
  echo "FAIL: $*" >&2
  violations=$((violations + 1))
}

check_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Fq "$pattern" "$path"; then
    fail "$message ($path -> $pattern)"
  fi
}

echo "=== Execution Invariants Pack Verification ==="
echo "Repo: $REPO_ROOT"

for path in "${required_files[@]}"; do
  check_file "$path"
done

python3 - <<'PY' || violations=$((violations + 1))
from pathlib import Path
import sys

try:
    import yaml
except Exception as exc:
    print(f"FAIL: PyYAML import failed: {exc}", file=sys.stderr)
    raise SystemExit(1)

contract_path = Path("docs/reference/operations/execution-invariants-pack.v1.yaml")
payload = yaml.safe_load(contract_path.read_text())

required_top_keys = {
    "version",
    "policy_doc",
    "required_context_lock_keys",
    "allowed_mutation_classes",
    "preconditions_by_mutation_class",
    "prohibited_behaviors",
    "required_post_mutation_evidence_artifacts",
    "allowed_final_status_enums",
    "required_update_sections",
    "reference_docs",
}

missing = sorted(required_top_keys - set(payload))
if missing:
    print(f"FAIL: missing YAML keys: {missing}", file=sys.stderr)
    raise SystemExit(1)

expected_classes = {"repo-only", "gitops-only", "live-proof-only", "live-mutation-exception"}
actual_classes = set(payload["allowed_mutation_classes"])
if actual_classes != expected_classes:
    print(f"FAIL: mutation classes mismatch: {sorted(actual_classes)}", file=sys.stderr)
    raise SystemExit(1)

preconditions = set(payload["preconditions_by_mutation_class"])
if preconditions != expected_classes:
    print(f"FAIL: precondition classes mismatch: {sorted(preconditions)}", file=sys.stderr)
    raise SystemExit(1)

status_enums = payload["allowed_final_status_enums"]
if status_enums != ["IN_PROGRESS", "READY_FOR_REVIEW", "COMPLETE"]:
    print(f"FAIL: final status enums mismatch: {status_enums}", file=sys.stderr)
    raise SystemExit(1)
PY

core="docs/policies/operations/AGENT_EXECUTION_INVARIANTS.md"
check_contains "$core" "## 1. Context Lock" "missing context lock section"
check_contains "$core" "## 2. Clean Transaction Boundary" "missing clean transaction section"
check_contains "$core" "## 3. Mutation Classes" "missing mutation classes section"
check_contains "$core" "## 4. Evidence Before Mutation" "missing evidence-before-mutation section"
check_contains "$core" "## 5. Proof vs Repair Separation" "missing proof/repair section"
check_contains "$core" "## 6. Real-Account / Credential Prohibition" "missing real-account section"
check_contains "$core" "## 7. Scope Guardrails By Lane" "missing lane scope section"
check_contains "$core" "## 8. Build Truth Contract" "missing build truth section"
check_contains "$core" "## 9. Exception Handling And Escalation" "missing exception handling section"
check_contains "$core" "## 10. Required Output Format For Lane Updates" "missing update format section"

for ref in \
  "docs/reference/operations/EXECUTION_CONTEXT_LOCK.md" \
  "docs/reference/operations/MUTATION_CLASS_MATRIX.md" \
  "docs/reference/operations/PROOF_REPAIR_SEPARATION_PROTOCOL.md" \
  "docs/reference/operations/REAL_ACCOUNT_AND_CREDENTIAL_BOUNDARY.md" \
  "docs/reference/operations/LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md" \
  "docs/reference/operations/RUNNER_CAPABILITY_CONTRACT.md" \
  "docs/reference/operations/BUILD_TRUTH_CONTRACT.md" \
  "docs/reference/operations/execution-invariants-pack.v1.yaml"
do
  check_contains "$core" "$ref" "core policy must reference pack artifact"
done

check_contains "docs/reference/operations/EXECUTION_CONTEXT_LOCK.md" "## Required Fields" "context lock required fields missing"
check_contains "docs/reference/operations/EXECUTION_CONTEXT_LOCK.md" "## What Invalidates A Lock" "context lock invalidation missing"
check_contains "docs/reference/operations/MUTATION_CLASS_MATRIX.md" "## Matrix" "mutation matrix missing"
check_contains "docs/reference/operations/PROOF_REPAIR_SEPARATION_PROTOCOL.md" "## Required Sequence" "proof/repair sequence missing"
check_contains "docs/reference/operations/REAL_ACCOUNT_AND_CREDENTIAL_BOUNDARY.md" "## Hard Boundary" "real-account boundary missing"
check_contains "docs/reference/operations/LIVE_MUTATION_EXCEPTION_LEDGER_TEMPLATE.md" "Timestamp:" "ledger template missing timestamp"
check_contains "docs/reference/operations/RUNNER_CAPABILITY_CONTRACT.md" "## Required Capabilities" "runner capability section missing"
check_contains "docs/reference/operations/BUILD_TRUTH_CONTRACT.md" "## Prohibited Truth Models" "build truth section missing"
check_contains "docs/reviews/EXECUTION_INVARIANTS_PACK_REVIEW_SUMMARY.md" "## What Problem This Pack Solves" "review summary missing problem statement"
check_contains "docs/reviews/EXECUTION_INVARIANTS_PACK_REVIEW_SUMMARY.md" "## What It Does Not Solve" "review summary missing limits"

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL: execution invariants pack verification found $violations problem(s)." >&2
  exit 1
fi

echo "PASS: execution invariants pack is present, parseable, and internally wired."
