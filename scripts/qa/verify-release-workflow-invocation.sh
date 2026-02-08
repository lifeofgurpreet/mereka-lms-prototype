#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

echo "Checking release workflow invocations..."

python3 - "$WORKFLOWS_DIR" <<'PY'
import sys
from pathlib import Path

import yaml

workflows_dir = Path(sys.argv[1])
required_flags = [
    "--target-env",
    "--openedx-tag",
    "--mfe-tag",
    "--apply",
    "--commit",
    "--push",
]

violations = []
invocations = 0

for wf_path in sorted(workflows_dir.glob("*.y*ml")):
    try:
        data = yaml.safe_load(wf_path.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        violations.append(f"{wf_path.name}: YAML parse error: {exc}")
        continue

    jobs = data.get("jobs") or {}
    for job_name, job in jobs.items():
        steps = (job or {}).get("steps") or []
        for idx, step in enumerate(steps, start=1):
            run = (step or {}).get("run")
            if not isinstance(run, str):
                continue
            if "./scripts/infra/release-openedx-gitops.sh" not in run:
                continue

            invocations += 1
            missing = [flag for flag in required_flags if flag not in run]
            if missing:
                step_name = (step or {}).get("name", f"step#{idx}")
                violations.append(
                    f"{wf_path.name}::{job_name}::{step_name} missing flags: {', '.join(missing)}"
                )

if invocations == 0:
    violations.append("No workflow step invokes ./scripts/infra/release-openedx-gitops.sh")

if violations:
    print("❌ Release workflow invocation contract failed.")
    for v in violations:
        print(f"  - {v}")
    sys.exit(1)

print("✅ Release workflow invocation contract passed.")
PY
