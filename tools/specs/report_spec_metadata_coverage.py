#!/usr/bin/env python3
"""Report Wave 3 metadata coverage by spec lane."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.specs.spec_tooling import (
    LEGACY_STATUS_VALUES,
    iter_lane_files,
    missing_required_fields,
    parse_frontmatter,
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    counts = {
        "normative": 0,
        "proposal": 0,
        "plan": 0,
        "legacy_status_hits": 0,
        "root_non_normative_residue": 0,
        "normative_missing": 0,
        "proposal_missing": 0,
        "plan_missing": 0,
    }

    for lane, path in iter_lane_files(repo_root):
        frontmatter = parse_frontmatter(path)
        status = frontmatter.get("status")
        if status in LEGACY_STATUS_VALUES:
            counts["legacy_status_hits"] += 1

        if lane == "normative":
            counts["normative"] += 1
            if missing_required_fields(frontmatter, "normative"):
                counts["normative_missing"] += 1
            normativity = frontmatter.get("normativity")
            spec_class = frontmatter.get("spec_class")
            if normativity in {"proposed", "planning"} or spec_class in {"proposal", "plan"}:
                counts["root_non_normative_residue"] += 1
        elif lane == "proposal":
            counts["proposal"] += 1
            if missing_required_fields(frontmatter, "proposal"):
                counts["proposal_missing"] += 1
        else:
            counts["plan"] += 1
            if missing_required_fields(frontmatter, lane):
                counts["plan_missing"] += 1

    print(f"total normative specs: {counts['normative']}")
    print(f"total proposal specs: {counts['proposal']}")
    print(f"total plan files: {counts['plan']}")
    print(f"normative specs missing required fields: {counts['normative_missing']}")
    print(f"proposal specs missing required fields: {counts['proposal_missing']}")
    print(f"plan files missing required fields: {counts['plan_missing']}")
    print(f"remaining legacy status hits: {counts['legacy_status_hits']}")
    print(
        "remaining top-level non-normative root residue count: "
        f"{counts['root_non_normative_residue']}"
    )


if __name__ == "__main__":
    main()
