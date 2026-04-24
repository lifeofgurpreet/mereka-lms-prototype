#!/usr/bin/env bash
# @covers AC-014
# @spec: ci-cd-pipeline_spec.md
# Verify every direct GitHub Actions job has an explicit timeout-minutes value.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOWS_DIR="${ROOT}/.github/workflows"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is required for workflow timeout verification." >&2
  exit 1
fi

python3 - "$WORKFLOWS_DIR" <<'PY'
import sys
from pathlib import Path

import yaml

workflows_dir = Path(sys.argv[1])
violations = []
checked = 0

for path in sorted(workflows_dir.glob("*.yml")) + sorted(workflows_dir.glob("*.yaml")):
    with path.open() as fh:
        data = yaml.safe_load(fh) or {}
    jobs = data.get("jobs") or {}
    if not isinstance(jobs, dict):
        continue

    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            continue
        if "uses" in job:
            # Reusable-workflow proxy jobs inherit timeout behavior from the
            # called workflow contract; only direct jobs are enforced here.
            continue
        checked += 1
        timeout = job.get("timeout-minutes")
        if timeout is None:
            violations.append(f"{path.relative_to(Path.cwd())}:{job_name} missing timeout-minutes")
            continue
        if not isinstance(timeout, int) or timeout <= 0:
            violations.append(
                f"{path.relative_to(Path.cwd())}:{job_name} timeout-minutes must be a positive integer"
            )

print("=== Workflow Timeout Verification ===")
print(f"Direct jobs checked: {checked}")

if violations:
    print("FAIL: direct workflow jobs without valid timeout-minutes:")
    for item in violations:
        print(f"  {item}")
    sys.exit(1)

print("PASS: every direct workflow job has an explicit timeout-minutes value.")
PY
