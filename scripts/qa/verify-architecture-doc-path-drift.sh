#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
# Prevent uncontrolled growth of legacy docs/architecture path references in scripts.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ALLOWLIST_PATH="${ARCH_DOC_PATH_ALLOWLIST_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/architecture-doc-path-allowlist.json}"
STRICT_STALE="${STRICT_STALE:-0}"

python3 - "$REPO_ROOT" "$ALLOWLIST_PATH" "$STRICT_STALE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
allowlist_path = Path(sys.argv[2]).resolve()
strict_stale = sys.argv[3] == "1"

failures = 0
passes = 0
warns = 0


def ok(message: str) -> None:
    global passes
    passes += 1
    print(f"PASS {message}")


def fail(message: str) -> None:
    global failures
    failures += 1
    print(f"FAIL {message}")


def warn(message: str) -> None:
    global warns
    warns += 1
    print(f"WARN {message}")


if not allowlist_path.exists():
    fail(f"allowlist missing: {allowlist_path}")
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
allowlist = payload.get("legacy_docs_architecture_reference_allowlist")
if not isinstance(allowlist, list) or any(not isinstance(item, str) or not item for item in allowlist):
    fail("legacy_docs_architecture_reference_allowlist must be a non-empty string list")
    raise SystemExit(1)
allow_set = set(allowlist)

hits: set[str] = set()
for path in (repo_root / "scripts").rglob("*"):
    if not path.is_file():
        continue
    if path.suffix not in {".sh", ".py"}:
        continue
    rel = str(path.relative_to(repo_root))
    if "/deprecated/" in rel or "/fixtures/" in rel:
        continue
    if rel == "scripts/qa/verify-architecture-doc-path-drift.sh":
        continue
    if rel.startswith("scripts/qa/test-"):
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "docs/architecture/" in text:
        hits.add(rel)

ok(f"detected {len(hits)} script(s) with legacy docs/architecture references")

for path in sorted(hits):
    if path in allow_set:
        ok(f"allowlisted legacy docs path reference: {path}")
    else:
        fail(f"new legacy docs/architecture reference is not allowlisted: {path}")

for path in sorted(allow_set):
    full = repo_root / path
    if not full.exists():
        fail(f"stale allowlist path (missing file): {path}")
        continue
    text = full.read_text(encoding="utf-8", errors="ignore")
    if "docs/architecture/" not in text:
        message = f"stale allowlist entry (no legacy docs path reference): {path}"
        if strict_stale:
            fail(message)
        else:
            warn(message)

print(f"Summary: PASS={passes} FAIL={failures} WARN={warns}")
if failures:
    raise SystemExit(1)
PY

echo "PASS architecture doc path drift guard"
