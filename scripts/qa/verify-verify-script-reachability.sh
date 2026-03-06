#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
# Enforce reachability freeze for scripts/qa/verify-*.sh.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ALLOWLIST_PATH="${VERIFY_REACHABILITY_ALLOWLIST_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/verify-script-reachability-allowlist.json}"

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


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


if not allowlist_path.exists():
    fail(f"allowlist missing: {rel(allowlist_path)}")
if not (repo_root / ".github/ci-scripts-static.txt").exists():
    fail("ci script list missing: .github/ci-scripts-static.txt")
if not (repo_root / "scripts/qa").exists():
    fail("scripts/qa missing")

if failures:
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
manual_allow = payload.get("manual_only_verify_allowlist")
if not isinstance(manual_allow, list) or any(not isinstance(item, str) or not item for item in manual_allow):
    fail("manual_only_verify_allowlist must be a non-empty string list")
    raise SystemExit(1)
manual_allow_set = set(manual_allow)

verify_scripts: set[str] = set()
for path in (repo_root / "scripts/qa").rglob("verify-*.sh"):
    if "deprecated" in path.parts:
        continue
    verify_scripts.add(rel(path))
ok(f"discovered {len(verify_scripts)} non-deprecated qa verify script(s)")

ci_static: set[str] = set()
for raw in (repo_root / ".github/ci-scripts-static.txt").read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    ci_static.add(line.split()[0])

reference_text = ""
for path in [
    repo_root / "scripts/qa/run-release-verification-gates.sh",
    repo_root / "scripts/qa/run-operations-gates.sh",
    repo_root / "scripts/qa/run-multisite-governance-gates.sh",
]:
    if path.exists():
        reference_text += path.read_text(encoding="utf-8", errors="ignore") + "\n"
for workflow in (repo_root / ".github/workflows").glob("*.y*ml"):
    reference_text += workflow.read_text(encoding="utf-8", errors="ignore") + "\n"

ref_pattern = re.compile(r"scripts/qa/verify-[A-Za-z0-9_./-]+\.sh")
direct_refs = set(ref_pattern.findall(reference_text))

reachable = {path for path in verify_scripts if path in ci_static or path in direct_refs}
manual_only = sorted(verify_scripts - reachable)

ok(f"reachable verify scripts: {len(reachable)}")
ok(f"manual-only verify scripts: {len(manual_only)}")

for path in manual_only:
    if path in manual_allow_set:
        ok(f"manual-only allowlisted: {path}")
    else:
        fail(f"new manual-only verify script is not allowlisted: {path}")

for path in sorted(manual_allow_set):
    if path not in verify_scripts:
        fail(f"allowlist entry is not an existing verify script: {path}")
    elif path not in manual_only:
        fail(f"stale allowlist entry (script is now reachable): {path}")

print(f"Summary: PASS={passes} FAIL={failures}")
if failures:
    raise SystemExit(1)
PY

echo "PASS verify script reachability contract"
