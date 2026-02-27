#!/usr/bin/env python3
"""extract_manual_entries.py — Extract manual/monitoring entries from testmaps.

Creates specs/manual_verifications.yaml with all non-automated entries.

Usage:
  python3 extract_manual_entries.py                    # Dry-run
  python3 extract_manual_entries.py --apply            # Write file
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parents[3]
TESTMAPS_DIR = REPO_ROOT / "specs" / "testmaps"
OUTPUT_PATH = REPO_ROOT / "specs" / "manual_verifications.yaml"


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
    for tm_path in sorted(files):
        yield tm_path


def extract_entries(testmaps_dir: Path) -> list[dict]:
    """Read all testmaps, extract manual and monitoring verify entries."""
    entries = []

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

            verify_list = ac.get("verify", [])
            non_automated = [
                v for v in verify_list
                if v.get("type") in ("manual", "monitoring")
            ]

            if not non_automated:
                continue

            entry = {
                "id": ac_id,
                "spec": spec_name,
            }

            # Include description if present
            desc = ac.get("description", "")
            if desc:
                entry["description"] = desc

            # Only include the non-automated verify entries
            clean_verify = []
            for v in non_automated:
                cv = {"type": v["type"]}
                # Copy all fields except 'type' in a stable order
                for key in ("runbook", "section", "justification", "file",
                            "metric", "dashboard"):
                    if key in v:
                        cv[key] = v[key]
                clean_verify.append(cv)

            entry["verify"] = clean_verify
            entries.append(entry)

    return entries


def sort_key(entry: dict) -> tuple:
    """Sort by spec name, then AC ID numerically."""
    spec = entry.get("spec", "")
    ac_id = entry.get("id", "")
    parts = ac_id.split("-")
    try:
        num = int(parts[-1])
    except ValueError:
        num = 0
    prefix = "-".join(parts[:-1])
    return (spec, prefix, num)


def format_output(entries: list[dict]) -> str:
    """Format entries as YAML with a header comment."""
    header = (
        f"# Manual and monitoring verification entries.\n"
        f"# Automated entries are discovered from @covers annotations in code.\n"
        f"# Generated from testmaps on {date.today().isoformat()}\n"
    )

    doc = {"entries": entries}

    # Use yaml.dump with specific formatting
    body = yaml.dump(
        doc,
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
        width=120,
    )

    return header + body


def main():
    parser = argparse.ArgumentParser(description="Extract manual/monitoring entries from testmaps")
    parser.add_argument("--apply", action="store_true", help="Write file (default: dry-run)")
    args = parser.parse_args()

    if not TESTMAPS_DIR.is_dir():
        print(f"ERROR: Testmaps directory not found: {TESTMAPS_DIR}", file=sys.stderr)
        sys.exit(1)

    print(f"{'APPLYING' if args.apply else 'DRY RUN'}: Reading testmaps from {TESTMAPS_DIR}")
    print()

    entries = extract_entries(TESTMAPS_DIR)
    entries.sort(key=sort_key)

    # Stats by type and spec
    by_type: dict[str, int] = defaultdict(int)
    by_spec: dict[str, int] = defaultdict(int)

    for entry in entries:
        for v in entry["verify"]:
            by_type[v["type"]] += 1
        by_spec[entry["spec"]] += 1

    output = format_output(entries)

    if args.apply:
        OUTPUT_PATH.write_text(output)
        print(f"  WRITTEN: {OUTPUT_PATH}")
    else:
        print(f"  WOULD WRITE: {OUTPUT_PATH}")
        print()
        # Show first 30 lines as preview
        preview_lines = output.splitlines()[:30]
        for line in preview_lines:
            print(f"    {line}")
        if len(output.splitlines()) > 30:
            print(f"    ... ({len(output.splitlines()) - 30} more lines)")

    print()
    print("=" * 60)
    print(f"Summary:")
    print(f"  Total entries: {len(entries)}")
    print(f"  By type:")
    for t, count in sorted(by_type.items()):
        print(f"    {t}: {count}")
    print(f"  By spec ({len(by_spec)} specs with non-automated entries):")
    for spec, count in sorted(by_spec.items(), key=lambda x: -x[1]):
        print(f"    {spec}: {count}")


if __name__ == "__main__":
    main()
