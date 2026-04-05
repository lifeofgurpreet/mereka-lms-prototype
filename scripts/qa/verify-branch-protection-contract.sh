#!/usr/bin/env bash
# @covers AC-CI-015
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/branch-protection-contract.yaml"
LIVE_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live)
      LIVE_MODE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Branch Protection Contract Verification ==="
echo "Repo root: $REPO_ROOT"
echo "Live mode: $LIVE_MODE"

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

if python3 - "$CONTRACT_FILE" <<'PY'
import sys
import yaml

contract = yaml.safe_load(open(sys.argv[1]))
repos = contract.get("repos", [])
assert repos, "no repos defined"
for row in repos:
    for field in (
        "repo",
        "branch",
        "enforce_admins",
        "required_approving_review_count",
        "dismiss_stale_reviews",
        "required_conversation_resolution",
        "strict_status_checks",
        "required_status_checks",
        "allow_force_pushes",
        "allow_deletions",
    ):
        assert field in row, f"missing {field} in {row.get('repo', '<unknown>')}"
        if field == "required_status_checks":
            assert isinstance(row[field], list) and row[field], f"required_status_checks must be non-empty for {row['repo']}"
print(f"Validated {len(repos)} branch-protection contract rows")
PY
then
  pass "branch-protection contract has required fields"
else
  fail "branch-protection contract is missing required fields"
fi

if [[ "$LIVE_MODE" -eq 1 ]]; then
  echo "--- Check 2: live GitHub branch protection matches contract ---"
  if python3 - "$CONTRACT_FILE" <<'PY'
import json
import subprocess
import sys

import yaml

contract = yaml.safe_load(open(sys.argv[1]))
failures = []

for row in contract.get("repos", []):
    repo = row["repo"]
    branch = row["branch"]
    try:
        raw = subprocess.check_output(
            ["gh", "api", f"repos/{repo}/branches/{branch}/protection"],
            text=True,
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as exc:
        failures.append(f"{repo}: failed to query branch protection ({exc.output.strip()})")
        continue

    live = json.loads(raw)
    checks = live.get("required_status_checks") or {}
    reviews = live.get("required_pull_request_reviews") or {}
    comparisons = {
        "enforce_admins": bool((live.get("enforce_admins") or {}).get("enabled")),
        "required_approving_review_count": int(reviews.get("required_approving_review_count") or 0),
        "dismiss_stale_reviews": bool(reviews.get("dismiss_stale_reviews", False)),
        "required_conversation_resolution": bool((live.get("required_conversation_resolution") or {}).get("enabled")),
        "strict_status_checks": bool(checks.get("strict")),
        "allow_force_pushes": bool((live.get("allow_force_pushes") or {}).get("enabled")),
        "allow_deletions": bool((live.get("allow_deletions") or {}).get("enabled")),
    }
    for field, actual in comparisons.items():
        expected = row[field]
        if actual != expected:
            failures.append(f"{repo}: {field} expected {expected!r} but got {actual!r}")

    actual_contexts = sorted(checks.get("contexts") or [])
    expected_contexts = sorted(row["required_status_checks"])
    if actual_contexts != expected_contexts:
        failures.append(
            f"{repo}: required_status_checks expected {expected_contexts!r} but got {actual_contexts!r}"
        )

if failures:
    for failure in failures:
        print(failure)
    raise SystemExit(1)

print("Live branch protection matches contract")
PY
  then
    pass "live GitHub branch protection matches contract"
  else
    fail "live GitHub branch protection does not match contract"
  fi
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Branch protection contract checks pass."
