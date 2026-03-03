#!/usr/bin/env python3
"""annotate_scripts.py — Inject @covers and @spec annotations from testmaps.

One-shot migration: reads all testmaps, builds file→AC mapping, writes annotations.

Usage:
  python3 annotate_scripts.py                  # Dry-run (print changes)
  python3 annotate_scripts.py --apply          # Write annotations to files
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

REPO_ROOT = Path(__file__).resolve().parents[3]
TESTMAPS_DIR = REPO_ROOT / "specs" / "testmaps"


def normalize_spec_name(raw: str) -> str:
    """Strip optional 'specs/' prefix and quotes to get bare spec filename."""
    name = raw.strip().strip('"').strip("'")
    if name.startswith("specs/"):
        name = name[len("specs/"):]
    return name


def iter_testmap_files(testmaps_dir: Path):
    """Yield testmap files in canonical and legacy naming formats."""
    files = set()
    for pattern in ("*.testmap.yml", "*.testmap.yaml", "*_testmap.yaml"):
        files.update(testmaps_dir.glob(pattern))
    yield from sorted(files)


def build_file_index(testmaps_dir: Path) -> dict[str, dict]:
    """Build reverse index: {file_path: {specs: {spec_name: set[ac_id]}}}."""
    index: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))

    for tm_path in iter_testmap_files(testmaps_dir):
        try:
            data = yaml.safe_load(tm_path.read_text())
        except Exception as e:
            print(f"WARNING: Failed to parse {tm_path.name}: {e}", file=sys.stderr)
            continue

        if not data or "spec" not in data:
            print(f"WARNING: No 'spec' field in {tm_path.name}", file=sys.stderr)
            continue

        spec_name = normalize_spec_name(data["spec"])
        criteria = data.get("acceptance_criteria", [])
        if not criteria:
            continue

        for ac in criteria:
            ac_id = ac.get("id", "")
            if not ac_id:
                continue
            for v in ac.get("verify", []):
                if v.get("type") != "automated":
                    continue
                fpath = v.get("file", "")
                if not fpath:
                    continue
                # Normalize path (strip leading ./)
                fpath = fpath.lstrip("./")
                index[fpath][spec_name].add(ac_id)

    return index


def sort_ac_ids(ids: set[str]) -> list[str]:
    """Sort AC IDs numerically: AC-001, AC-002, ..., AC-TCR-001, etc."""
    def sort_key(ac_id: str):
        parts = ac_id.split("-")
        # Try to get numeric part from the end
        try:
            num = int(parts[-1])
        except ValueError:
            num = 0
        prefix = "-".join(parts[:-1])
        return (prefix, num)
    return sorted(ids, key=sort_key)


def pick_primary_spec(specs: dict[str, set[str]]) -> str:
    """Pick the spec with the most ACs as the primary @spec."""
    return max(specs, key=lambda s: len(specs[s]))


def build_annotation_block(all_ac_ids: list[str], primary_spec: str) -> list[str]:
    """Build the annotation comment lines."""
    lines = []
    lines.append(f"# @covers {', '.join(all_ac_ids)}")
    lines.append(f"# @spec: {primary_spec}")
    return lines


def annotate_file(filepath: Path, all_ac_ids: list[str], primary_spec: str, apply: bool) -> str:
    """Inject annotations into a file. Returns status string."""
    content = filepath.read_text()
    lines = content.splitlines(True)  # Keep line endings

    # Check if already annotated
    if any("@covers" in line for line in lines):
        return "SKIP (already has @covers)"

    annotation_lines = build_annotation_block(all_ac_ids, primary_spec)
    annotation_text = "\n".join(annotation_lines) + "\n"

    # Find insertion point
    insert_idx = 0
    if lines and lines[0].startswith("#!"):
        # After shebang line
        insert_idx = 1
        # Also skip blank line after shebang if present
        # But keep looking for the end of the existing header comment block
        # Insert right after shebang
    elif filepath.suffix == ".py":
        # For Python files without shebang, insert at top
        insert_idx = 0
    else:
        insert_idx = 0

    # Build new content
    before = lines[:insert_idx]
    after = lines[insert_idx:]

    new_content = "".join(before) + annotation_text + "".join(after)

    if apply:
        filepath.write_text(new_content)
        return "ANNOTATED"
    else:
        return "WOULD ANNOTATE"


def main():
    parser = argparse.ArgumentParser(description="Inject @covers/@spec annotations from testmaps")
    parser.add_argument("--apply", action="store_true", help="Write annotations (default: dry-run)")
    args = parser.parse_args()

    if not TESTMAPS_DIR.is_dir():
        print(f"ERROR: Testmaps directory not found: {TESTMAPS_DIR}", file=sys.stderr)
        sys.exit(1)

    print(f"{'APPLYING' if args.apply else 'DRY RUN'}: Reading testmaps from {TESTMAPS_DIR}")
    print()

    # Build index
    file_index = build_file_index(TESTMAPS_DIR)

    # Stats
    annotated = 0
    skipped = 0
    missing = 0
    total_acs = 0

    for fpath_str in sorted(file_index):
        specs = file_index[fpath_str]
        filepath = REPO_ROOT / fpath_str

        if not filepath.is_file():
            print(f"  MISSING: {fpath_str}")
            missing += 1
            continue

        # Merge all AC IDs across all specs
        all_ac_ids_set: set[str] = set()
        for ac_ids in specs.values():
            all_ac_ids_set.update(ac_ids)

        all_ac_ids = sort_ac_ids(all_ac_ids_set)
        primary_spec = pick_primary_spec(specs)

        status = annotate_file(filepath, all_ac_ids, primary_spec, args.apply)

        if "SKIP" in status:
            skipped += 1
        elif "ANNOTAT" in status:
            annotated += 1
            total_acs += len(all_ac_ids)

        print(f"  {status}: {fpath_str} ({len(all_ac_ids)} ACs from {len(specs)} spec(s))")

    print()
    print("=" * 60)
    print("Summary:")
    print(f"  Files {'annotated' if args.apply else 'to annotate'}: {annotated}")
    print(f"  Files skipped (already annotated):  {skipped}")
    print(f"  Files missing on disk:              {missing}")
    print(f"  Total AC mappings:                  {total_acs}")
    print(f"  Total unique files in testmaps:     {len(file_index)}")


if __name__ == "__main__":
    main()
