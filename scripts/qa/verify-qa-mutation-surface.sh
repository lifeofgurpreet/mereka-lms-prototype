#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
# Keep scripts/qa surface read-mostly: mutating prefixes must be explicitly allowlisted.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QA_SCAN_ROOT="${QA_SCAN_ROOT_OVERRIDE:-$REPO_ROOT/scripts/qa}"
ALLOWLIST_PATH="${QA_MUTATION_ALLOWLIST_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/qa-mutating-scripts-allowlist.json}"

python3 - "$REPO_ROOT" "$QA_SCAN_ROOT" "$ALLOWLIST_PATH" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
qa_root = Path(sys.argv[2]).resolve()
allowlist_path = Path(sys.argv[3]).resolve()

failures = 0
passes = 0


def rel_display(path: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def ok(message: str) -> None:
    global passes
    passes += 1
    print(f"PASS {message}")


def fail(message: str) -> None:
    global failures
    failures += 1
    print(f"FAIL {message}")


if not qa_root.exists() or not qa_root.is_dir():
    fail(f"qa scan root missing or not a directory: {rel_display(qa_root)}")
if not allowlist_path.exists():
    fail(f"allowlist missing: {rel_display(allowlist_path)}")

if failures:
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
prefixes = payload.get("mutating_prefixes")
entries = payload.get("allowed_scripts")

if not isinstance(prefixes, list) or any(not isinstance(p, str) or not p for p in prefixes):
    fail("allowlist mutating_prefixes must be a non-empty string array")
if not isinstance(entries, list):
    fail("allowlist allowed_scripts must be an array")
if failures:
    raise SystemExit(1)

allowlisted_paths: set[str] = set()
for idx, entry in enumerate(entries):
    if not isinstance(entry, dict):
        fail(f"allowed_scripts[{idx}] must be an object")
        continue
    path = entry.get("path")
    if not isinstance(path, str) or not path:
        fail(f"allowed_scripts[{idx}] missing path")
        continue
    if path in allowlisted_paths:
        fail(f"duplicate allowlist path: {path}")
        continue
    if not path.endswith(".sh"):
        fail(f"allowlist path must target shell script: {path}")
        continue
    allowlisted_paths.add(path)

discovered_mutating: set[str] = set()
for script in qa_root.rglob("*.sh"):
    name = script.name
    if not any(name.startswith(prefix) for prefix in prefixes):
        continue
    rel = rel_display(script)
    discovered_mutating.add(rel)

ok(f"discovered {len(discovered_mutating)} qa mutating-prefix script(s)")

for path in sorted(discovered_mutating):
    if path in allowlisted_paths:
        ok(f"allowlisted mutating qa script: {path}")
    else:
        fail(f"mutating qa script not allowlisted: {path}")

for path in sorted(allowlisted_paths):
    if path not in discovered_mutating:
        script_file = repo_root / path
        if not script_file.exists():
            fail(f"stale allowlist entry (script missing or renamed): {path}")
        # else: script exists but uses mutating commands (not prefix) — valid for readonly contract

print(f"Summary: PASS={passes} FAIL={failures}")
if failures:
    raise SystemExit(1)
PY

echo "PASS qa mutation surface contract"
