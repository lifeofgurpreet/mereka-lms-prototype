#!/usr/bin/env python3
"""convert_testmap.py — Convert testmaps from Format A/C to canonical Format B.

Format A: top-level 'tests:' with flat criterion/test_file/type entries
Format C: 'acceptance_criteria:' with flat test_file/command (no verify blocks)
Format B: 'acceptance_criteria:' with nested 'verify:' blocks (canonical)

Usage:
  python3 convert_testmap.py specs/testmaps/foo_testmap.yaml
  python3 convert_testmap.py --all specs/testmaps/
  python3 convert_testmap.py --dry-run specs/testmaps/foo_testmap.yaml
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")

AC_ID_RE = re.compile(r"\bAC-(\d{3,})\b")
EC_ID_RE = re.compile(r"\bEC-(\d+)\b")


def detect_format(data: dict) -> str:
    """Detect testmap format: A, B, or C."""
    if "tests" in data:
        return "A"
    ac = data.get("acceptance_criteria")
    if not isinstance(ac, list) or not ac:
        return "unknown"
    first = ac[0] if ac else {}
    if isinstance(first, dict) and "verify" in first:
        return "B"
    if isinstance(first, dict) and ("test_file" in first or "command" in first or "test_type" in first):
        return "C"
    # Has acceptance_criteria with id + verify = B
    if isinstance(first, dict) and "id" in first:
        return "B"
    return "unknown"


def extract_ac_id(criterion: str) -> str:
    """Extract AC-NNN or EC-N from a criterion string."""
    m = AC_ID_RE.search(criterion)
    if m:
        return f"AC-{m.group(1)}"
    m = EC_ID_RE.search(criterion)
    if m:
        return f"EC-{m.group(1)}"
    return ""


def make_description(criterion: str, ac_id: str) -> str:
    """Create a short description from a criterion string."""
    # Remove the AC-NNN: prefix if present
    desc = criterion
    if ac_id and ":" in desc:
        idx = desc.find(":")
        after = desc[idx + 1:].strip()
        if after:
            desc = after
    # Truncate to reasonable length
    if len(desc) > 120:
        desc = desc[:117] + "..."
    return desc


def convert_format_a(data: dict) -> dict:
    """Convert Format A (tests: list) to Format B (acceptance_criteria: with verify:)."""
    result: dict[str, Any] = {}

    # Preserve metadata
    if "spec" in data:
        result["spec"] = data["spec"]
    for key in ("plan", "testplan", "tier"):
        if key in data:
            result[key] = data[key]

    tests = data.get("tests", [])
    if not isinstance(tests, list):
        result["acceptance_criteria"] = []
        return result

    # Group tests by AC ID
    ac_groups: dict[str, list] = {}
    ungrouped: list = []

    for entry in tests:
        if not isinstance(entry, dict):
            continue
        criterion = entry.get("criterion", "")
        ac_id = extract_ac_id(criterion)
        if ac_id:
            ac_groups.setdefault(ac_id, []).append(entry)
        else:
            ungrouped.append(entry)

    ac_list = []
    # Process grouped entries
    for ac_id in sorted(ac_groups.keys(), key=_sort_ac_key):
        entries = ac_groups[ac_id]
        first_criterion = entries[0].get("criterion", "")
        description = make_description(first_criterion, ac_id)

        verify = []
        for entry in entries:
            ve = _entry_to_verify(entry)
            verify.append(ve)

        item: dict[str, Any] = {
            "id": ac_id,
            "description": description,
            "verify": verify,
        }
        ac_list.append(item)

    # Process ungrouped as standalone entries (edge cases, load tests, etc.)
    for entry in ungrouped:
        criterion = entry.get("criterion", "")
        # Generate a synthetic ID from the criterion
        desc = criterion[:120] if criterion else "Unmapped test"
        ve = _entry_to_verify(entry)
        item = {
            "id": f"UNGROUPED-{len(ac_list) + 1}",
            "description": desc,
            "verify": [ve],
        }
        ac_list.append(item)

    result["acceptance_criteria"] = ac_list
    return result


def convert_format_c(data: dict) -> dict:
    """Convert Format C (flat acceptance_criteria without verify blocks) to Format B."""
    result: dict[str, Any] = {}

    # Preserve metadata
    for key in ("spec", "plan", "testplan", "tier"):
        if key in data:
            result[key] = data[key]

    ac_list_in = data.get("acceptance_criteria", [])
    ac_list_out = []
    # Also handle edge_case_tests if present
    extra_items = data.get("edge_case_tests", [])

    for item in ac_list_in:
        if not isinstance(item, dict):
            continue
        new_item: dict[str, Any] = {
            "id": str(item.get("id", "UNKNOWN")),
        }
        if "description" in item:
            new_item["description"] = item["description"]

        # Build verify entry from flat fields
        ve: dict[str, Any] = {}
        is_automated = item.get("automated", True)
        test_file = item.get("test_file", "")
        command = item.get("command", "")
        test_type = item.get("test_type", "")

        if is_automated and (test_file or command):
            ve["type"] = "automated"
            if test_type:
                ve["test_type"] = test_type
            if test_file:
                ve["file"] = test_file
            if command:
                ve["command"] = command
        elif not is_automated:
            ve["type"] = "manual"
            if item.get("justification"):
                ve["justification"] = item["justification"]
            if item.get("runbook"):
                ve["runbook"] = item["runbook"]
            if item.get("section"):
                ve["section"] = item["section"]
        else:
            ve["type"] = "automated"
            if test_type:
                ve["test_type"] = test_type

        if item.get("notes"):
            ve["notes"] = item["notes"]

        new_item["verify"] = [ve] if ve else []
        ac_list_out.append(new_item)

    # Convert edge_case_tests
    for item in extra_items:
        if not isinstance(item, dict):
            continue
        new_item = {
            "id": str(item.get("id", "UNKNOWN")),
        }
        if "description" in item:
            new_item["description"] = item["description"]

        ve = {}
        is_automated = item.get("automated", False)
        test_file = item.get("test_file", "")

        if is_automated and test_file:
            ve["type"] = "automated"
            if item.get("test_type"):
                ve["test_type"] = item["test_type"]
            ve["file"] = test_file
        elif not is_automated:
            ve["type"] = "manual"
            if item.get("justification"):
                ve["justification"] = item["justification"]
        else:
            ve["type"] = "automated"
            if item.get("test_type"):
                ve["test_type"] = item["test_type"]

        new_item["verify"] = [ve] if ve else []
        ac_list_out.append(new_item)

    result["acceptance_criteria"] = ac_list_out
    return result


def _entry_to_verify(entry: dict) -> dict:
    """Convert a Format A test entry to a verify dict."""
    test_type = entry.get("type", "")
    test_file = entry.get("test_file", "")
    test_name = entry.get("test_name", "")

    ve: dict[str, Any] = {"type": "automated"}

    # Map Format A 'type' to test_type
    if test_type in ("manual",):
        ve["type"] = "manual"
        # Use test_file as a rough runbook/script reference
        if test_file:
            ve["file"] = test_file
        if test_name:
            ve["command"] = f"{test_file} {test_name}" if test_file else test_name
    elif test_type in ("monitoring", "runtime"):
        ve["type"] = "automated"
        ve["test_type"] = test_type
        if test_file:
            ve["file"] = test_file
        if test_name:
            ve["command"] = f"{test_file} {test_name}" if test_file else test_name
    else:
        ve["test_type"] = test_type if test_type else "integration"
        if test_file:
            ve["file"] = test_file
        if test_name and test_file:
            # Generate pytest-style command
            ve["command"] = f"pytest {test_file}::{test_name}"
        elif test_file:
            ve["command"] = f"pytest {test_file}"

    return ve


def _sort_ac_key(ac_id: str) -> tuple:
    """Sort AC IDs numerically: AC-001 < AC-010 < EC-1."""
    m = re.match(r"(AC|EC)-(\d+)", ac_id)
    if m:
        prefix = 0 if m.group(1) == "AC" else 1
        return (prefix, int(m.group(2)))
    return (2, 0)


class LiteralStr(str):
    """String that should be represented as literal in YAML."""
    pass


def str_representer(dumper, data):
    if "\n" in data:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    if len(data) > 80:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style='"')
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


def dump_yaml(data: dict) -> str:
    """Dump dict to YAML with readable formatting."""
    dumper = yaml.SafeDumper
    dumper.add_representer(str, str_representer)
    return yaml.dump(data, Dumper=dumper, default_flow_style=False, allow_unicode=True, sort_keys=False, width=200)


def convert_file(path: Path, dry_run: bool = False) -> bool:
    """Convert a single testmap file. Returns True if converted."""
    content = path.read_text(encoding="utf-8")
    data = yaml.safe_load(content)
    if not isinstance(data, dict):
        print(f"  SKIP {path.name}: not a YAML mapping")
        return False

    fmt = detect_format(data)
    if fmt == "B":
        print(f"  SKIP {path.name}: already Format B")
        return False
    if fmt == "unknown":
        print(f"  SKIP {path.name}: unknown format")
        return False

    print(f"  CONVERT {path.name}: Format {fmt} -> B")

    if fmt == "A":
        converted = convert_format_a(data)
    elif fmt == "C":
        converted = convert_format_c(data)
    else:
        return False

    # Preserve header comments
    header_lines = []
    for line in content.splitlines():
        if line.startswith("#"):
            header_lines.append(line)
        else:
            break

    output = dump_yaml(converted)
    if header_lines:
        output = "\n".join(header_lines) + "\n\n" + output

    if dry_run:
        print(f"--- DRY RUN: {path.name} ---")
        print(output[:500])
        if len(output) > 500:
            print(f"  ... ({len(output)} chars total)")
        return True

    path.write_text(output, encoding="utf-8")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description="Convert testmaps from Format A/C to canonical Format B.")
    ap.add_argument("path", type=str, help="Testmap file or directory")
    ap.add_argument("--all", action="store_true", help="Convert all non-B testmaps in directory")
    ap.add_argument("--dry-run", action="store_true", help="Preview without writing")
    args = ap.parse_args()

    target = Path(args.path)
    if target.is_file():
        files = [target]
    elif target.is_dir():
        files = sorted(target.glob("*_testmap.yaml")) + sorted(target.glob("*_testmap.yml"))
    else:
        print(f"ERROR: path not found: {target}")
        return 2

    if not files:
        print("No testmap files found.")
        return 0

    converted = 0
    for f in files:
        if convert_file(f, dry_run=args.dry_run):
            converted += 1

    action = "would convert" if args.dry_run else "converted"
    print(f"\n{converted}/{len(files)} files {action}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
