#!/usr/bin/env python3
"""Generate twin-root reading bundles for docs/specs hot paths."""

from __future__ import annotations

from pathlib import Path


DOCS_SPEC_BUNDLE = """# Docs/Specs Contract Hot Path

Read this bundle when you need the minimum cross-root truth for platform work.

## Read first

- `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
- `docs/guides/standards/DOCS_SPECS_CONTRACT.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_METADATA_MODEL.md`

## Machine-readable surfaces

- `docs/catalog.json`
- `specs/catalog.json`
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

## Use these next

- `specs/proposals/README.md` for not-yet-normative spec proposals
- `specs/plans/README.md` for execution and rollout plans
- `docs/_generated/bundles/60-docs-specs-contract.md` for the cross-root bridge
"""


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    docs_bundle = repo_root / "docs" / "_generated" / "bundles" / "60-docs-specs-contract.md"
    spec_bundle = repo_root / "specs" / "_generated" / "bundles" / "00-spec-hot-path.md"
    spec_index = repo_root / "specs" / "_generated" / "indexes" / "spec-read-first.md"
    write(docs_bundle, DOCS_SPEC_BUNDLE)
    write(spec_bundle, SPEC_HOT_PATH_BUNDLE)
    write(spec_index, SPEC_READ_FIRST_INDEX)
    print("SPEC_BUNDLES_OK bundles=3")


if __name__ == "__main__":
    main()
