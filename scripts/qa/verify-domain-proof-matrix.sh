#!/usr/bin/env bash
# @covers AC-DPM-001
# @spec: multi-site-domains_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/domain-proof-matrix.yaml"
SUMMARY_FILE="${1:-$REPO_ROOT/var/qa/domain-proof-summary.json}"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Domain Proof Matrix Verification ==="
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

echo "--- Check 2: summary can be generated and blocker classes are classified ---"
if python3 - "$REPO_ROOT" "$CONTRACT_FILE" "$SUMMARY_FILE" <<'PY'
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
contract_file = Path(sys.argv[2])
summary_file = Path(sys.argv[3])

contract = yaml.safe_load(contract_file.read_text())
tenant_registry = yaml.safe_load((repo_root / contract["inputs"]["tenant_registry"]).read_text())
smoke_registry = yaml.safe_load((repo_root / contract["inputs"]["smoke_registry"]).read_text())

dns_records = {}
for row in contract["inputs"]["dns_records"]:
    dns_rows = json.loads((repo_root / row["file"]).read_text())
    dns_records[row["environment"]] = {
        entry.get("name")
        for entry in dns_rows
        if isinstance(entry, dict) and entry.get("name")
    }

browser_matrices = {}
for row in contract["inputs"].get("browser_matrices", []):
    data = json.loads((repo_root / row["file"]).read_text())
    browser_matrices[row["environment"]] = {
        entry["tenant"]: entry
        for entry in data.get("tenants", [])
        if isinstance(entry, dict) and entry.get("tenant")
    }

accounts = smoke_registry.get("accounts", [])
rules = {row["role"]: row for row in contract.get("surface_rules", [])}
default_rule = contract["default_surface_rule"]
count_statuses = set(contract["scoring"]["count_statuses"])

def find_account(domain_row, rule):
    fixed_id = rule.get("smoke_account_id")
    if fixed_id:
        for account in accounts:
            if account.get("id") == fixed_id:
                return account
        return None
    smoke_role = rule.get("smoke_account_role", "none")
    if smoke_role in (None, "", "none"):
        return None
    env = domain_row["environment"]
    tenant = domain_row["tenant"]
    for account in accounts:
        if account.get("tenant") == tenant and account.get("role") == smoke_role and env in account.get("target_envs", []):
            return account
    return None

rows = []
status_counts = Counter()
blocker_counts = Counter()
by_environment = defaultdict(Counter)

for domain in tenant_registry.get("domains", []):
    if domain.get("status") not in count_statuses:
        continue
    env_id = domain["environment"]
    env_contract = contract["environments"].get(env_id, {})
    if not env_contract.get("count_in_scoreboard", True):
        continue
    env_meta = tenant_registry["environments"].get(env_id, {})
    rule = dict(default_rule)
    rule.update(rules.get(domain["role"], {}))

    blockers = []
    account = find_account(domain, rule)
    if rule.get("smoke_account_required", False):
        if account is None or account.get("state") != "provisioned":
            blockers.append("secrets")

    if any(not (repo_root / workflow).exists() for workflow in env_contract.get("required_workflows", [])):
        blockers.append("ci")

    if env_id != "local":
        if not all(env_meta.get(field) for field in ("gitops_repo", "gitops_overlay_path", "argocd_app")):
            blockers.append("promotion")

    if env_meta.get("scheme") == "https":
        if not domain.get("ingress_tls", False):
            blockers.append("runtime")
        if domain["domain"] not in dns_records.get(env_id, set()):
            blockers.append("runtime")

    proof_mode = rule.get("proof_mode", "metadata_only")
    matrix_entry = browser_matrices.get(env_id, {}).get(domain["tenant"])
    if proof_mode == "browser_matrix":
        if not env_meta.get("runtime_proof_script"):
            blockers.append("runtime")
        if matrix_entry is None:
            blockers.append("runtime")

    blockers = sorted(
        set(blockers),
        key=lambda item: contract["scoring"]["blocker_priority"].index(item),
    )

    if blockers:
        status = "red"
    elif proof_mode == "browser_matrix" and matrix_entry and matrix_entry.get("contract_ready"):
        status = "green"
    else:
        status = "unknown"

    status_counts[status] += 1
    by_environment[env_id][status] += 1
    for blocker in blockers:
        blocker_counts[blocker] += 1

    rows.append(
        {
            "environment": env_id,
            "tenant": domain["tenant"],
            "domain": domain["domain"],
            "role": domain["role"],
            "status": status,
            "blockers": blockers,
            "proof_mode": proof_mode,
            "runtime_proof_script": env_meta.get("runtime_proof_script", ""),
            "gitops_overlay_path": env_meta.get("gitops_overlay_path", ""),
        }
    )

summary = {
    "schema_version": contract["schema_version"],
    "total_units": len(rows),
    "status_counts": dict(status_counts),
    "blocked_counts": {
        key: blocker_counts.get(key, 0)
        for key in contract["scoring"]["blocker_priority"]
    },
    "by_environment": {
        env: dict(counts)
        for env, counts in sorted(by_environment.items())
    },
    "rows": rows,
}
summary_file.parent.mkdir(parents=True, exist_ok=True)
summary_file.write_text(json.dumps(summary, indent=2) + "\n")

print(f"Generated proof summary: {summary_file}")
print(f"Total proof units: {summary['total_units']}")
print(f"Status counts: {summary['status_counts']}")
print(f"Blocked counts: {summary['blocked_counts']}")
PY
then
  pass "domain proof summary generated at $SUMMARY_FILE"
else
  fail "domain proof summary generation failed"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Domain proof matrix checks pass."
