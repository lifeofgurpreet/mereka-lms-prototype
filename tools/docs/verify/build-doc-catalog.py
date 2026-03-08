#!/usr/bin/env python3
"""Build docs catalog artifacts from repository docs metadata and path taxonomy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict


METADATA_RE = re.compile(r"^_(.+)_$")
COMMENT_DATE_RE = re.compile(
    r"<!--\s*Last\s+(verified|updated):\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*-->"
)
ADR_STATUS_RE = re.compile(r"^\*\*Status\*\*:\s*(.+?)\s*$", re.IGNORECASE)
ADR_DATE_RE = re.compile(r"^\*\*Date\*\*:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*$", re.IGNORECASE)
VALID_STATUSES = {
    "canonical",
    "supporting",
    "superseded",
    "historical",
    "archive-candidate",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Repo root")
    parser.add_argument("--docs-root", default="docs", help="Docs root relative to repo root")
    parser.add_argument(
        "--source-out",
        default="generated/catalogs/docs-catalog.json",
        help="Generated source catalog path relative to repo root",
    )
    parser.add_argument(
        "--mirror-out",
        default="docs/catalog.json",
        help="Derived mirror catalog path relative to repo root",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail on drift instead of writing files",
    )
    return parser.parse_args()


def normalize_key(raw: str) -> str:
    return raw.strip().lower().replace(" ", "_")


def load_existing_catalog(path: Path) -> Dict[str, Dict[str, Any]]:
    if not path.exists():
        return {}
    payload = json.loads(path.read_text())
    if not isinstance(payload, list):
        return {}
    existing: Dict[str, Dict[str, Any]] = {}
    for entry in payload:
        if isinstance(entry, dict) and isinstance(entry.get("path"), str):
            existing[entry["path"]] = entry
    return existing


def parse_frontmatter(lines: list[str]) -> Dict[str, str]:
    if not lines or lines[0].strip() != "---":
        return {}
    values: Dict[str, str] = {}
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            return values
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[normalize_key(key)] = value.strip().strip('"').strip("'")
    return {}


def parse_inline_metadata(lines: list[str]) -> Dict[str, str]:
    for line in lines[:12]:
        match = METADATA_RE.match(line.strip())
        if not match:
            continue
        values: Dict[str, str] = {}
        for part in match.group(1).split("•"):
            if ":" not in part:
                continue
            key, value = part.split(":", 1)
            values[normalize_key(key)] = value.strip()
        if values:
            return values
    return {}


def parse_comment_date(lines: list[str]) -> str:
    for line in lines[:20]:
        match = COMMENT_DATE_RE.search(line)
        if match:
            return match.group(2)
    return ""


def parse_adr_fields(lines: list[str]) -> Dict[str, str]:
    values: Dict[str, str] = {}
    for line in lines[:20]:
        status_match = ADR_STATUS_RE.match(line.strip())
        if status_match:
            values["adr_status"] = status_match.group(1).strip().lower()
        date_match = ADR_DATE_RE.match(line.strip())
        if date_match:
            values["adr_date"] = date_match.group(1)
    return values


def derive_type(path_text: str, existing: Dict[str, Any]) -> str:
    if path_text in {"README.md", "CONTRIBUTING.md", "catalog.json"} or path_text.endswith("/INDEX.md"):
        return "index"
    if path_text.startswith("evidence/"):
        return "evidence"
    if path_text.startswith(("status/", "archive/reports/")):
        return "status"
    if path_text.startswith(("ops/", "operations/", "runbooks/")):
        return "runbook"
    if path_text.startswith(("guides/", "branding/", "onboarding/")):
        return "guide"
    if path_text.startswith(("concepts/architecture/", "architecture/", "adr/")):
        return "concept"
    return str(existing.get("type") or "other")


def derive_status(
    path_text: str,
    text: str,
    metadata: Dict[str, str],
    adr_fields: Dict[str, str],
    existing: Dict[str, Any],
) -> str:
    explicit = str(metadata.get("status") or "").strip().lower()
    if explicit in VALID_STATUSES:
        return explicit
    if path_text.startswith("archive/"):
        return "archive-candidate"
    if "superseded_by:" in text or "(superseded)" in text.lower():
        return "superseded"
    adr_status = adr_fields.get("adr_status", "")
    if adr_status in {"superseded", "deprecated"}:
        return "historical"
    if adr_status in {"accepted", "proposed", "draft"}:
        return "supporting"
    return "supporting"


def build_entry(docs_root: Path, file_path: Path, existing_catalog: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
    rel_path = file_path.relative_to(docs_root).as_posix()
    existing = existing_catalog.get(rel_path, {})

    metadata: Dict[str, str] = {}
    adr_fields: Dict[str, str] = {}
    text = ""

    if file_path.suffix.lower() == ".md":
        text = file_path.read_text()
        lines = text.splitlines()
        metadata = parse_frontmatter(lines)
        metadata.update({k: v for k, v in parse_inline_metadata(lines).items() if v})
        comment_date = parse_comment_date(lines)
        if comment_date and "last_verified" not in metadata and "last_updated" not in metadata:
            metadata["last_verified"] = comment_date
        adr_fields = parse_adr_fields(lines)

    owner = metadata.get("owner") or existing.get("owner")
    last_verified = (
        metadata.get("last_verified")
        or metadata.get("last_updated")
        or existing.get("last_verified_or_updated")
        or adr_fields.get("adr_date")
    )

    return {
        "canonical_conflict_group": existing.get("canonical_conflict_group"),
        "freshness_risk": "low",
        "last_verified_or_updated": last_verified,
        "owner": owner,
        "path": rel_path,
        "status": derive_status(rel_path, text, metadata, adr_fields, existing),
        "type": derive_type(rel_path, existing),
    }


def render(entries: list[Dict[str, Any]]) -> str:
    return json.dumps(entries, indent=2, sort_keys=True) + "\n"


def write_or_check(path: Path, content: str, check: bool) -> int:
    current = path.read_text() if path.exists() else ""
    if check:
        if current != content:
            print(f"DOCS_CATALOG_DRIFT: {path}")
            return 1
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return 0


def main() -> int:
    args = parse_args()
    repo_root = Path(args.root).resolve()
    docs_root = repo_root / args.docs_root
    source_out = repo_root / args.source_out
    mirror_out = repo_root / args.mirror_out

    existing_catalog = load_existing_catalog(source_out)
    entries = [
        build_entry(docs_root, file_path, existing_catalog)
        for file_path in sorted(
            path
            for path in docs_root.rglob("*")
            if path.is_file() and path.relative_to(docs_root).as_posix() != "catalog.json"
        )
    ]
    entries.sort(key=lambda item: item["path"])
    rendered = render(entries)

    rc = 0
    rc |= write_or_check(source_out, rendered, args.check)
    rc |= write_or_check(mirror_out, rendered, args.check)
    if rc == 0:
        mode = "check" if args.check else "write"
        print(f"DOCS_CATALOG_BUILD_OK mode={mode} entries={len(entries)}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
