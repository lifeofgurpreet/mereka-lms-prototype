#!/usr/bin/env python3
"""validate_testmap_format.py — Validates all testmaps use canonical Format B.

Canonical Format B requires:
- Top-level key: acceptance_criteria (list)
- Each item: id, verify (list of verify entries)
- No top-level 'tests' key (Format A)
- verify entries have: type (automated|manual|monitoring)

Exits 0 if all testmaps are valid, 1 if any violations found.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Tuple

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")


def validate_testmap(path: Path) -> List[str]:
    """Validate a single testmap file is in canonical Format B."""
    errors: List[str] = []

    try:
        content = path.read_text(encoding="utf-8")
        data = yaml.safe_load(content)
    except Exception as e:
        return [f"Failed to parse YAML: {e}"]

    if not isinstance(data, dict):
        return ["Root must be a YAML mapping"]

    # Check for legacy Format A
    if "tests" in data:
        errors.append("Uses legacy Format A ('tests:' key). Must use 'acceptance_criteria:' with 'verify:' blocks.")
        return errors

    # Must have acceptance_criteria
    ac_list = data.get("acceptance_criteria")
    if ac_list is None:
        errors.append("Missing 'acceptance_criteria' top-level key.")
        return errors

    if not isinstance(ac_list, list):
        errors.append("'acceptance_criteria' must be a list.")
        return errors

    for i, item in enumerate(ac_list):
        prefix = f"acceptance_criteria[{i}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix}: must be a mapping")
            continue

        # Must have id
        if "id" not in item:
            errors.append(f"{prefix}: missing 'id' field")

        # Must have verify (list)
        verify = item.get("verify")
        if verify is None:
            # Format C detection: has flat test_file/command but no verify
            if "test_file" in item or "command" in item:
                errors.append(f"{prefix} (id={item.get('id', '?')}): Uses flat Format C (test_file/command without verify: block). Wrap in verify: list.")
            else:
                errors.append(f"{prefix} (id={item.get('id', '?')}): missing 'verify' field")
            continue

        if not isinstance(verify, list):
            errors.append(f"{prefix} (id={item.get('id', '?')}): 'verify' must be a list")
            continue

        for j, ve in enumerate(verify):
            vprefix = f"{prefix}.verify[{j}]"
            if not isinstance(ve, dict):
                errors.append(f"{vprefix}: must be a mapping")
                continue
            vtype = ve.get("type", "")
            if vtype not in ("automated", "manual", "monitoring"):
                errors.append(f"{vprefix}: type must be automated|manual|monitoring (got '{vtype}')")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate all testmaps use canonical Format B.")
    ap.add_argument("path", type=str, help="Testmaps directory or single file")
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

    any_errors = False
    for f in files:
        errs = validate_testmap(f)
        if errs:
            any_errors = True
            print(f"\nFAIL {f.name}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"PASS {f.name}")

    return 1 if any_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
