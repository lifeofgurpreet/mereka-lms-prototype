#!/usr/bin/env python3
"""spec_coverage_report.py — Spec-to-test coverage report for Mereka LMS.

Categories each AC into:
- automated_exists: verify.type=automated AND verify.file exists on disk
- automated_planned: verify.type=automated but verify.file doesn't exist
- manual: verify.type=manual
- monitoring: verify.type=monitoring
- unmapped: AC in spec but absent from testmap
- no_testmap: Spec has no testmap file at all

Outputs: text, json, or markdown.
Exit code: 1 if coverage < --fail-under threshold, 0 otherwise.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")

AC_ID_RE = re.compile(r"\bAC-(\d{3,})\b")


@dataclass
class ACCoverage:
    ac_id: str
    category: str  # automated_exists, automated_planned, manual, monitoring, unmapped, no_testmap


@dataclass
class SpecCoverage:
    spec_name: str
    spec_path: str
    total_acs: int = 0
    automated_exists: int = 0
    automated_planned: int = 0
    manual: int = 0
    monitoring: int = 0
    unmapped: int = 0
    no_testmap: bool = False
    ac_details: list = field(default_factory=list)


def extract_ac_ids(md: str) -> list[str]:
    """Extract AC IDs from checkbox lines."""
    ids = []
    for line in md.splitlines():
        stripped = line.strip()
        if stripped.startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                ids.append(f"AC-{m.group(1)}")
    return ids


def find_testmap(spec_path: Path, testmaps_dir: Path) -> Optional[Path]:
    """Find testmap for a spec."""
    slug = spec_path.stem.replace("_spec", "")
    for ext in [".yaml", ".yml"]:
        candidate = testmaps_dir / f"{slug}_testmap{ext}"
        if candidate.exists():
            return candidate
    return None


def categorize_ac(ac_id: str, tm_index: dict, repo_root: Path) -> str:
    """Categorize an AC based on its testmap entry."""
    if ac_id not in tm_index:
        return "unmapped"

    item = tm_index[ac_id]
    verify = item.get("verify", [])
    if not isinstance(verify, list) or not verify:
        return "unmapped"

    # Use the "best" category: automated_exists > automated_planned > monitoring > manual
    has_auto_exists = False
    has_auto_planned = False
    has_monitoring = False
    has_manual = False

    for ve in verify:
        if not isinstance(ve, dict):
            continue
        vtype = ve.get("type", "")
        if vtype == "automated":
            vfile = ve.get("file", "")
            if vfile and (repo_root / vfile).exists():
                has_auto_exists = True
            else:
                has_auto_planned = True
        elif vtype == "monitoring":
            has_monitoring = True
        elif vtype == "manual":
            has_manual = True

    if has_auto_exists:
        return "automated_exists"
    if has_auto_planned:
        return "automated_planned"
    if has_monitoring:
        return "monitoring"
    if has_manual:
        return "manual"
    return "unmapped"


def analyze_spec(spec_path: Path, testmaps_dir: Path, repo_root: Path) -> SpecCoverage:
    """Analyze coverage for a single spec."""
    md = spec_path.read_text(encoding="utf-8")
    ac_ids = extract_ac_ids(md)
    slug = spec_path.stem.replace("_spec", "")

    cov = SpecCoverage(
        spec_name=slug,
        spec_path=str(spec_path),
        total_acs=len(ac_ids),
    )

    if not ac_ids:
        return cov

    testmap_path = find_testmap(spec_path, testmaps_dir)
    if not testmap_path:
        cov.no_testmap = True
        cov.unmapped = len(ac_ids)
        for ac_id in ac_ids:
            cov.ac_details.append(ACCoverage(ac_id, "no_testmap"))
        return cov

    data = yaml.safe_load(testmap_path.read_text(encoding="utf-8")) or {}
    ac_items = data.get("acceptance_criteria", [])
    tm_index = {}
    for item in ac_items:
        if isinstance(item, dict) and "id" in item:
            tm_index[str(item["id"]).strip()] = item

    for ac_id in ac_ids:
        cat = categorize_ac(ac_id, tm_index, repo_root)
        cov.ac_details.append(ACCoverage(ac_id, cat))
        if cat == "automated_exists":
            cov.automated_exists += 1
        elif cat == "automated_planned":
            cov.automated_planned += 1
        elif cat == "manual":
            cov.manual += 1
        elif cat == "monitoring":
            cov.monitoring += 1
        elif cat in ("unmapped", "no_testmap"):
            cov.unmapped += 1

    return cov


def format_text(specs: list[SpecCoverage]) -> str:
    """Format as aligned text table."""
    lines = []
    header = f"{'Spec':<45s} {'ACs':>4s} {'Auto✓':>6s} {'Planned':>8s} {'Manual':>7s} {'Monitor':>8s} {'Unmapped':>9s}"
    lines.append(header)
    lines.append("-" * len(header))

    total_acs = total_auto = total_planned = total_manual = total_monitor = total_unmapped = 0
    for s in specs:
        name = s.spec_name[:44]
        lines.append(
            f"{name:<45s} {s.total_acs:>4d} {s.automated_exists:>6d} {s.automated_planned:>8d} "
            f"{s.manual:>7d} {s.monitoring:>8d} {s.unmapped:>9d}"
        )
        total_acs += s.total_acs
        total_auto += s.automated_exists
        total_planned += s.automated_planned
        total_manual += s.manual
        total_monitor += s.monitoring
        total_unmapped += s.unmapped

    lines.append("-" * len(header))
    lines.append(
        f"{'TOTAL':<45s} {total_acs:>4d} {total_auto:>6d} {total_planned:>8d} "
        f"{total_manual:>7d} {total_monitor:>8d} {total_unmapped:>9d}"
    )

    mapped = total_acs - total_unmapped
    mapped_pct = (mapped / total_acs * 100) if total_acs else 0
    auto_pct = (total_auto / total_acs * 100) if total_acs else 0
    lines.append(
        f"\nCoverage: {mapped_pct:.1f}% mapped ({mapped}/{total_acs}) | "
        f"{auto_pct:.1f}% automated with existing files ({total_auto}/{total_acs})"
    )

    return "\n".join(lines)


def format_json(specs: list[SpecCoverage]) -> str:
    """Format as JSON."""
    total_acs = sum(s.total_acs for s in specs)
    total_auto = sum(s.automated_exists for s in specs)
    total_planned = sum(s.automated_planned for s in specs)
    total_manual = sum(s.manual for s in specs)
    total_monitor = sum(s.monitoring for s in specs)
    total_unmapped = sum(s.unmapped for s in specs)
    mapped = total_acs - total_unmapped

    output = {
        "summary": {
            "total_acs": total_acs,
            "mapped": mapped,
            "mapped_pct": round(mapped / total_acs * 100, 1) if total_acs else 0,
            "automated_exists": total_auto,
            "automated_planned": total_planned,
            "manual": total_manual,
            "monitoring": total_monitor,
            "unmapped": total_unmapped,
        },
        "specs": [
            {
                "name": s.spec_name,
                "path": s.spec_path,
                "total_acs": s.total_acs,
                "automated_exists": s.automated_exists,
                "automated_planned": s.automated_planned,
                "manual": s.manual,
                "monitoring": s.monitoring,
                "unmapped": s.unmapped,
                "no_testmap": s.no_testmap,
            }
            for s in specs
        ],
    }
    return json.dumps(output, indent=2)


def format_markdown(specs: list[SpecCoverage]) -> str:
    """Format as markdown table."""
    lines = ["# Spec Coverage Report", ""]
    lines.append("| Spec | ACs | Auto (exists) | Auto (planned) | Manual | Monitor | Unmapped |")
    lines.append("|------|-----|---------------|----------------|--------|---------|----------|")

    total_acs = total_auto = total_planned = total_manual = total_monitor = total_unmapped = 0
    for s in specs:
        lines.append(
            f"| {s.spec_name} | {s.total_acs} | {s.automated_exists} | {s.automated_planned} "
            f"| {s.manual} | {s.monitoring} | {s.unmapped} |"
        )
        total_acs += s.total_acs
        total_auto += s.automated_exists
        total_planned += s.automated_planned
        total_manual += s.manual
        total_monitor += s.monitoring
        total_unmapped += s.unmapped

    lines.append(
        f"| **TOTAL** | **{total_acs}** | **{total_auto}** | **{total_planned}** "
        f"| **{total_manual}** | **{total_monitor}** | **{total_unmapped}** |"
    )

    mapped = total_acs - total_unmapped
    mapped_pct = (mapped / total_acs * 100) if total_acs else 0
    auto_pct = (total_auto / total_acs * 100) if total_acs else 0
    lines.append("")
    lines.append(
        f"**Coverage**: {mapped_pct:.1f}% mapped ({mapped}/{total_acs}) | "
        f"{auto_pct:.1f}% automated with existing files ({total_auto}/{total_acs})"
    )

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Spec-to-test coverage report.")
    ap.add_argument("--specs-dir", type=str, default="specs/", help="Directory containing *_spec.md files")
    ap.add_argument("--testmaps-dir", type=str, default="specs/testmaps/", help="Directory containing testmaps")
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root for resolving file paths")
    ap.add_argument("--format", choices=["text", "json", "markdown"], default="text", help="Output format")
    ap.add_argument("--output", type=str, default=None, help="Write output to file instead of stdout")
    ap.add_argument("--fail-under", type=float, default=0, help="Fail if mapped%% < threshold")
    args = ap.parse_args()

    specs_dir = Path(args.specs_dir)
    testmaps_dir = Path(args.testmaps_dir)
    repo_root = Path(args.repo_root).resolve()

    if not specs_dir.is_dir():
        print(f"ERROR: specs directory not found: {specs_dir}")
        return 2

    spec_files = sorted(specs_dir.glob("*_spec.md"))
    if not spec_files:
        print("No *_spec.md files found.")
        return 0

    results = []
    for f in spec_files:
        cov = analyze_spec(f, testmaps_dir, repo_root)
        if cov.total_acs > 0:
            results.append(cov)

    if args.format == "json":
        output = format_json(results)
    elif args.format == "markdown":
        output = format_markdown(results)
    else:
        output = format_text(results)

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n", encoding="utf-8")
        print(f"Report written to {args.output}")
    else:
        print(output)

    # Check fail-under threshold
    total_acs = sum(s.total_acs for s in results)
    total_unmapped = sum(s.unmapped for s in results)
    mapped = total_acs - total_unmapped
    mapped_pct = (mapped / total_acs * 100) if total_acs else 0

    if args.fail_under > 0 and mapped_pct < args.fail_under:
        print(f"\nFAIL: Coverage {mapped_pct:.1f}% < threshold {args.fail_under}%")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
