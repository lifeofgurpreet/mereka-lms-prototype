#!/usr/bin/env bash
# @covers AC-TRUTH-003
# @spec: stabilization-control-board_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTER_FILE="$REPO_ROOT/config/structural-debt-register.yaml"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Structural Debt Register Verification ==="
echo "Repo root: $REPO_ROOT"

echo "--- Check 1: register exists and is valid YAML ---"
if [[ -f "$REGISTER_FILE" ]]; then
  pass "$REGISTER_FILE exists"
else
  fail "$REGISTER_FILE missing"
fi
if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$REGISTER_FILE" 2>/dev/null; then
  pass "$REGISTER_FILE is valid YAML"
else
  fail "$REGISTER_FILE is not valid YAML"
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

echo "--- Check 2: entries are complete, unique, and severity-ranked ---"
if python3 - "$REGISTER_FILE" <<'PY'
import re
import sys

import yaml

register = yaml.safe_load(open(sys.argv[1]))
entries = register.get("entries", [])
issues = []
ids = []
allowed_severity = {"critical", "high", "medium", "low"}
allowed_decision = {"kill", "migrate", "tolerate"}
allowed_status = {"open", "in-progress", "resolved"}
allowed_layers = {"source", "build", "promotion", "realization", "runtime", "proof"}
required_classes = {"ghost-truth-surface", "local-only-truth", "shared-skill-loader", "live-governance-gap"}
seen_classes = set()

if len(entries) < 15:
    issues.append(f"expected at least 15 debt entries, found {len(entries)}")

for entry in entries:
    for field in (
        "id",
        "title",
        "severity",
        "class",
        "owner_repo",
        "owner_layer",
        "evidence",
        "current_risk",
        "decision",
        "action",
        "review_date",
        "status",
    ):
        if field not in entry:
            issues.append(f"{entry.get('id', '<unknown>')}: missing {field}")
    ids.append(entry.get("id"))
    seen_classes.add(entry.get("class"))
    if entry.get("severity") not in allowed_severity:
        issues.append(f"{entry.get('id')}: invalid severity {entry.get('severity')}")
    if entry.get("decision") not in allowed_decision:
        issues.append(f"{entry.get('id')}: invalid decision {entry.get('decision')}")
    if entry.get("status") not in allowed_status:
        issues.append(f"{entry.get('id')}: invalid status {entry.get('status')}")
    if entry.get("owner_layer") not in allowed_layers:
        issues.append(f"{entry.get('id')}: invalid owner_layer {entry.get('owner_layer')}")
    if not re.match(r"^DEBT-\d{3}$", entry.get("id", "")):
        issues.append(f"{entry.get('id')}: invalid debt id format")
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", str(entry.get("review_date", ""))):
        issues.append(f"{entry.get('id')}: review_date must be YYYY-MM-DD")

if len(ids) != len(set(ids)):
    issues.append("duplicate debt ids detected")

missing_classes = required_classes - seen_classes
for klass in sorted(missing_classes):
    issues.append(f"missing required debt class {klass}")

if issues:
    for issue in issues:
        print(issue)
    raise SystemExit(1)

print(f"Validated {len(entries)} structural debt entries")
PY
then
  pass "structural debt register is complete and machine-readable"
else
  fail "structural debt register has schema or coverage gaps"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Structural debt register checks pass."
