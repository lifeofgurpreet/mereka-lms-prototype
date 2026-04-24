#!/usr/bin/env bash
# @covers AC-CI-017
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RUNNER="$REPO_ROOT/scripts/qa/run-skill-evals.py"
EVALS_FILE="$REPO_ROOT/evals/evals.yaml"
PREDICTIONS_FILE="$REPO_ROOT/evals/fixtures/top-risk-baseline.json"
OUTPUT_FILE="$REPO_ROOT/var/qa/skill-eval-summary.json"
SKILLS="layer-triage,frontend-mfe-change,settings-configmap,gitops-promotion,runtime-proof"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Skill Eval Runner Verification ==="
echo "Repo root: $REPO_ROOT"

echo "--- Check 1: runner and fixtures exist ---"
for file in "$RUNNER" "$EVALS_FILE" "$PREDICTIONS_FILE"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

echo "--- Check 2: top-risk skill eval fixture scores perfect metrics ---"
if python3 "$RUNNER" \
  --evals "$EVALS_FILE" \
  --predictions "$PREDICTIONS_FILE" \
  --skills "$SKILLS" \
  --output-json "$OUTPUT_FILE"; then
  pass "skill eval runner executed successfully"
else
  fail "skill eval runner execution failed"
fi

if python3 - "$OUTPUT_FILE" <<'PY'
import json
import math
import sys

summary = json.load(open(sys.argv[1]))
for skill_name, metrics in summary["skills"].items():
    assert math.isclose(metrics["trigger_precision"], 1.0), f"{skill_name} trigger_precision != 1.0"
    assert math.isclose(metrics["false_trigger_rate"], 0.0), f"{skill_name} false_trigger_rate != 0.0"
    assert math.isclose(metrics["missed_trigger_rate"], 0.0), f"{skill_name} missed_trigger_rate != 0.0"
    assert math.isclose(metrics["quality_pass_rate"], 1.0), f"{skill_name} quality_pass_rate != 1.0"
print("Top-risk fixture metrics are perfect")
PY
then
  pass "top-risk fixture metrics are correct"
else
  fail "top-risk fixture metrics are incorrect"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Skill eval runner checks pass."
