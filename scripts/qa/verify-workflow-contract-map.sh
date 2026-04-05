#!/usr/bin/env bash
# @covers AC-CI-016
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/workflow-contract-map.yaml"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Workflow Contract Map Verification ==="
echo "Repo root: $REPO_ROOT"

echo "--- Check 1: contract exists and is valid YAML ---"
if [[ -f "$CONTRACT_FILE" ]]; then
  pass "$CONTRACT_FILE exists"
else
  fail "$CONTRACT_FILE missing"
fi
if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT_FILE" 2>/dev/null; then
  pass "$CONTRACT_FILE is valid YAML"
else
  fail "$CONTRACT_FILE is not valid YAML"
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

echo "--- Check 2: every contract names a consuming verifier and workflow/inventory ---"
if python3 - "$REPO_ROOT" "$CONTRACT_FILE" <<'PY'
import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
contract = yaml.safe_load(open(sys.argv[2]))
issues = []

inventories = contract.get("inventories", {})
manual_profiles = {row["id"]: row for row in contract.get("manual_profiles", [])}
inventory_lines_cache = {}

for inv_name, inv in inventories.items():
    inventory_file = repo_root / inv["generated_file"]
    if not inventory_file.exists():
        issues.append(f"inventory {inv_name} missing generated file {inventory_file}")
        continue
    inventory_lines = {
        line.strip()
        for line in inventory_file.read_text().splitlines()
        if line.strip()
    }
    inventory_lines_cache[inv_name] = inventory_lines
    for workflow_path in inv.get("workflows", []):
        if not (repo_root / workflow_path).exists():
            issues.append(f"inventory {inv_name} references missing workflow {workflow_path}")
    for shard in inv.get("shard_files", []):
        if not (repo_root / shard).exists():
            issues.append(f"inventory {inv_name} missing shard file {shard}")
    for script in inv.get("required_scripts", []):
        if script not in inventory_lines:
            issues.append(f"inventory {inv_name} missing required script {script}")

for row in contract.get("contracts", []):
    contract_path = repo_root / row["contract"]
    verifier_path = repo_root / row["verifier"]
    if not contract_path.exists():
        issues.append(f"missing contract file {row['contract']}")
    if not verifier_path.exists():
        issues.append(f"missing verifier file {row['verifier']}")
    inventory_name = row.get("inventory")
    manual_profile = row.get("manual_profile")
    if bool(inventory_name) == bool(manual_profile):
        issues.append(f"{row['contract']}: exactly one of inventory or manual_profile must be set")
    if inventory_name:
        inventory = inventories.get(inventory_name)
        if inventory is None:
            issues.append(f"{row['contract']}: inventory {inventory_name} not defined")
        elif row["verifier"] not in inventory_lines_cache.get(inventory_name, set()):
            issues.append(f"{row['contract']}: verifier {row['verifier']} not present in inventory {inventory_name}")
    if manual_profile:
        profile = manual_profiles.get(manual_profile)
        if profile is None:
            issues.append(f"{row['contract']}: manual profile {manual_profile} not defined")
        elif profile.get("verifier") != row["verifier"]:
            issues.append(f"{row['contract']}: manual profile {manual_profile} verifier mismatch")

for workflow in contract.get("workflows", []):
    workflow_path = repo_root / workflow["file"]
    if not workflow_path.exists():
        issues.append(f"missing workflow file {workflow['file']}")
        continue
    workflow_text = workflow_path.read_text(encoding="utf-8")
    for token in workflow.get("references", []):
        if token not in workflow_text:
            issues.append(f"workflow {workflow['file']} missing reference token {token!r}")

if issues:
    for issue in issues:
        print(issue)
    raise SystemExit(1)

print(
    f"Validated {len(contract.get('contracts', []))} contract mappings, "
    f"{len(contract.get('workflows', []))} workflows, and {len(inventories)} inventories"
)
PY
then
  pass "workflow map is structurally complete and references live consumers"
else
  fail "workflow map has missing consumers or stale references"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Workflow contract map checks pass."
