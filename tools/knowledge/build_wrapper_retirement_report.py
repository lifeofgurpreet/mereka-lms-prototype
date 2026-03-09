#!/usr/bin/env python3
"""Build the Wave 5 machine-readable wrapper retirement report."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.knowledge_model import classify_path


EXCLUDE_GLOBS = [
    ".git",
    "node_modules",
    "generated",
    "specs/_generated",
    "docs/_generated",
]


def load_catalog(repo_root: Path) -> list[dict]:
    catalog = json.loads((repo_root / "generated" / "catalogs" / "knowledge-catalog.json").read_text())
    return catalog.get("entries", [])


def read_frontmatter(path: Path) -> dict:
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}
    parts = text.split("---\n", 2)
    if len(parts) < 3:
        return {}
    return yaml.safe_load(parts[1]) or {}


def canonical_target(wrapper_path: Path) -> str:
    frontmatter = read_frontmatter(wrapper_path)
    target = frontmatter.get("superseded_by")
    if target:
        return str(target)
    match = re.search(r"Superseded by:\s*([^\n`]+)", wrapper_path.read_text())
    if match:
        return match.group(1).strip()
    return ""


def live_references(repo_root: Path, wrapper_rel: str, canonical_rel: str) -> list[str]:
    cmd = ["rg", "-n", "-F", wrapper_rel, str(repo_root)]
    for glob in EXCLUDE_GLOBS:
        cmd.extend(["-g", f"!{glob}/**"])
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    hits = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        path_part = line.split(":", 1)[0]
        rel_path = str(Path(path_part).resolve().relative_to(repo_root))
        if rel_path == wrapper_rel:
            continue
        if rel_path == canonical_rel:
            continue
        hits.append(line.replace(str(repo_root) + "/", ""))
    return sorted(set(hits))


def wrapper_status(canonical_exists: bool, ref_count: int) -> str:
    if not canonical_exists:
        return "suspicious"
    if ref_count == 0:
        return "safe_to_retire"
    if ref_count <= 3:
        return "active_but_suspicious"
    return "active_and_justified"


def build_report(repo_root: Path) -> dict:
    wrappers = [
        entry
        for entry in load_catalog(repo_root)
        if entry.get("classification") == "compatibility"
    ]
    entries = []
    summary = {"active_and_justified": 0, "active_but_suspicious": 0, "safe_to_retire": 0, "suspicious": 0}

    for wrapper in sorted(wrappers, key=lambda item: item["path"]):
        wrapper_rel = wrapper["path"]
        wrapper_path = repo_root / wrapper_rel
        canonical_rel = canonical_target(wrapper_path)
        canonical_exists = bool(canonical_rel) and (repo_root / canonical_rel).exists()
        refs = live_references(repo_root, wrapper_rel, canonical_rel)
        status = wrapper_status(canonical_exists, len(refs))
        summary[status] += 1
        entries.append(
            {
                "wrapper_path": wrapper_rel,
                "canonical_target": canonical_rel,
                "canonical_exists": canonical_exists,
                "wrapper_lane": classify_path(wrapper_path, repo_root).get("lane"),
                "live_reference_count": len(refs),
                "status": status,
                "sample_live_references": refs[:10],
            }
        )

    return {
        "generated_by": "tools/knowledge/build_wrapper_retirement_report.py",
        "wrapper_count": len(entries),
        "status_counts": summary,
        "entries": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="generated/knowledge/wrapper-retirement-report.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    report = build_report(repo_root)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("WRAPPER_RETIREMENT_REPORT_DRIFT")
        print("WRAPPER_RETIREMENT_REPORT_OK mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print("WRAPPER_RETIREMENT_REPORT_OK mode=write")


if __name__ == "__main__":
    main()
