#!/usr/bin/env python3
"""Shared spec lane and frontmatter helpers for Wave 3 tooling."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
HEADING_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)
LEGACY_STATUS_VALUES = {"completed", "in_progress", "deferred"}
LANE_ORDER = ("normative", "proposal", "plan", "testplan")

REQUIRED_FIELDS_BY_LANE: dict[str, dict[str, tuple[str, ...]]] = {
    "normative": {
        "id": ("id",),
        "title": ("title",),
        "status": ("status",),
        "spec_class": ("spec_class",),
        "owner": ("owner",),
        "created": ("created",),
        "last_reviewed": ("last_reviewed",),
        "review_due": ("review_due",),
        "domain": ("domain",),
        "normativity": ("normativity",),
        "summary": ("summary",),
    },
    "proposal": {
        "id": ("id",),
        "title": ("title",),
        "status": ("status",),
        "spec_class": ("spec_class",),
        "owner": ("owner",),
        "created": ("created",),
        "last_reviewed": ("last_reviewed",),
        "review_due": ("review_due",),
        "domain": ("domain",),
        "normativity": ("normativity",),
        "summary": ("summary",),
    },
    "plan": {
        "id_or_spec": ("id", "spec", "source_spec"),
        "status": ("status",),
        "last_reviewed_or_last_updated": ("last_reviewed", "last_updated", "updated"),
    },
    "testplan": {
        "spec": ("spec", "source_spec"),
        "plan": ("plan", "source_plan"),
        "status": ("status",),
        "last_reviewed_or_last_updated": ("last_reviewed", "last_updated", "updated"),
    },
}


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text()
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    data = yaml.safe_load(match.group(1)) or {}
    return data if isinstance(data, dict) else {}


def read_title(path: Path) -> str:
    match = HEADING_RE.search(path.read_text())
    return match.group(1).strip() if match else path.stem


def pick(frontmatter: dict, *keys: str) -> object:
    for key in keys:
        value = frontmatter.get(key)
        if value not in (None, "", []):
            return value
    return None


def has_any(frontmatter: dict, keys: tuple[str, ...]) -> bool:
    return any(frontmatter.get(key) not in (None, "", []) for key in keys)


def missing_required_fields(frontmatter: dict, lane: str) -> list[str]:
    return [
        label
        for label, keys in REQUIRED_FIELDS_BY_LANE[lane].items()
        if not has_any(frontmatter, keys)
    ]


def relative_path(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


def classify_lane(path: Path, repo_root: Path) -> str | None:
    rel_path = relative_path(path, repo_root)
    if path.parent == repo_root / "specs" and path.name.endswith("_spec.md"):
        return "normative"
    if rel_path.startswith("specs/proposals/") and path.name.endswith("_spec.md"):
        return "proposal"
    if rel_path.startswith("specs/plans/") and path.name.endswith("_plan.md"):
        return "plan"
    if rel_path.startswith("specs/plans/") and path.name.endswith("_testplan.md"):
        return "testplan"
    return None


def iter_lane_files(repo_root: Path) -> list[tuple[str, Path]]:
    specs_root = repo_root / "specs"
    collected: list[tuple[str, Path]] = []
    patterns = {
        "normative": sorted(specs_root.glob("*_spec.md")),
        "proposal": sorted((specs_root / "proposals").rglob("*_spec.md")),
        "plan": sorted((specs_root / "plans").rglob("*_plan.md")),
        "testplan": sorted((specs_root / "plans").rglob("*_testplan.md")),
    }
    for lane in LANE_ORDER:
        for path in patterns[lane]:
            if path.is_file():
                collected.append((lane, path))
    return collected


def inferred_spec_class(lane: str, frontmatter: dict) -> object:
    if lane == "proposal":
        return pick(frontmatter, "spec_class", "type") or "proposal"
    if lane in {"plan", "testplan"}:
        return pick(frontmatter, "spec_class", "type") or "plan"
    return pick(frontmatter, "spec_class", "type")


def inferred_normativity(lane: str, frontmatter: dict) -> object:
    if lane == "proposal":
        return pick(frontmatter, "normativity", "vehicle") or "proposed"
    if lane in {"plan", "testplan"}:
        return pick(frontmatter, "normativity", "vehicle") or "planning"
    return pick(frontmatter, "normativity", "vehicle")
