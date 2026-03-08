#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
#
# Guardrail: keep tracked evidence payload growth explicit and reviewed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUDGET_JSON="$REPO_ROOT/verification/manifests/evidence_sprawl_budget.json"

if [[ ! -f "$BUDGET_JSON" ]]; then
  echo "FAIL evidence budget missing: $BUDGET_JSON" >&2
  exit 1
fi

python3 - "$REPO_ROOT" "$BUDGET_JSON" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
budget_path = Path(sys.argv[2])
budget = json.loads(budget_path.read_text(encoding="utf-8"))

max_files = int(budget.get("tracked_evidence_max_files", 0))
max_bytes = int(budget.get("tracked_evidence_max_bytes", 0))
archive_max_files = int(budget.get("tracked_archive_reports_max_files", 0))
archive_max_bytes = int(budget.get("tracked_archive_reports_max_bytes", 0))

tracked = subprocess.check_output(
    [
        "git",
        "ls-files",
        "docs/operations/evidence",
        "docs/evidence/observability",
        "docs/archive/evidence/observability",
    ],
    cwd=repo_root,
    text=True,
).splitlines()

archive_tracked = subprocess.check_output(
    [
        "git",
        "ls-files",
        "docs/archive/reports",
    ],
    cwd=repo_root,
    text=True,
).splitlines()

tracked_files = len(tracked)
tracked_bytes = 0
for rel in tracked:
    p = repo_root / rel
    if p.is_file():
        tracked_bytes += p.stat().st_size

archive_tracked_files = len(archive_tracked)
archive_tracked_bytes = 0
for rel in archive_tracked:
    p = repo_root / rel
    if p.is_file():
        archive_tracked_bytes += p.stat().st_size

failed = 0
passed = 0

def ok(msg: str) -> None:
    global passed
    passed += 1
    print(f"PASS {msg}")

def fail(msg: str) -> None:
    global failed
    failed += 1
    print(f"FAIL {msg}")

if tracked_files <= max_files:
    ok(f"tracked evidence file count {tracked_files} <= budget {max_files}")
else:
    fail(f"tracked evidence file count {tracked_files} exceeds budget {max_files}")

if tracked_bytes <= max_bytes:
    ok(f"tracked evidence bytes {tracked_bytes} <= budget {max_bytes}")
else:
    fail(f"tracked evidence bytes {tracked_bytes} exceeds budget {max_bytes}")

if archive_tracked_files <= archive_max_files:
    ok(
        "tracked archive report files "
        f"{archive_tracked_files} <= budget {archive_max_files}"
    )
else:
    fail(
        "tracked archive report files "
        f"{archive_tracked_files} exceeds budget {archive_max_files}"
    )

if archive_tracked_bytes <= archive_max_bytes:
    ok(
        "tracked archive report bytes "
        f"{archive_tracked_bytes} <= budget {archive_max_bytes}"
    )
else:
    fail(
        "tracked archive report bytes "
        f"{archive_tracked_bytes} exceeds budget {archive_max_bytes}"
    )

print(f"Summary: PASS={passed} FAIL={failed}")
if failed:
    print("")
    print(
        "Evidence sprawl budget exceeded. Move raw artifacts to CI/object storage "
        "or update budget file with explicit review rationale."
    )
    raise SystemExit(1)
PY

echo "PASS evidence sprawl budget"
