#!/usr/bin/env python3
"""Advisory scan for winning-root docs with no inbound doc references."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path, PurePosixPath
from urllib.parse import unquote

WINNING_ROOTS = (
    "adr/",
    "concepts/architecture/",
    "evidence/",
    "guides/",
    "ops/",
    "policies/",
    "reference/",
    "status/",
)

ENTRYPOINTS = {
    "README.md",
    "CONTRIBUTING.md",
    "DOCS_REMEDIATION_PLAN_AND_TRACKER.md",
    "adr/README.md",
    "concepts/architecture/README.md",
    "evidence/INDEX.md",
    "status/INDEX.md",
    "status/weekly/README.md",
    "status/incidents/README.md",
}

LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
SUPERSEDED_RE = re.compile(r"(?im)^(status:\s*superseded|_status:\s*superseded_|status:\s*\"superseded\")")
SUPERSEDED_BY_RE = re.compile(r"(?im)^\s*superseded_by:\s*.+$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-file", default="")
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--fail-on-orphans", action="store_true")
    return parser.parse_args()


def in_winning_root(path: str) -> bool:
    return path.endswith(".md") and path.startswith(WINNING_ROOTS)


def is_index_like(path: str) -> bool:
    name = PurePosixPath(path).name.lower()
    return name in {"readme.md", "index.md"}


def resolve_doc_link(source: str, target: str) -> str | None:
    if target.startswith(("http://", "https://", "mailto:", "tel:", "#")):
        return None

    cleaned = target.split("#", 1)[0].strip()
    if not cleaned:
        return None

    cleaned = unquote(cleaned)
    if cleaned.startswith("/"):
        cleaned = cleaned.lstrip("/")

    source_dir = PurePosixPath(source).parent
    if cleaned.startswith("docs/"):
        normalized = PurePosixPath(cleaned[5:])
    else:
        normalized = PurePosixPath(source_dir, cleaned)

    parts: list[str] = []
    for part in normalized.parts:
        if part in {"", "."}:
            continue
        if part == "..":
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return "/".join(parts)


def extract_link_targets(source: str, text: str) -> set[str]:
    targets: set[str] = set()
    for match in LINK_RE.finditer(text):
        resolved = resolve_doc_link(source, match.group(1))
        if resolved:
            targets.add(resolved)
    return targets


def is_superseded_stub(text: str) -> bool:
    head = "\n".join(text.splitlines()[:25])
    return bool(SUPERSEDED_RE.search(head) and SUPERSEDED_BY_RE.search(text))


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    docs_root = repo_root / "docs"

    markdown_paths: list[str] = []
    markdown_text: dict[str, str] = {}
    for file in docs_root.rglob("*.md"):
        rel = file.relative_to(docs_root).as_posix()
        markdown_paths.append(rel)
        markdown_text[rel] = file.read_text(encoding="utf-8")

    candidates = sorted(
        path
        for path in markdown_paths
        if in_winning_root(path)
        and path not in ENTRYPOINTS
        and not is_index_like(path)
        and not is_superseded_stub(markdown_text[path])
    )

    extracted_links = {
        source: extract_link_targets(source, text)
        for source, text in markdown_text.items()
    }

    inbound_counts: dict[str, int] = {path: 0 for path in candidates}
    for target in candidates:
        for source, targets in extracted_links.items():
            if source == target:
                continue
            if target in targets:
                inbound_counts[target] += 1

    orphan_docs = [path for path, count in inbound_counts.items() if count == 0]
    summary = {
        "status": "advisory",
        "winning_roots": list(WINNING_ROOTS),
        "entrypoints": sorted(ENTRYPOINTS),
        "candidates_checked": len(candidates),
        "orphan_docs_count": len(orphan_docs),
        "orphan_docs_sample": orphan_docs[: args.limit],
        "linked_docs_count": sum(1 for count in inbound_counts.values() if count > 0),
    }

    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    print(
        "DOC_ORPHAN_SCAN_ADVISORY "
        f"candidates_checked={summary['candidates_checked']} "
        f"orphan_docs={summary['orphan_docs_count']}"
    )
    if args.fail_on_orphans and orphan_docs:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
