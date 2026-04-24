#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
#
# Guardrail: keep verification-script growth intentional.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CATALOG_JSON="$REPO_ROOT/verification/catalogs/verification_catalog.json"
BUDGET_JSON="$REPO_ROOT/verification/manifests/verification_sprawl_budget.json"

if [[ ! -f "$CATALOG_JSON" ]]; then
  echo "FAIL verification catalog missing: $CATALOG_JSON" >&2
  exit 1
fi

if [[ ! -f "$BUDGET_JSON" ]]; then
  echo "FAIL verification budget missing: $BUDGET_JSON" >&2
  exit 1
fi

python3 - "$CATALOG_JSON" "$BUDGET_JSON" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
budget_path = Path(sys.argv[2])

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
budget = json.loads(budget_path.read_text(encoding="utf-8"))
summary = catalog.get("summary", {})
statuses = summary.get("statuses", {})

metrics = {
    "total_verify_scripts": int(summary.get("total_verify_scripts", 0)),
    "manual_only_scripts": int(statuses.get("manual_only", 0)),
    "deprecated_candidate_scripts": int(statuses.get("deprecated_candidate", 0)),
    "ci_static_bound": int(summary.get("ci_static_bound", 0)),
}

limits = {
    "max_total_verify_scripts": int(budget.get("max_total_verify_scripts", 0)),
    "max_manual_only_scripts": int(budget.get("max_manual_only_scripts", 0)),
    "max_deprecated_candidate_scripts": int(budget.get("max_deprecated_candidate_scripts", 0)),
    "min_ci_static_bound": int(budget.get("min_ci_static_bound", 0)),
}

failed = 0
passed = 0

def ok(message: str) -> None:
    global passed
    passed += 1
    print(f"PASS {message}")

def fail(message: str) -> None:
    global failed
    failed += 1
    print(f"FAIL {message}")

if metrics["total_verify_scripts"] <= limits["max_total_verify_scripts"]:
    ok(
        f"total verify scripts {metrics['total_verify_scripts']} <= budget {limits['max_total_verify_scripts']}"
    )
else:
    fail(
        f"total verify scripts {metrics['total_verify_scripts']} exceeds budget {limits['max_total_verify_scripts']}"
    )

if metrics["manual_only_scripts"] <= limits["max_manual_only_scripts"]:
    ok(
        f"manual-only scripts {metrics['manual_only_scripts']} <= budget {limits['max_manual_only_scripts']}"
    )
else:
    fail(
        f"manual-only scripts {metrics['manual_only_scripts']} exceeds budget {limits['max_manual_only_scripts']}"
    )

if metrics["deprecated_candidate_scripts"] <= limits["max_deprecated_candidate_scripts"]:
    ok(
        f"deprecated-candidate scripts {metrics['deprecated_candidate_scripts']} <= budget {limits['max_deprecated_candidate_scripts']}"
    )
else:
    fail(
        f"deprecated-candidate scripts {metrics['deprecated_candidate_scripts']} exceeds budget {limits['max_deprecated_candidate_scripts']}"
    )

if metrics["ci_static_bound"] >= limits["min_ci_static_bound"]:
    ok(
        f"ci-static bound scripts {metrics['ci_static_bound']} >= floor {limits['min_ci_static_bound']}"
    )
else:
    fail(
        f"ci-static bound scripts {metrics['ci_static_bound']} below floor {limits['min_ci_static_bound']}"
    )

print(f"Summary: PASS={passed} FAIL={failed}")

if failed:
    print("")
    print("Verification sprawl budget violated.")
    print(f"Update budget intentionally in {budget_path} only with review.")
    raise SystemExit(1)
PY

echo "PASS verification sprawl budget"
