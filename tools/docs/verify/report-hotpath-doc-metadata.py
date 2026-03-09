#!/usr/bin/env python3
"""Audit metadata coverage for canonical hot-path docs."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    print(f"FAILED_TO_IMPORT_YAML: {exc}", file=sys.stderr)
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parents[3]
HOTPATH_ROOTS = [
    "docs/concepts/architecture",
    "docs/ops",
    "docs/guides/standards",
    "docs/reference",
    "docs/policies",
    "docs/status",
    "docs/evidence",
    "docs/adr",
]
REQUIRED_FIELDS = [
    "title",
    "owner",
    "status",
    "last_reviewed",
    "canonical_root",
    "doc_class",
    "summary",
    "tags",
]
INLINE_PATTERNS = {
    "owner": re.compile(r"^_Owner:\s*(.+?)_\s*$", re.IGNORECASE),
    "status": re.compile(r"^_Status:\s*(.+?)_\s*$", re.IGNORECASE),
    "last_reviewed": re.compile(r"^_Last reviewed:\s*(.+?)_\s*$", re.IGNORECASE),
}
FRONTMATTER_DELIM = "---"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary-file", type=Path, default=None)
    return parser.parse_args()


def iter_docs() -> list[Path]:
    docs: dict[str, Path] = {}
    for rel_root in HOTPATH_ROOTS:
        root = REPO_ROOT / rel_root
        if not root.exists():
            continue
        for path in root.rglob("*.md"):
            if path.is_file():
                docs[str(path.relative_to(REPO_ROOT))] = path
    return [docs[key] for key in sorted(docs)]


def parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith(f"{FRONTMATTER_DELIM}\n"):
        return {}, text

    end = text.find(f"\n{FRONTMATTER_DELIM}\n", len(FRONTMATTER_DELIM) + 1)
    if end == -1:
        return {}, text

    raw = text[len(FRONTMATTER_DELIM) + 1 : end]
    body = text[end + len(f"\n{FRONTMATTER_DELIM}\n") :]
    parsed = yaml.safe_load(raw) or {}
    if not isinstance(parsed, dict):
        return {}, body
    return parsed, body


def first_heading(body: str) -> str | None:
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip()
    return None


def inline_metadata(body: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for line in body.splitlines():
        for field, pattern in INLINE_PATTERNS.items():
            match = pattern.match(line.strip())
            if match:
                found[field] = match.group(1).strip()
    return found


def has_value(value) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, set, dict)):
        return bool(value)
    return True


def classify(path: Path) -> dict[str, bool]:
    text = path.read_text(encoding="utf-8")
    frontmatter, body = parse_frontmatter(text)
    inline = inline_metadata(body)

    tags_value = frontmatter.get("tags")
    if isinstance(tags_value, str):
        tags_value = [item.strip() for item in tags_value.split(",") if item.strip()]

    title_value = frontmatter.get("title") or first_heading(body)

    values = {
        "title": title_value,
        "owner": frontmatter.get("owner") or inline.get("owner"),
        "status": frontmatter.get("status") or inline.get("status"),
        "last_reviewed": frontmatter.get("last_reviewed") or inline.get("last_reviewed"),
        "canonical_root": frontmatter.get("canonical_root"),
        "doc_class": frontmatter.get("doc_class"),
        "summary": frontmatter.get("summary"),
        "tags": tags_value,
    }
    return {field: has_value(values[field]) for field in REQUIRED_FIELDS}


def main() -> int:
    args = parse_args()
    docs = iter_docs()
    totals = {field: 0 for field in REQUIRED_FIELDS}
    docs_missing_any_required_field = 0

    for path in docs:
        fields = classify(path)
        missing_any = False
        for field, present in fields.items():
            if present:
                totals[field] += 1
            else:
                missing_any = True
        if missing_any:
            docs_missing_any_required_field += 1

    total_docs = len(docs)
    print(
        "HOTPATH_METADATA_COVERAGE "
        f"total_docs={total_docs} "
        f"docs_missing_any_required_field={docs_missing_any_required_field}"
    )
    summary = {
        "total_docs": total_docs,
        "docs_missing_any_required_field": docs_missing_any_required_field,
        "fields": {},
    }
    for field in REQUIRED_FIELDS:
        present = totals[field]
        percent = round((present / total_docs) * 100, 2) if total_docs else 0.0
        print(f"{field}: present={present} percent={percent}")
        summary["fields"][field] = {"present": present, "percent": percent}

    if args.summary_file:
        args.summary_file.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
