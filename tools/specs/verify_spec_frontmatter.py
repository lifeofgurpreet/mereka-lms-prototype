#!/usr/bin/env python3
"""Verify required frontmatter fields across normative, proposal, and plan lanes."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.specs.spec_tooling import iter_lane_files, missing_required_fields, parse_frontmatter


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    missing = []
    checked = 0

    for lane, path in iter_lane_files(repo_root):
        frontmatter = parse_frontmatter(path)
        missing_fields = missing_required_fields(frontmatter, lane)
        if missing_fields:
            missing.append((path.relative_to(repo_root).as_posix(), lane, missing_fields))
        checked += 1

    if missing:
        for path, lane, fields in missing:
            print(
                f"SPEC_FRONTMATTER_FAIL {path} lane={lane} missing={','.join(fields)}"
            )
        raise SystemExit(1)

    print(f"SPEC_FRONTMATTER_OK files_checked={checked}")


if __name__ == "__main__":
    main()
