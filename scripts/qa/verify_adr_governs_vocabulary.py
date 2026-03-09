#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
TAXONOMY = ROOT / "docs/meta/docs-program/metadata/governs-taxonomy.yaml"
MANIFEST = ROOT / "docs/adr/manifest.yaml"
ADR_ROOTS = [ROOT / "docs/adr", ROOT / "docs/adr/rfc"]


def load_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}
    _, rest = text.split("---\n", 1)
    front, _ = rest.split("\n---\n", 1)
    return yaml.safe_load(front) or {}


def validate_governs(values: Any, allowed: set[str], source: str, errors: list[str], counter: list[int]) -> None:
    if values is None:
        return
    if not isinstance(values, list):
        errors.append(f"{source}: governs must be a list")
        return
    for value in values:
        counter[0] += 1
        if not isinstance(value, str):
            errors.append(f"{source}: governs entry must be a string: {value!r}")
        elif value not in allowed:
            errors.append(f"{source}: unknown governs token '{value}'")


def walk_manifest(node: Any, allowed: set[str], errors: list[str], counter: list[int], path: str = "manifest") -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            next_path = f"{path}.{key}"
            if key == "governs":
                validate_governs(value, allowed, next_path, errors, counter)
            else:
                walk_manifest(value, allowed, errors, counter, next_path)
    elif isinstance(node, list):
        for idx, item in enumerate(node):
            walk_manifest(item, allowed, errors, counter, f"{path}[{idx}]")


def main() -> int:
    taxonomy = yaml.safe_load(TAXONOMY.read_text()) or {}
    allowed = {entry["token"] for entry in taxonomy.get("tokens", []) if isinstance(entry, dict) and "token" in entry}
    errors: list[str] = []
    checked_docs = 0
    checked_tokens = [0]

    for adr_root in ADR_ROOTS:
        for path in sorted(adr_root.glob("*.md")):
            meta = load_frontmatter(path)
            if "governs" in meta:
                checked_docs += 1
                validate_governs(meta.get("governs"), allowed, str(path.relative_to(ROOT)), errors, checked_tokens)

    manifest_data = yaml.safe_load(MANIFEST.read_text()) or {}
    manifest_tokens = [0]
    walk_manifest(manifest_data, allowed, errors, manifest_tokens)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(
        f"ADR_GOVERNS_VOCAB_OK checked_docs={checked_docs} checked_doc_tokens={checked_tokens[0]} checked_manifest_tokens={manifest_tokens[0]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
