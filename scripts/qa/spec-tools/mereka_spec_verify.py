#!/usr/bin/env python3
"""mereka_spec_verify.py — Project-specific spec-testmap verifier for Mereka LMS.

Adapts the generic spec_verify.py for our directory layout:
  specs/<slug>_spec.md  →  specs/testmaps/<slug>_testmap.yaml

Reuses all verification logic from spec_verify.py.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List, Optional

from spec_verify import (
    find_markdown_files,
    is_spec_like,
    parse_acceptance_criteria,
    load_testmap,
    normalize_verify_entries,
)


def find_testmap_for_spec(spec_path: Path, testmaps_dir: Optional[Path] = None) -> Optional[Path]:
    """Find the testmap file for a spec using our directory convention.

    Convention: specs/<slug>_spec.md → specs/testmaps/<slug>_testmap.yaml
    """
    slug = spec_path.stem.replace("_spec", "")
    if testmaps_dir is None:
        testmaps_dir = spec_path.parent / "testmaps"
    for ext in [".yaml", ".yml"]:
        candidate = testmaps_dir / f"{slug}_testmap{ext}"
        if candidate.exists():
            return candidate
    return None


def verify_one_spec(spec_path: Path, testmaps_dir: Path, repo_root: Path) -> List[str]:
    """Verify a single spec against its testmap."""
    errors: List[str] = []
    md = spec_path.read_text(encoding="utf-8")

    acs = parse_acceptance_criteria(md)
    if not acs:
        errors.append("No Acceptance Criteria checkbox lines with AC-### IDs found.")
        return errors

    ids = [ac_id for ac_id, _ in acs]
    if len(set(ids)) != len(ids):
        errors.append("Duplicate Acceptance Criteria IDs found.")

    testmap_path = find_testmap_for_spec(spec_path, testmaps_dir)
    if not testmap_path:
        # Not an error by default — some specs may not have testmaps yet
        return errors

    try:
        tm = load_testmap(testmap_path)
    except Exception as e:
        errors.append(f"Failed to parse testmap {testmap_path.name}: {e}")
        return errors

    ac_items = tm.get("acceptance_criteria", [])
    if not isinstance(ac_items, list):
        errors.append(f"testmap {testmap_path.name}: acceptance_criteria must be a list")
        return errors

    tm_index: dict[str, dict] = {}
    for item in ac_items:
        if not isinstance(item, dict) or "id" not in item:
            errors.append(f"testmap {testmap_path.name}: each item must have an 'id' key")
            continue
        tm_index[str(item["id"]).strip()] = item

    for ac_id, ac_line in acs:
        if ac_id not in tm_index:
            errors.append(f"{ac_id} missing from testmap {testmap_path.name}")
            continue

        try:
            entries = normalize_verify_entries(tm_index[ac_id])
        except Exception as e:
            errors.append(f"{ac_id} invalid verify entries: {e}")
            continue

        if not entries:
            errors.append(f"{ac_id} has no verification entries in testmap.")
            continue

        for ve in entries:
            if ve.type not in ("automated", "monitoring", "manual"):
                errors.append(f"{ac_id} verify.type must be automated|monitoring|manual (got {ve.type!r})")

            if ve.type == "automated":
                if not ve.command:
                    errors.append(f"{ac_id} automated verification missing command.")
                if ve.file:
                    f = (repo_root / ve.file).resolve()
                    if not f.exists():
                        errors.append(f"{ac_id} references missing test file: {ve.file}")

            elif ve.type == "monitoring":
                if not ve.metric and not ve.dashboard:
                    errors.append(f"{ac_id} monitoring should include metric and/or dashboard.")

            elif ve.type == "manual":
                if not ve.runbook or not ve.section:
                    errors.append(f"{ac_id} manual verification requires runbook + section.")
                if not ve.justification:
                    errors.append(f"{ac_id} manual verification requires justification.")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify Mereka LMS specs against testmaps.")
    ap.add_argument("path", type=str, help="Spec file or specs/ directory")
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root for resolving paths")
    ap.add_argument("--testmaps-dir", type=str, default=None,
                     help="Directory containing testmaps (default: <specs-dir>/testmaps/)")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    files = find_markdown_files(target)
    spec_files = [f for f in files if f.name.endswith("_spec.md")]

    if not spec_files:
        print("No *_spec.md files found.")
        return 0

    testmaps_dir = Path(args.testmaps_dir) if args.testmaps_dir else target / "testmaps"
    if not testmaps_dir.is_dir():
        print(f"ERROR: testmaps directory not found: {testmaps_dir}")
        return 2

    any_errors = False
    for f in spec_files:
        errs = verify_one_spec(f, testmaps_dir, repo_root)
        if errs:
            any_errors = True
            print(f"\nFAIL {f}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"PASS {f}")

    return 1 if any_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
