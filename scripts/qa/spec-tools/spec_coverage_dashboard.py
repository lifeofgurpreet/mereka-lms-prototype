#!/usr/bin/env python3
"""spec_coverage_dashboard.py — Compact spec coverage dashboard.

Reads testmap YAML files and generates a coverage dashboard showing:
- Per-spec AC coverage rates
- Automated/manual/monitoring/unmapped counts
- Overall system health
- Color-coded tiers (GREEN ≥80%, YELLOW 50-79%, RED <50%)

Usage:
  python3 spec_coverage_dashboard.py --specs-dir specs/ --testmaps-dir specs/testmaps/
  python3 spec_coverage_dashboard.py --testmaps-dir specs/testmaps/ --format json
  python3 spec_coverage_dashboard.py --testmaps-dir specs/testmaps/ --format markdown
"""
# @covers AC-002
# @spec: ci-cd-pipeline_spec.md

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")


@dataclass
class SpecStats:
    """Coverage statistics for a single spec."""

    spec_name: str
    total_acs: int = 0
    automated: int = 0
    manual: int = 0
    monitoring: int = 0
    unmapped: int = 0
    tier: Optional[int] = None

    @property
    def covered(self) -> int:
        """Total covered ACs (automated + manual + monitoring)."""
        return self.automated + self.manual + self.monitoring

    @property
    def coverage_rate(self) -> float:
        """Coverage rate as percentage."""
        if self.total_acs == 0:
            return 0.0
        return (self.covered / self.total_acs) * 100

    @property
    def coverage_tier(self) -> str:
        """Color tier: GREEN, YELLOW, or RED."""
        rate = self.coverage_rate
        if rate >= 80:
            return "GREEN"
        elif rate >= 50:
            return "YELLOW"
        else:
            return "RED"


@dataclass
class DashboardData:
    """Aggregated dashboard data."""

    total_specs: int = 0
    total_acs: int = 0
    total_automated: int = 0
    total_manual: int = 0
    total_monitoring: int = 0
    total_unmapped: int = 0
    spec_stats: List[SpecStats] = field(default_factory=list)

    @property
    def total_covered(self) -> int:
        return self.total_automated + self.total_manual + self.total_monitoring

    @property
    def overall_coverage_rate(self) -> float:
        if self.total_acs == 0:
            return 0.0
        return (self.total_covered / self.total_acs) * 100

    @property
    def green_count(self) -> int:
        return sum(1 for s in self.spec_stats if s.coverage_tier == "GREEN")

    @property
    def yellow_count(self) -> int:
        return sum(1 for s in self.spec_stats if s.coverage_tier == "YELLOW")

    @property
    def red_count(self) -> int:
        return sum(1 for s in self.spec_stats if s.coverage_tier == "RED")


def load_testmap(testmap_path: Path) -> SpecStats:
    """Load a testmap YAML and compute statistics."""
    data = yaml.safe_load(testmap_path.read_text(encoding="utf-8"))
    spec_name = data.get("spec", testmap_path.stem.replace(".testmap", ""))

    acs = data.get("acceptance_criteria", [])
    total_acs = len(acs)

    automated = 0
    manual = 0
    monitoring = 0
    unmapped = 0

    for ac in acs:
        verify_list = ac.get("verify", [])
        if not verify_list:
            unmapped += 1
            continue

        # Check verification types
        has_automated = False
        has_manual = False
        has_monitoring = False

        for v in verify_list:
            vtype = v.get("type", "")
            test_type = v.get("test_type", "")

            # Count as automated if type is automated or test_type suggests automation
            if vtype == "automated" or test_type in (
                "shell_verification",
                "unit",
                "integration",
                "contract",
            ):
                has_automated = True
            elif vtype == "manual":
                has_manual = True
            elif vtype == "monitoring":
                has_monitoring = True

        # Prioritize automated > manual > monitoring
        if has_automated:
            automated += 1
        elif has_manual:
            manual += 1
        elif has_monitoring:
            monitoring += 1
        else:
            unmapped += 1

    return SpecStats(
        spec_name=spec_name,
        total_acs=total_acs,
        automated=automated,
        manual=manual,
        monitoring=monitoring,
        unmapped=unmapped,
    )


def load_tier_mapping(specs_dir: Optional[Path]) -> Dict[str, int]:
    """Load tier information from spec frontmatter."""
    if not specs_dir or not specs_dir.exists():
        return {}

    tier_map = {}
    for spec_file in specs_dir.glob("*_spec.md"):
        try:
            content = spec_file.read_text(encoding="utf-8")
            # Parse frontmatter
            if not content.lstrip().startswith("---"):
                continue

            parts = content.split("---", 2)
            if len(parts) < 3:
                continue

            fm_raw = parts[1].strip()
            fm = yaml.safe_load(fm_raw)
            if not isinstance(fm, dict):
                continue

            # Extract tier from depends_on
            depends_on = fm.get("depends_on", [])
            if not depends_on:
                tier_map[spec_file.name] = 0
                continue

            # Infer tier from number of dependencies (heuristic)
            # This is simplified; ideally we'd parse IMPLEMENTATION_ORDER.md
            tier_map[spec_file.name] = len(depends_on)

        except Exception:
            continue

    return tier_map


def generate_dashboard(testmaps_dir: Path, specs_dir: Optional[Path]) -> DashboardData:
    """Generate dashboard data from testmap directory."""
    dashboard = DashboardData()

    # Load tier mapping
    tier_map = load_tier_mapping(specs_dir)

    # Load all testmaps
    spec_stats_list = []
    for testmap_file in sorted(testmaps_dir.glob("*.testmap.yml")):
        stats = load_testmap(testmap_file)

        # Try to map tier
        spec_md_name = stats.spec_name
        if not spec_md_name.endswith(".md"):
            spec_md_name += ".md"
        stats.tier = tier_map.get(spec_md_name)

        spec_stats_list.append(stats)

        # Aggregate totals
        dashboard.total_specs += 1
        dashboard.total_acs += stats.total_acs
        dashboard.total_automated += stats.automated
        dashboard.total_manual += stats.manual
        dashboard.total_monitoring += stats.monitoring
        dashboard.total_unmapped += stats.unmapped

    # Sort by coverage rate (highest first)
    spec_stats_list.sort(key=lambda s: s.coverage_rate, reverse=True)
    dashboard.spec_stats = spec_stats_list

    return dashboard


def format_text(dashboard: DashboardData) -> str:
    """Format dashboard as human-readable text."""
    lines = [
        "=== Spec Coverage Dashboard ===",
        f"{dashboard.total_specs} specs | {dashboard.total_acs} ACs | "
        f"{dashboard.total_automated} automated | {dashboard.total_manual} manual | "
        f"{dashboard.total_monitoring} monitoring | {dashboard.total_unmapped} unmapped",
        "",
        f"Overall coverage: {dashboard.overall_coverage_rate:.1f}%",
        "",
    ]

    # Table header
    lines.append(
        "Tier | Spec                                    | ACs | Auto | Man | Mon | Unmapped | Coverage"
    )
    lines.append(
        "-----|----------------------------------------|-----|------|-----|-----|----------|----------"
    )

    # Table rows
    for stats in dashboard.spec_stats:
        tier_str = f"{stats.tier:>3}" if stats.tier is not None else "  ?"
        spec_display = stats.spec_name.replace("_spec.md", "")[:38]
        lines.append(
            f"{tier_str:>4} | {spec_display:<38} | "
            f"{stats.total_acs:>3} | {stats.automated:>4} | {stats.manual:>3} | "
            f"{stats.monitoring:>3} | {stats.unmapped:>8} | {stats.coverage_rate:>7.1f}%"
        )

    # Coverage tier summary
    lines.append("")
    lines.append("Coverage tiers:")
    lines.append(f"  GREEN  (≥80%): {dashboard.green_count} specs")
    lines.append(f"  YELLOW (50-79%): {dashboard.yellow_count} specs")
    lines.append(f"  RED    (<50%): {dashboard.red_count} specs")

    return "\n".join(lines)


def format_json(dashboard: DashboardData) -> str:
    """Format dashboard as JSON."""
    output = {
        "summary": {
            "total_specs": dashboard.total_specs,
            "total_acs": dashboard.total_acs,
            "automated": dashboard.total_automated,
            "manual": dashboard.total_manual,
            "monitoring": dashboard.total_monitoring,
            "unmapped": dashboard.total_unmapped,
            "covered": dashboard.total_covered,
            "coverage_rate": round(dashboard.overall_coverage_rate, 2),
        },
        "coverage_tiers": {
            "green": dashboard.green_count,
            "yellow": dashboard.yellow_count,
            "red": dashboard.red_count,
        },
        "specs": [
            {
                "spec": s.spec_name,
                "tier": s.tier,
                "total_acs": s.total_acs,
                "automated": s.automated,
                "manual": s.manual,
                "monitoring": s.monitoring,
                "unmapped": s.unmapped,
                "coverage_rate": round(s.coverage_rate, 2),
                "coverage_tier": s.coverage_tier,
            }
            for s in dashboard.spec_stats
        ],
    }
    return json.dumps(output, indent=2)


def format_markdown(dashboard: DashboardData) -> str:
    """Format dashboard as GitHub-compatible markdown."""
    lines = [
        "# Spec Coverage Dashboard",
        "",
        f"**{dashboard.total_specs} specs** | "
        f"**{dashboard.total_acs} ACs** | "
        f"{dashboard.total_automated} automated | "
        f"{dashboard.total_manual} manual | "
        f"{dashboard.total_monitoring} monitoring | "
        f"{dashboard.total_unmapped} unmapped",
        "",
        f"**Overall coverage:** {dashboard.overall_coverage_rate:.1f}%",
        "",
        "## Coverage by Spec",
        "",
    ]

    # Table header
    lines.append(
        "| Tier | Spec | ACs | Auto | Man | Mon | Unmapped | Coverage |"
    )
    lines.append("|------|------|-----|------|-----|-----|----------|----------|")

    # Table rows
    for stats in dashboard.spec_stats:
        tier_str = f"{stats.tier}" if stats.tier is not None else "?"
        spec_display = stats.spec_name.replace("_spec.md", "")
        coverage_badge = (
            f"🟢 {stats.coverage_rate:.1f}%"
            if stats.coverage_tier == "GREEN"
            else f"🟡 {stats.coverage_rate:.1f}%"
            if stats.coverage_tier == "YELLOW"
            else f"🔴 {stats.coverage_rate:.1f}%"
        )
        lines.append(
            f"| {tier_str} | {spec_display} | "
            f"{stats.total_acs} | {stats.automated} | {stats.manual} | "
            f"{stats.monitoring} | {stats.unmapped} | {coverage_badge} |"
        )

    # Coverage tier summary
    lines.append("")
    lines.append("## Coverage Tiers")
    lines.append("")
    lines.append(f"- 🟢 **GREEN** (≥80%): {dashboard.green_count} specs")
    lines.append(f"- 🟡 **YELLOW** (50-79%): {dashboard.yellow_count} specs")
    lines.append(f"- 🔴 **RED** (<50%): {dashboard.red_count} specs")

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate spec coverage dashboard from testmap files."
    )
    ap.add_argument(
        "--testmaps-dir",
        type=str,
        required=True,
        help="Directory containing *.testmap.yml files",
    )
    ap.add_argument(
        "--specs-dir",
        type=str,
        default=None,
        help="Directory containing *_spec.md files (for tier info)",
    )
    ap.add_argument(
        "--format",
        choices=["text", "json", "markdown"],
        default="text",
        help="Output format (default: text)",
    )
    args = ap.parse_args()

    testmaps_dir = Path(args.testmaps_dir)
    if not testmaps_dir.exists():
        print(f"Error: testmaps directory not found: {testmaps_dir}")
        return 1

    specs_dir = Path(args.specs_dir) if args.specs_dir else None

    dashboard = generate_dashboard(testmaps_dir, specs_dir)

    if args.format == "text":
        print(format_text(dashboard))
    elif args.format == "json":
        print(format_json(dashboard))
    elif args.format == "markdown":
        print(format_markdown(dashboard))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
