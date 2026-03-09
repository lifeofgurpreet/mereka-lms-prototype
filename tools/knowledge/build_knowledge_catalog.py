#!/usr/bin/env python3
"""Build a unified docs/specs knowledge catalog from the shared Wave 4 model."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.knowledge_model import classify_path, iter_knowledge_files, to_json_value


def build_catalog(repo_root: Path) -> dict:
    entries = [classify_path(path, repo_root) for path in iter_knowledge_files(repo_root)]
    root_counts = Counter(entry["root"] for entry in entries)
    lane_counts = Counter(f"{entry['root']}:{entry['lane']}" for entry in entries)
    classification_counts = Counter(entry["classification"] for entry in entries)
    return {
        "generated_by": "tools/knowledge/build_knowledge_catalog.py",
        "entry_count": len(entries),
        "roots": {
            "docs": root_counts.get("docs", 0),
            "specs": root_counts.get("specs", 0),
        },
        "classifications": dict(sorted(classification_counts.items())),
        "lanes": dict(sorted(lane_counts.items())),
        "entries": [to_json_value(entry) for entry in sorted(entries, key=lambda item: item["path"])],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="generated/catalogs/knowledge-catalog.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    catalog = build_catalog(repo_root)
    rendered = json.dumps(catalog, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("KNOWLEDGE_CATALOG_DRIFT")
        print(f"KNOWLEDGE_CATALOG_OK entries={catalog['entry_count']} mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"KNOWLEDGE_CATALOG_OK entries={catalog['entry_count']} mode=write")


if __name__ == "__main__":
    main()
