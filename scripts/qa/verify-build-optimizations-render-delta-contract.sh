#!/usr/bin/env bash
# @covers AC-CI-ONBOARDING-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify that post-render Tutor Dockerfile mutations remain bounded:
# raw Tutor render -> explicit allowed delta -> artifact.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="${BUILD_OPTIMIZATIONS_DELTA_CONTRACT:-$REPO_ROOT/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml}"
PATCH_SCRIPT="${BUILD_OPTIMIZATIONS_SCRIPT:-$REPO_ROOT/infrastructure/tutor/patches/build-optimizations.sh}"
INVENTORY_DOC="${PATCH_INVENTORY_DOC:-$REPO_ROOT/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md}"

python3 - <<'PY' "$CONTRACT" "$PATCH_SCRIPT" "$INVENTORY_DOC" "${RAW_RENDER_FILE:-}" "${PATCHED_RENDER_FILE:-}"
from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required for build optimization delta contract verification") from exc

contract_path = Path(sys.argv[1])
patch_script_path = Path(sys.argv[2])
inventory_doc_path = Path(sys.argv[3])
raw_render = Path(sys.argv[4]) if sys.argv[4] else None
patched_render = Path(sys.argv[5]) if sys.argv[5] else None

allowed_classes = {
    "authority_correction",
    "obsolete_expectation_removal",
    "temporary_compatibility_layer",
    "intentional_architecture_change",
}

failures: list[str] = []

if not contract_path.is_file():
    raise SystemExit(f"missing delta contract: {contract_path}")
if not patch_script_path.is_file():
    raise SystemExit(f"missing build optimization patch script: {patch_script_path}")
if not inventory_doc_path.is_file():
    raise SystemExit(f"missing patch inventory doc: {inventory_doc_path}")

payload = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
if not isinstance(payload, dict):
    raise SystemExit(f"{contract_path} must load as a mapping")

if payload.get("default_policy") != "fail_closed":
    failures.append("contract default_policy must be fail_closed")
if not payload.get("review_date"):
    failures.append("contract must carry review_date")

deltas = payload.get("allowed_deltas")
if not isinstance(deltas, list) or not deltas:
    failures.append("contract must contain non-empty allowed_deltas")
    deltas = []

inventory_text = inventory_doc_path.read_text(encoding="utf-8")
ids: set[str] = set()
added_patterns: list[re.Pattern[str]] = []
removed_patterns: list[re.Pattern[str]] = []
source_text_cache: dict[Path, str] = {}


def source_text_for(path: Path) -> str:
    resolved = path.resolve()
    if resolved not in source_text_cache:
        if not resolved.is_file():
            failures.append(f"missing delta source script: {path}")
            source_text_cache[resolved] = ""
        else:
            source_text_cache[resolved] = resolved.read_text(encoding="utf-8")
    return source_text_cache[resolved]

for index, delta in enumerate(deltas, start=1):
    if not isinstance(delta, dict):
        failures.append(f"allowed_deltas[{index}] must be a mapping")
        continue
    delta_id = str(delta.get("id") or "")
    if not delta_id:
        failures.append(f"allowed_deltas[{index}] missing id")
    elif delta_id in ids:
        failures.append(f"duplicate delta id: {delta_id}")
    else:
        ids.add(delta_id)
    if delta_id and delta_id not in inventory_text:
        failures.append(f"{delta_id} missing from {inventory_doc_path}")
    authority_class = str(delta.get("authority_class") or "")
    if authority_class not in allowed_classes:
        failures.append(f"{delta_id}: invalid authority_class {authority_class!r}")
    if not str(delta.get("retirement_trigger") or "").strip():
        failures.append(f"{delta_id}: missing retirement_trigger")
    delta_source_value = delta.get("source_script")
    if delta_source_value is None:
        delta_source_path = patch_script_path
    elif isinstance(delta_source_value, str) and delta_source_value.strip():
        delta_source_path = Path(delta_source_value)
        if not delta_source_path.is_absolute():
            delta_source_path = Path.cwd() / delta_source_path
    else:
        failures.append(f"{delta_id}: source_script must be a non-empty string when present")
        delta_source_path = patch_script_path

    delta_source_text = source_text_for(delta_source_path)
    markers = delta.get("source_markers") or []
    if not isinstance(markers, list) or not markers:
        failures.append(f"{delta_id}: missing source_markers")
    for marker in markers:
        if not isinstance(marker, str) or marker not in delta_source_text:
            failures.append(
                f"{delta_id}: source marker missing from {delta_source_path}: {marker!r}"
            )
    for field, target in (("added_patterns", added_patterns), ("removed_patterns", removed_patterns)):
        patterns = delta.get(field) or []
        if not isinstance(patterns, list):
            failures.append(f"{delta_id}: {field} must be a list")
            continue
        for pattern in patterns:
            if not isinstance(pattern, str) or not pattern:
                failures.append(f"{delta_id}: empty/non-string {field} entry")
                continue
            try:
                target.append(re.compile(pattern))
            except re.error as exc:
                failures.append(f"{delta_id}: invalid regex {pattern!r}: {exc}")


def line_allowed(line: str, patterns: list[re.Pattern[str]]) -> bool:
    stripped = line.rstrip("\n")
    if not stripped:
        return True
    return any(pattern.search(stripped) for pattern in patterns)


if raw_render or patched_render:
    if not raw_render or not patched_render:
        failures.append("RAW_RENDER_FILE and PATCHED_RENDER_FILE must be provided together")
    elif not raw_render.is_file() or not patched_render.is_file():
        failures.append("RAW_RENDER_FILE and PATCHED_RENDER_FILE must both exist")
    else:
        raw_lines = raw_render.read_text(encoding="utf-8").splitlines(keepends=True)
        patched_lines = patched_render.read_text(encoding="utf-8").splitlines(keepends=True)
        for line in difflib.unified_diff(raw_lines, patched_lines, fromfile="raw", tofile="patched"):
            if line.startswith(("+++", "---", "@@")):
                continue
            if line.startswith("+") and not line_allowed(line[1:], added_patterns):
                failures.append(f"unexpected added render delta: {line[1:].rstrip()}")
            if line.startswith("-") and not line_allowed(line[1:], removed_patterns):
                failures.append(f"unexpected removed render delta: {line[1:].rstrip()}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

mode = "contract+diff" if raw_render and patched_render else "contract"
print(f"PASS: build-optimizations render delta {mode} is bounded")
PY
