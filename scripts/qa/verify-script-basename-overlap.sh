#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
# Enforce explicit contracts for duplicate script basenames.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3 is required" >&2
  exit 1
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCAN_ROOT="${SCRIPT_BASENAME_SCAN_ROOT:-$REPO_ROOT/scripts}"
ALLOWLIST_PATH="${SCRIPT_BASENAME_ALLOWLIST:-$REPO_ROOT/scripts/qa/fixtures/script-basename-overlap-allowlist.json}"

python3 - "$REPO_ROOT" "$SCAN_ROOT" "$ALLOWLIST_PATH" <<'PY'
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
scan_root = Path(sys.argv[2]).resolve()
allowlist_path = Path(sys.argv[3]).resolve()

failures = 0
passes = 0


def _display(path: Path) -> str:
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


if not scan_root.exists() or not scan_root.is_dir():
    fail(f"scan root missing or not a directory: {_display(scan_root)}")
if not allowlist_path.exists():
    fail(f"allowlist missing: {_display(allowlist_path)}")

if failures:
    raise SystemExit(1)

payload = json.loads(allowlist_path.read_text(encoding="utf-8"))
overlaps = payload.get("overlaps")
if not isinstance(overlaps, list):
    fail("allowlist payload must contain 'overlaps' array")
    raise SystemExit(1)

allowed: dict[str, dict] = {}
for idx, item in enumerate(overlaps):
    if not isinstance(item, dict):
        fail(f"overlaps[{idx}] must be an object")
        continue

    basename = item.get("basename")
    if not isinstance(basename, str) or not basename:
        fail(f"overlaps[{idx}] missing basename")
        continue
    if basename in allowed:
        fail(f"duplicate allowlist entry for basename: {basename}")
        continue

    paths = item.get("paths")
    if not isinstance(paths, list) or len(paths) < 2 or any(not isinstance(p, str) or not p for p in paths):
        fail(f"{basename}: paths must be a list of at least two non-empty strings")
        continue

    if len(set(paths)) != len(paths):
        fail(f"{basename}: paths contain duplicates")
        continue

    path_basenames = {Path(path).name for path in paths}
    if path_basenames != {basename}:
        fail(f"{basename}: every listed path must end with basename {basename}")
        continue

    contract_type = item.get("contract_type")
    if contract_type not in {"wrapper", "peer_set"}:
        fail(f"{basename}: contract_type must be wrapper or peer_set")
        continue

    if contract_type == "wrapper":
        canonical = item.get("canonical")
        wrappers = item.get("wrappers")
        if not isinstance(canonical, str) or not canonical:
            fail(f"{basename}: wrapper contract requires canonical path")
            continue
        if canonical not in paths:
            fail(f"{basename}: canonical path must be present in paths")
            continue
        if not isinstance(wrappers, list) or any(not isinstance(w, str) or not w for w in wrappers):
            fail(f"{basename}: wrapper contract requires wrappers list")
            continue
        if sorted(set(wrappers)) != sorted([p for p in paths if p != canonical]):
            fail(f"{basename}: wrappers must exactly match paths excluding canonical")
            continue
    else:
        if "canonical" in item and item.get("canonical"):
            fail(f"{basename}: peer_set contract must not define canonical")
            continue

    missing_paths = [path for path in paths if not (repo_root / path).is_file()]
    if missing_paths:
        fail(f"{basename}: allowlist paths missing on disk: {', '.join(sorted(missing_paths))}")
        continue

    allowed[basename] = {
        "contract_type": contract_type,
        "paths": sorted(paths),
    }

if failures:
    raise SystemExit(1)

clusters: dict[str, list[str]] = defaultdict(list)
for path in scan_root.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix not in {".sh", ".py"}:
        continue
    try:
        rel = str(path.relative_to(repo_root))
    except ValueError:
        rel = str(path)
    clusters[path.name].append(rel)

duplicates = {name: sorted(paths) for name, paths in clusters.items() if len(paths) > 1}
ok(f"detected {len(duplicates)} duplicate basename cluster(s)")

for basename, paths in sorted(duplicates.items()):
    entry = allowed.get(basename)
    if entry is None:
        fail(f"{basename}: duplicate basename has no allowlist contract")
        continue
    if paths != entry["paths"]:
        fail(
            f"{basename}: duplicate paths drifted from allowlist. "
            f"expected={entry['paths']} actual={paths}"
        )
    else:
        ok(f"{basename}: duplicate contract matches allowlist ({entry['contract_type']})")

for basename in sorted(allowed):
    if basename not in duplicates:
        fail(f"{basename}: stale allowlist entry (basename no longer duplicated)")

print(f"Summary: PASS={passes} FAIL={failures}")
if failures:
    raise SystemExit(1)
PY

echo "PASS script basename overlap contracts"
