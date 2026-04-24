#!/usr/bin/env python3
"""Build the Wave 4 compatibility-wrapper retirement ledger."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.knowledge_model import parse_frontmatter


BODY_SUPERSEDED_RE = re.compile(r"Superseded by:\s*([^\s]+)")


def load_catalog(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"{path} must be a JSON object")
    return data


def canonical_target(path: Path, repo_root: Path) -> str:
    frontmatter = parse_frontmatter(path)
    target = str(frontmatter.get("superseded_by") or "").strip()
    if target:
        return target
    match = BODY_SUPERSEDED_RE.search(path.read_text())
    if match:
        raw = match.group(1).strip()
        return raw if raw.startswith("specs/") else f"specs/{raw}"
    raise ValueError(f"Wrapper missing canonical target: {path.relative_to(repo_root)}")


def live_reference_count(wrapper_rel: str, repo_root: Path) -> int:
    wrapper_name = Path(wrapper_rel).name
    cmd = [
        "rg",
        "-n",
        "-F",
        wrapper_name,
        str(repo_root),
        "--glob",
        f"!{wrapper_rel}",
        "--glob",
        "!generated/**",
        "--glob",
        "!docs/catalog.json",
        "--glob",
        "!generated/catalogs/**",
        "--glob",
        "!specs/catalog.json",
        "--glob",
        "!specs/_generated/**",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return len([line for line in result.stdout.splitlines() if line.strip()])


def build_markdown(repo_root: Path) -> str:
    catalog = load_catalog(repo_root / "generated" / "catalogs" / "knowledge-catalog.json")
    wrappers = [entry for entry in catalog.get("entries", []) if entry.get("classification") == "compatibility"]
    wrappers.sort(key=lambda item: item["path"])

    lines = [
        "# Wave 4 Wrapper Retirement Ledger",
        "",
        "Compatibility wrappers remain only where path stability still matters.",
        "",
        "| Wrapper | Canonical target | Non-generated live refs | Status | Retirement note |",
        "|---|---|---:|---|---|",
    ]
    for entry in wrappers:
        wrapper_path = entry["path"]
        target = canonical_target(repo_root / wrapper_path, repo_root)
        refs = live_reference_count(wrapper_path, repo_root)
        status = "retain" if refs > 0 else "retire_candidate"
        note = (
            "Active downstream references still exist"
            if refs > 0
            else "No remaining non-generated live references detected"
        )
        lines.append(f"| `{wrapper_path}` | `{target}` | {refs} | {status} | {note} |")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument(
        "--output",
        default="docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    rendered = build_markdown(repo_root).rstrip() + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("WRAPPER_RETIREMENT_LEDGER_DRIFT")
        print("WRAPPER_RETIREMENT_LEDGER_OK mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print("WRAPPER_RETIREMENT_LEDGER_OK mode=write")


if __name__ == "__main__":
    main()
