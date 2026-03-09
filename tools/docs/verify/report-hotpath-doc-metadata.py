#!/usr/bin/env python3
"""Report metadata coverage for canonical hot-path docs."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List


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
    "docs/adr/rfc",
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

METADATA_LINE_RE = re.compile(
    r"^_Audience:\s*(?P<audience>.+?)\s*•\s*Owner:\s*(?P<owner>.+?)\s*•\s*Last verified:\s*(?P<last_reviewed>\d{4}-\d{2}-\d{2})\s*•\s*Status:\s*(?P<status>.+?)_$",
    re.MULTILINE,
)
H1_RE = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


@dataclass
class DocReport:
    path: str
    fields_present: Dict[str, bool]


def iter_hotpath_docs() -> Iterable[Path]:
    seen: set[Path] = set()
    for rel_root in HOTPATH_ROOTS:
        root = REPO_ROOT / rel_root
        if not root.exists():
            continue
        for path in root.rglob("*.md"):
            if path in seen:
                continue
            seen.add(path)
            yield path


def parse_frontmatter(text: str) -> Dict[str, str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}

    data: Dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data


def classify(path: Path, text: str, frontmatter: Dict[str, str]) -> Dict[str, bool]:
    fields = {field: False for field in REQUIRED_FIELDS}

    h1 = H1_RE.search(text)
    if h1 and h1.group(1).strip():
        fields["title"] = True

    metadata_line = METADATA_LINE_RE.search(text)
    if metadata_line:
        fields["owner"] = bool(metadata_line.group("owner").strip())
        fields["status"] = bool(metadata_line.group("status").strip())
        fields["last_reviewed"] = bool(metadata_line.group("last_reviewed").strip())

    if frontmatter.get("canonical_root"):
        fields["canonical_root"] = True
    if frontmatter.get("doc_class"):
        fields["doc_class"] = True
    if frontmatter.get("summary"):
        fields["summary"] = True
    if frontmatter.get("tags"):
        fields["tags"] = True

    return fields


def build_report() -> Dict[str, object]:
    reports: List[DocReport] = []
    field_counts = {field: 0 for field in REQUIRED_FIELDS}

    for path in iter_hotpath_docs():
        text = path.read_text(encoding="utf-8")
        frontmatter = parse_frontmatter(text)
        fields = classify(path, text, frontmatter)
        for field, present in fields.items():
            if present:
                field_counts[field] += 1
        reports.append(DocReport(path=str(path.relative_to(REPO_ROOT)), fields_present=fields))

    total = len(reports)
    summary = {
        "total_docs": total,
        "field_coverage": {
            field: {
                "present": count,
                "percent": round((count / total) * 100, 2) if total else 0.0,
            }
            for field, count in field_counts.items()
        },
        "docs_missing_any_required_field": [
            report.path
            for report in reports
            if not all(report.fields_present.values())
        ],
        "doc_reports": [
            {
                "path": report.path,
                "fields_present": report.fields_present,
            }
            for report in reports
        ],
    }
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary-file", help="Optional path to write JSON summary to.")
    args = parser.parse_args()

    summary = build_report()
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    total = summary["total_docs"]
    missing = len(summary["docs_missing_any_required_field"])
    print(
        "HOTPATH_METADATA_COVERAGE "
        f"total_docs={total} docs_missing_any_required_field={missing}"
    )
    for field, stats in summary["field_coverage"].items():
        print(
            f"{field}: present={stats['present']} percent={stats['percent']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
