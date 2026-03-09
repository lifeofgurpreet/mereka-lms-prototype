#!/usr/bin/env python3
"""Shared knowledge control-plane helpers spanning docs and specs."""

from __future__ import annotations

import re
from pathlib import Path

import yaml


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
HEADING_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def relative_path(path: Path, repo_root: Path) -> str:
    return path.relative_to(repo_root).as_posix()


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


def classify_specs_lane(path: Path, repo_root: Path, frontmatter: dict | None = None) -> tuple[str, str]:
    rel = relative_path(path, repo_root)
    fm = frontmatter or {}
    spec_class = str(fm.get("spec_class") or "")
    normativity = str(fm.get("normativity") or "")

    if path.parent == repo_root / "specs" and path.name.endswith("_spec.md"):
        if spec_class == "generated" or normativity == "generated":
            return "normative", "compatibility"
        return "normative", "canonical"
    if rel.startswith("specs/proposals/") and path.name.endswith("_spec.md"):
        return "proposal", "supporting"
    if rel.startswith("specs/plans/") and path.name.endswith("_plan.md"):
        return "plan", "supporting"
    if rel.startswith("specs/plans/") and path.name.endswith("_testplan.md"):
        return "testplan", "supporting"
    if rel.startswith("specs/_generated/"):
        return "generated", "generated"
    if rel.startswith("specs/templates/") or rel.startswith("specs/standards/"):
        return "reference", "supporting"
    if rel.startswith("specs/testmaps/"):
        return "evidence", "supporting"
    return "other", "supporting"


def classify_docs_lane(path: Path, repo_root: Path) -> tuple[str, str]:
    rel = relative_path(path, repo_root)
    docs_rel = rel.removeprefix("docs/")

    if docs_rel in {"README.md", "CONTRIBUTING.md", "catalog.json"} or docs_rel.endswith("/INDEX.md"):
        return "index", "canonical"
    if docs_rel.startswith("_generated/"):
        return "generated", "generated"
    if docs_rel.startswith("archive/"):
        return "archive", "archival"
    if docs_rel.startswith("meta/docs-program/"):
        return "review", "supporting"
    if docs_rel.startswith(("ops/", "operations/", "runbooks/")):
        return "runbook", "supporting"
    if docs_rel.startswith(("concepts/", "architecture/", "reference/", "guides/", "branding/", "onboarding/")):
        return "concept", "supporting"
    if docs_rel.startswith("evidence/"):
        return "evidence", "supporting"
    if docs_rel.startswith("adr/"):
        return "adr", "supporting"
    return "other", "supporting"


def classify_path(path: Path, repo_root: Path) -> dict[str, str]:
    rel = relative_path(path, repo_root)
    frontmatter = parse_frontmatter(path) if path.suffix == ".md" else {}

    if rel.startswith("specs/"):
        lane, classification = classify_specs_lane(path, repo_root, frontmatter)
        root = "specs"
    elif rel.startswith("docs/"):
        lane, classification = classify_docs_lane(path, repo_root)
        root = "docs"
    else:
        root = "other"
        lane = "other"
        classification = "supporting"

    status = str(frontmatter.get("status") or "")
    owner = str(frontmatter.get("owner") or "")
    title = str(frontmatter.get("title") or read_title(path))
    return {
        "root": root,
        "lane": lane,
        "classification": classification,
        "status": status,
        "owner": owner,
        "title": title,
        "path": rel,
    }
