#!/usr/bin/env python3
"""compute_dependency_graph.py

Compute implementation order from spec depends_on frontmatter.

Usage:
  python3 compute_dependency_graph.py --specs-dir specs/ --format markdown
  python3 compute_dependency_graph.py --specs-dir specs/ --format json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Dict, List, Set

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")

AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")


def parse_frontmatter(md: str) -> dict:
    """Extract YAML frontmatter from markdown."""
    if not md.lstrip().startswith("---"):
        return {}
    parts = md.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        fm = yaml.safe_load(parts[1].strip()) or {}
        return fm if isinstance(fm, dict) else {}
    except Exception:
        return {}


def count_acs(md: str) -> int:
    """Count acceptance criteria in spec."""
    count = 0
    for line in md.splitlines():
        if line.strip().startswith(("- [ ]", "* [ ]")) and AC_ID_RE.search(line):
            count += 1
    return count


def load_specs(specs_dir: Path) -> Dict[str, dict]:
    """Load all specs with frontmatter. Returns {filename: info}."""
    specs: Dict[str, dict] = {}
    for f in sorted(specs_dir.glob("*_spec.md")):
        content = f.read_text(encoding="utf-8")
        fm = parse_frontmatter(content)
        specs[f.name] = {
            "path": str(f),
            "title": fm.get(
                "title", f.stem.replace("_spec", "").replace("-", " ").title()
            ),
            "depends_on": fm.get("depends_on", []),
            "ac_count": count_acs(content),
            "tier": fm.get("tier"),
        }
    return specs


def compute_tiers(specs: Dict[str, dict]) -> List[List[str]]:
    """Topological sort into tiers using Kahn's algorithm."""
    all_specs = set(specs.keys())
    deps: Dict[str, Set[str]] = {}

    for name, info in specs.items():
        dep_set: Set[str] = set()
        for dep in info.get("depends_on", []):
            dep_name = Path(dep).name if "/" in dep else dep
            if dep_name in all_specs:
                dep_set.add(dep_name)
        deps[name] = dep_set

    in_degree = {name: len(deps[name]) for name in all_specs}
    tiers: List[List[str]] = []
    remaining = set(all_specs)

    while remaining:
        tier = sorted(name for name in remaining if in_degree[name] == 0)
        if not tier:
            cycle_specs = sorted(remaining)
            print(f"ERROR: Dependency cycle detected among: {', '.join(cycle_specs)}")
            tiers.append(cycle_specs)
            break

        tiers.append(tier)
        remaining -= set(tier)

        for name in remaining:
            deps[name] -= set(tier)
            in_degree[name] = len(deps[name])

    return tiers


def format_markdown(tiers: List[List[str]], specs: Dict[str, dict]) -> str:
    """Format as markdown implementation order."""
    lines = ["# Implementation Order", ""]
    lines.append("Generated from `depends_on` frontmatter in spec files.")
    lines.append("")

    for i, tier in enumerate(tiers):
        lines.append(f"## Tier {i}")
        lines.append("")
        lines.append("| Spec | ACs | Title |")
        lines.append("|------|-----|-------|")
        for name in tier:
            info = specs.get(name, {})
            title = info.get("title", "")
            ac_count = info.get("ac_count", 0)
            lines.append(f"| {name} | {ac_count} | {title} |")
        lines.append("")

    total_acs = sum(info.get("ac_count", 0) for info in specs.values())
    lines.append(
        f"**Total**: {len(specs)} specs, {total_acs} ACs, {len(tiers)} tiers"
    )

    return "\n".join(lines)


def format_json_output(tiers: List[List[str]], specs: Dict[str, dict]) -> str:
    """Format as JSON."""
    output = {
        "tiers": [
            {
                "tier": i,
                "specs": [
                    {"name": name, **{k: v for k, v in specs.get(name, {}).items() if k != "path"}}
                    for name in tier
                ],
            }
            for i, tier in enumerate(tiers)
        ],
        "total_specs": len(specs),
        "total_acs": sum(info.get("ac_count", 0) for info in specs.values()),
        "total_tiers": len(tiers),
    }
    return json.dumps(output, indent=2, default=str)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Compute implementation order from spec dependencies."
    )
    ap.add_argument(
        "--specs-dir", type=str, required=True, help="Directory containing *_spec.md"
    )
    ap.add_argument(
        "--format", choices=["markdown", "json"], default="markdown"
    )
    ap.add_argument("--output", type=str, default=None, help="Output file")
    args = ap.parse_args()

    specs_dir = Path(args.specs_dir)
    if not specs_dir.is_dir():
        print(f"ERROR: directory not found: {specs_dir}")
        return 2

    specs = load_specs(specs_dir)
    if not specs:
        print("No spec files found.")
        return 0

    tiers = compute_tiers(specs)

    if args.format == "markdown":
        result = format_markdown(tiers, specs)
    else:
        result = format_json_output(tiers, specs)

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(result + "\n", encoding="utf-8")
        print(f"Written to {args.output}")
    else:
        print(result)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
