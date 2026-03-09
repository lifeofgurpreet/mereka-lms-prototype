#!/usr/bin/env python3
"""Report unified docs/specs control-plane coverage from one shared model."""

from __future__ import annotations

import argparse
from collections import Counter
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.knowledge_model import classify_path


def iter_knowledge_files(repo_root: Path) -> list[Path]:
    paths: list[Path] = []
    for root_name in ("docs", "specs"):
        root = repo_root / root_name
        for path in sorted(root.rglob("*")):
            if path.is_file() and path.suffix in {".md", ".json", ".yml", ".yaml"}:
                paths.append(path)
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    entries = [classify_path(path, repo_root) for path in iter_knowledge_files(repo_root)]

    root_counts = Counter(entry["root"] for entry in entries)
    lane_counts = Counter((entry["root"], entry["lane"]) for entry in entries)
    class_counts = Counter(entry["classification"] for entry in entries)

    print("KNOWLEDGE_CONTROL_PLANE_OK")
    print(f"total tracked files: {len(entries)}")
    print(f"docs files: {root_counts.get('docs', 0)}")
    print(f"specs files: {root_counts.get('specs', 0)}")
    print(f"compatibility surfaces: {class_counts.get('compatibility', 0)}")
    print(f"generated surfaces: {class_counts.get('generated', 0)}")
    print(f"archival surfaces: {class_counts.get('archival', 0)}")

    for root, lane in sorted(lane_counts):
        print(f"lane[{root}:{lane}]: {lane_counts[(root, lane)]}")


if __name__ == "__main__":
    main()
