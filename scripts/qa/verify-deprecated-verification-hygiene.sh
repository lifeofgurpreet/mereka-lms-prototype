#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$REPO_ROOT/verification/manifests/deprecated_verify_scripts.json"
CI_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

if [[ ! -f "$MANIFEST" ]]; then
  echo "FAIL deprecated manifest missing: $MANIFEST" >&2
  exit 1
fi

python3 - "$MANIFEST" "$CI_LIST" "$WORKFLOWS_DIR" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
ci_list_path = Path(sys.argv[2])
workflows_dir = Path(sys.argv[3])

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
scripts = manifest.get("scripts", [])

if not scripts:
    print("FAIL deprecated manifest has no scripts")
    raise SystemExit(1)

ci_text = ci_list_path.read_text(encoding="utf-8", errors="ignore")
workflow_text = "\n".join(
    p.read_text(encoding="utf-8", errors="ignore")
    for p in workflows_dir.glob("*.y*ml")
)

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

for entry in scripts:
    path = entry.get("path", "")
    replacement = entry.get("replacement_entrypoint", "")
    reason = entry.get("reason", "")
    rel = Path(path)
    abs_path = Path.cwd() / rel

    if not path.startswith("scripts/qa/deprecated/verify-"):
        fail(f"{path}: must live under scripts/qa/deprecated/")
    else:
        ok(f"{path}: location is deprecated namespace")

    if not abs_path.exists():
        fail(f"{path}: archived script missing from repository")
    else:
        ok(f"{path}: archived script file exists")

    if path in ci_text:
        fail(f"{path}: must not be listed in .github/ci-scripts-static.txt")
    else:
        ok(f"{path}: not present in CI static script list")

    if path in workflow_text:
        fail(f"{path}: must not be called directly from workflows")
    else:
        ok(f"{path}: not referenced by workflows")

    if not replacement.startswith("scripts/qa/run-"):
        fail(f"{path}: replacement_entrypoint must be canonical run-* gate")
    else:
        ok(f"{path}: replacement entrypoint declared ({replacement})")

    if not reason.strip():
        fail(f"{path}: reason is required")
    else:
        ok(f"{path}: reason present")

print(f"Summary: PASS={passed} FAIL={failed}")
if failed:
    raise SystemExit(1)
PY

echo "PASS deprecated verification hygiene contract"
