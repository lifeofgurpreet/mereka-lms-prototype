#!/usr/bin/env bash
# Enforce that mutating scripts under scripts/qa are explicitly allowlisted.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ALLOWLIST_PATH="${QA_READONLY_ALLOWLIST_OVERRIDE:-$REPO_ROOT/scripts/qa/fixtures/qa-mutating-scripts-allowlist.json}"

python3 - "$REPO_ROOT" "$ALLOWLIST_PATH" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
allowlist_path = Path(sys.argv[2]).resolve()

mutating_prefixes = (
    "fix-",
    "repair-",
    "cleanup-",
    "prune-",
    "retire-",
    "park-",
    "unpark-",
    "sync-",
    "apply-",
    "create-",
    "provision-",
    "bootstrap-",
    "rollback-",
    "load-",
)
mutating_command_re = re.compile(
    r"\b("
    r"kubectl\s+(apply|delete|patch|replace|scale|set\s+image|rollout\s+restart)"
    r"|terraform\s+apply"
    r"|helm\s+(upgrade|install|uninstall|delete)"
    r"|argocd\s+app\s+sync"
    r"|velero\s+restore\s+create"
    r")\b"
)

failures = 0
passes = 0


def rel(path: Path) -> str:
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


if not (repo_root / "scripts/qa").exists():
    fail("scripts/qa missing")
if not allowlist_path.exists():
    fail(f"allowlist missing: {rel(allowlist_path)}")
if failures:
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
entries = payload.get("allowed_scripts")
if not isinstance(entries, list):
    fail("allowed_scripts must be a list")
    raise SystemExit(1)

allowlist: dict[str, str] = {}
for entry in entries:
    if not isinstance(entry, dict):
        fail("allowed_scripts entries must be objects")
        continue
    path = entry.get("path")
    reason = entry.get("reason")
    if not isinstance(path, str) or not path:
        fail("allowed_scripts.path must be a non-empty string")
        continue
    if not isinstance(reason, str) or not reason.strip():
        fail(f"allowlist entry missing reason: {path}")
        continue
    allowlist[path] = reason.strip()

mutating: dict[str, list[str]] = {}
for script_path in sorted((repo_root / "scripts/qa").rglob("*.sh")):
    rel_path = rel(script_path)
    if "/deprecated/" in rel_path:
        continue
    if script_path.name.startswith("test-"):
        continue
    content = script_path.read_text(encoding="utf-8", errors="ignore")
    reasons: list[str] = []
    if script_path.name.startswith(mutating_prefixes):
        reasons.append("mutating_prefix")
    if mutating_command_re.search(content):
        reasons.append("mutating_command")
    if reasons:
        mutating[rel_path] = reasons

ok(f"discovered {len(mutating)} mutating qa script(s)")

for path, reasons in sorted(mutating.items()):
    if path in allowlist:
        ok(f"allowlisted mutating qa script: {path} ({','.join(reasons)})")
    else:
        fail(f"mutating qa script is not allowlisted: {path} ({','.join(reasons)})")

for path in sorted(allowlist):
    script_path = repo_root / path
    if not script_path.exists():
        fail(f"allowlist entry path missing: {path}")
    elif path not in mutating:
        fail(f"stale allowlist entry (script no longer mutating by contract): {path}")

print(f"Summary: PASS={passes} FAIL={failures}")
if failures:
    raise SystemExit(1)
PY

echo "PASS qa readonly contract"
