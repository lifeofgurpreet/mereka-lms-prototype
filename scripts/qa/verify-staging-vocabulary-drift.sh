#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
# Prevent uncontrolled growth of staging references in scripts/.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ALLOWLIST_PATH="${STAGING_VOCAB_ALLOWLIST_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/staging-vocabulary-allowlist.json}"

python3 - "$REPO_ROOT" "$ALLOWLIST_PATH" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
allowlist_path = Path(sys.argv[2]).resolve()

failures = 0
passes = 0


def ok(message: str) -> None:
    global passes
    passes += 1
    print(f"PASS {message}")


def fail(message: str) -> None:
    global failures
    failures += 1
    print(f"FAIL {message}")


if not allowlist_path.exists():
    fail(f"allowlist missing: {allowlist_path}")
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
allowlist = payload.get("staging_reference_allowlist")
if not isinstance(allowlist, list) or any(not isinstance(item, str) or not item for item in allowlist):
    fail("staging_reference_allowlist must be a non-empty string list")
    raise SystemExit(1)
allow_set = set(allowlist)

staging_files: set[str] = set()
for path in (repo_root / "scripts").rglob("*"):
    if not path.is_file():
        continue
    if path.suffix not in {".sh", ".py"}:
        continue
    rel = str(path.relative_to(repo_root))
    if "/fixtures/" in rel or "/qa/deprecated/" in rel:
        continue
    if rel == "scripts/qa/verify-staging-vocabulary-drift.sh":
        continue
    if rel.startswith("scripts/qa/test-"):
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if re.search(r"\bstaging\b", text):
        staging_files.add(rel)

ok(f"detected {len(staging_files)} script(s) referencing 'staging'")

for path in sorted(staging_files):
    if path in allow_set:
        ok(f"allowlisted staging reference: {path}")
    else:
        fail(f"new staging reference is not allowlisted: {path}")

for path in sorted(allow_set):
    full = repo_root / path
    if not full.exists():
        fail(f"stale allowlist path (missing file): {path}")
        continue
    if path not in staging_files:
        fail(f"stale allowlist entry (no longer references 'staging'): {path}")

print(f"Summary: PASS={passes} FAIL={failures}")
if failures:
    raise SystemExit(1)
PY

echo "PASS staging vocabulary drift guard"
