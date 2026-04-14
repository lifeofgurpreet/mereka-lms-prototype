#!/usr/bin/env python3
"""Generate twin-root reading bundles for docs/specs hot paths."""

from __future__ import annotations

import argparse
from pathlib import Path


DOCS_SPEC_BUNDLE = """# Docs/Specs Contract Hot Path

Read this bundle when you need the minimum cross-root truth for platform work.

## Read first

- `docs/README.md`
- `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
- `docs/guides/standards/DOCS_SPECS_CONTRACT.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_METADATA_MODEL.md`

## Machine-readable surfaces

- `docs/catalog.json`
- `specs/catalog.json`
- `specs/_generated/graph.json`
- `specs/_generated/testmaps/README.md`
"""


SPEC_HOT_PATH_BUNDLE = """# Spec Hot Path

Read this bundle when you need the minimum normative spec reading set.

## Read first

- `specs/INDEX.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`
- `specs/catalog.json`
- `specs/proposals/README.md`
- `specs/plans/README.md`
- `specs/_generated/testmaps/README.md`
"""


SPEC_READ_FIRST_INDEX = """# Spec Read First

Use this generated index when you need the shortest path into the spec system.

## Start with system rules

- `specs/README.md`
- `specs/INDEX.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`

## Machine-readable surfaces

- `specs/catalog.json`
- `specs/_generated/graph.json`
- `specs/_generated/testmaps/README.md`
- `specs/proposals/README.md`
- `specs/plans/README.md`

## Use these next

- `specs/proposals/README.md` for not-yet-normative spec proposals
- `specs/plans/README.md` for execution and rollout plans
- `docs/_generated/bundles/60-docs-specs-contract.md` for the cross-root bridge
"""


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n")


def render_outputs(repo_root: Path) -> dict[Path, str]:
    docs_bundle = repo_root / "docs" / "_generated" / "bundles" / "60-docs-specs-contract.md"
    spec_bundle = repo_root / "specs" / "_generated" / "bundles" / "00-spec-hot-path.md"
    spec_index = repo_root / "specs" / "_generated" / "indexes" / "spec-read-first.md"
    return {
        docs_bundle: DOCS_SPEC_BUNDLE.rstrip() + "\n",
        spec_bundle: SPEC_HOT_PATH_BUNDLE.rstrip() + "\n",
        spec_index: SPEC_READ_FIRST_INDEX.rstrip() + "\n",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if generated bundles would change")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    outputs = render_outputs(repo_root)

    if args.check:
        for path, content in outputs.items():
            current = path.read_text() if path.exists() else ""
            if current != content:
                raise SystemExit(f"SPEC_BUNDLES_DRIFT: {path.relative_to(repo_root)} is out of date")
        print("SPEC_BUNDLES_OK bundles=3 mode=check")
        return

    for path, content in outputs.items():
        write(path, content)
    print("SPEC_BUNDLES_OK bundles=3 mode=write")


if __name__ == "__main__":
    main()
