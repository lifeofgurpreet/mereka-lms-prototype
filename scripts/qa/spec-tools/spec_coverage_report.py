#!/usr/bin/env python3
"""spec_coverage_report.py — Spec-to-test coverage report for Mereka LMS.

Uses @covers annotations in source files as the source of truth.
Manual/monitoring entries from specs/manual_verifications.yaml.

Categories each AC into:
- automated: has @covers annotation AND file exists on disk
- manual: in manual_verifications.yaml with type=manual
- monitoring: in manual_verifications.yaml with type=monitoring
- unmapped: AC in spec but no @covers and no manual entry

Outputs: text, json, or markdown.
Exit code: 1 if coverage < --fail-under threshold, 0 otherwise.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")

COVERS_RE = re.compile(r"(?://|#)\s*@covers\s+((?:AC-[A-Z]*-?\d+(?:\s*,\s*)*)+)")
SPEC_RE = re.compile(r"(?://|#)\s*@spec:\s*(\S+)")
AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")
SCAN_EXTENSIONS = {".sh", ".py", ".ts", ".js", ".tsx", ".jsx", ".yaml", ".yml"}


@dataclass
class SpecCoverage:
    spec_name: str
    spec_path: str
    total_acs: int = 0
    automated: int = 0
    manual: int = 0
    monitoring: int = 0
    unmapped: int = 0


def extract_ac_ids(md: str) -> List[str]:
    """Extract AC IDs from checkbox lines."""
    ids = []
    for line in md.splitlines():
        stripped = line.strip()
        if stripped.startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                ids.append(m.group(1))
    return ids


def scan_dirs_for_covers(dirs: List[Path]) -> Dict[Tuple[str, str], List[Path]]:
    """Scan directories for @covers annotations.

    Returns {(spec_filename, ac_id): [file_paths]}.
    The spec_filename comes from @spec: annotations in the same file.
    Files without @spec: use empty string as spec key (matches any spec).
    """
    result: Dict[Tuple[str, str], List[Path]] = {}
    for d in dirs:
        if not d.exists():
            continue
        for f in sorted(d.rglob("*")):
            if not f.is_file() or f.suffix not in SCAN_EXTENSIONS:
                continue
            try:
                content = f.read_text(encoding="utf-8")
            except Exception:
                continue
            # Extract @spec: annotation for scoping
            spec_name = ""
            for sm in SPEC_RE.finditer(content):
                spec_name = sm.group(1)
            for m in COVERS_RE.finditer(content):
                ids = [s.strip() for s in m.group(1).split(",") if s.strip()]
                for raw_id in ids:
                    ac_match = AC_ID_RE.match(raw_id)
                    if ac_match:
                        ac_id = ac_match.group(1)
                        result.setdefault((spec_name, ac_id), []).append(f)
    return result


def load_manual_entries(manual_file: Optional[Path]) -> Dict[Tuple[str, str], dict]:
    """Load all manual/monitoring entries. Returns {(spec_filename, ac_id): entry}."""
    if not manual_file or not manual_file.exists():
        return {}
    data = yaml.safe_load(manual_file.read_text(encoding="utf-8")) or {}
    entries = data.get("entries", [])
    result: Dict[Tuple[str, str], dict] = {}
    for entry in entries:
        if isinstance(entry, dict) and "id" in entry:
            spec = entry.get("spec", "")
            result[(spec, entry["id"])] = entry
    return result


def is_ac_automated(
    ac_id: str,
    spec_filename: str,
    automated_index: Dict[Tuple[str, str], List[Path]],
) -> bool:
    """Check if an AC is covered by @covers annotations scoped to the right spec.

    Matching rules:
    1. Exact match: (spec_filename, ac_id) — file has @spec: matching this spec
    2. Unscoped match: ("", ac_id) — file has @covers but no @spec:
    3. Prefixed AC IDs (e.g. AC-TCR-001) are globally unique, match any @spec:
    """
    # Prefixed AC IDs (like AC-TCR-001, AC-HUB-005) are globally unique
    has_prefix = bool(re.match(r"AC-[A-Z]+-\d+", ac_id))

    if has_prefix:
        # Globally unique — match any @spec: value
        for (_, indexed_ac), paths in automated_index.items():
            if indexed_ac == ac_id and paths:
                return True
        return False

    # Non-prefixed (like AC-001) — must match by @spec: scope
    # Exact spec match
    if (spec_filename, ac_id) in automated_index:
        return True
    # Unscoped match (file had no @spec:)
    if ("", ac_id) in automated_index:
        return True
    return False


def find_manual_entry(
    ac_id: str,
    spec_filename: str,
    manual_index: Dict[Tuple[str, str], dict],
) -> Optional[dict]:
    """Find a manual entry scoped to the spec. Handles prefixed AC IDs as global."""
    has_prefix = bool(re.match(r"AC-[A-Z]+-\d+", ac_id))

    if has_prefix:
        # Globally unique — match any spec
        for (_, indexed_ac), entry in manual_index.items():
            if indexed_ac == ac_id:
                return entry
        return None

    # Non-prefixed — exact spec match, then unscoped
    if (spec_filename, ac_id) in manual_index:
        return manual_index[(spec_filename, ac_id)]
    if ("", ac_id) in manual_index:
        return manual_index[("", ac_id)]
    return None


def categorize_ac(
    ac_id: str,
    spec_filename: str,
    automated_index: Dict[Tuple[str, str], List[Path]],
    manual_index: Dict[Tuple[str, str], dict],
) -> str:
    """Categorize an AC based on annotations and manual entries."""
    if is_ac_automated(ac_id, spec_filename, automated_index):
        return "automated"

    me = find_manual_entry(ac_id, spec_filename, manual_index)
    if me is not None:
        verify = me.get("verify", [])
        for v in verify:
            vtype = v.get("type", "")
            if vtype == "monitoring":
                return "monitoring"
            if vtype == "manual":
                return "manual"
        return "manual"

    return "unmapped"


def analyze_spec(
    spec_path: Path,
    automated_index: Dict[Tuple[str, str], List[Path]],
    manual_index: Dict[str, dict],
) -> SpecCoverage:
    """Analyze coverage for a single spec."""
    md = spec_path.read_text(encoding="utf-8")
    ac_ids = extract_ac_ids(md)
    slug = spec_path.stem.replace("_spec", "")
    spec_filename = spec_path.name

    cov = SpecCoverage(
        spec_name=slug,
        spec_path=str(spec_path),
        total_acs=len(ac_ids),
    )

    for ac_id in ac_ids:
        cat = categorize_ac(ac_id, spec_filename, automated_index, manual_index)
        if cat == "automated":
            cov.automated += 1
        elif cat == "manual":
            cov.manual += 1
        elif cat == "monitoring":
            cov.monitoring += 1
        else:
            cov.unmapped += 1

    return cov


def format_text(specs: List[SpecCoverage]) -> str:
    """Format as aligned text table."""
    lines = []
    header = f"{'Spec':<45s} {'ACs':>4s} {'Auto':>6s} {'Manual':>7s} {'Monitor':>8s} {'Unmapped':>9s}"
    lines.append(header)
    lines.append("-" * len(header))

    total_acs = total_auto = total_manual = total_monitor = total_unmapped = 0
    for s in specs:
        name = s.spec_name[:44]
        lines.append(
            f"{name:<45s} {s.total_acs:>4d} {s.automated:>6d} "
            f"{s.manual:>7d} {s.monitoring:>8d} {s.unmapped:>9d}"
        )
        total_acs += s.total_acs
        total_auto += s.automated
        total_manual += s.manual
        total_monitor += s.monitoring
        total_unmapped += s.unmapped

    lines.append("-" * len(header))
    lines.append(
        f"{'TOTAL':<45s} {total_acs:>4d} {total_auto:>6d} "
        f"{total_manual:>7d} {total_monitor:>8d} {total_unmapped:>9d}"
    )

    mapped = total_acs - total_unmapped
    mapped_pct = (mapped / total_acs * 100) if total_acs else 0
    auto_pct = (total_auto / total_acs * 100) if total_acs else 0
    lines.append(
        f"\nCoverage: {mapped_pct:.1f}% mapped ({mapped}/{total_acs}) | "
        f"{auto_pct:.1f}% automated ({total_auto}/{total_acs})"
    )

    return "\n".join(lines)


def format_json(specs: List[SpecCoverage]) -> str:
    """Format as JSON."""
    total_acs = sum(s.total_acs for s in specs)
    total_auto = sum(s.automated for s in specs)
    total_manual = sum(s.manual for s in specs)
    total_monitor = sum(s.monitoring for s in specs)
    total_unmapped = sum(s.unmapped for s in specs)
    mapped = total_acs - total_unmapped

    output = {
        "summary": {
            "total_acs": total_acs,
            "mapped": mapped,
            "mapped_pct": round(mapped / total_acs * 100, 1) if total_acs else 0,
            "automated": total_auto,
            "manual": total_manual,
            "monitoring": total_monitor,
            "unmapped": total_unmapped,
        },
        "specs": [
            {
                "name": s.spec_name,
                "path": s.spec_path,
                "total_acs": s.total_acs,
                "automated": s.automated,
                "manual": s.manual,
                "monitoring": s.monitoring,
                "unmapped": s.unmapped,
            }
            for s in specs
        ],
    }
    return json.dumps(output, indent=2)


def format_markdown(specs: List[SpecCoverage]) -> str:
    """Format as markdown table."""
    lines = ["# Spec Coverage Report", ""]
    lines.append("| Spec | ACs | Automated | Manual | Monitor | Unmapped |")
    lines.append("|------|-----|-----------|--------|---------|----------|")

    total_acs = total_auto = total_manual = total_monitor = total_unmapped = 0
    for s in specs:
        lines.append(
            f"| {s.spec_name} | {s.total_acs} | {s.automated} "
            f"| {s.manual} | {s.monitoring} | {s.unmapped} |"
        )
        total_acs += s.total_acs
        total_auto += s.automated
        total_manual += s.manual
        total_monitor += s.monitoring
        total_unmapped += s.unmapped

    lines.append(
        f"| **TOTAL** | **{total_acs}** | **{total_auto}** "
        f"| **{total_manual}** | **{total_monitor}** | **{total_unmapped}** |"
    )

    mapped = total_acs - total_unmapped
    mapped_pct = (mapped / total_acs * 100) if total_acs else 0
    auto_pct = (total_auto / total_acs * 100) if total_acs else 0
    lines.append("")
    lines.append(
        f"**Coverage**: {mapped_pct:.1f}% mapped ({mapped}/{total_acs}) | "
        f"{auto_pct:.1f}% automated ({total_auto}/{total_acs})"
    )

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Spec-to-test coverage report (annotation-based).")
    ap.add_argument("--specs-dir", type=str, default="specs/", help="Specs directory")
    ap.add_argument(
        "--scan-dirs",
        nargs="+",
        default=["scripts/", "tests/", "deploy/", "infrastructure/", "services/", ".github/workflows/"],
        help="Directories to scan for @covers",
    )
    ap.add_argument(
        "--manual-file",
        type=str,
        default="specs/manual_verifications.yaml",
        help="Path to manual_verifications.yaml",
    )
    ap.add_argument("--repo-root", type=str, default=".", help="Repo root")
    ap.add_argument("--format", choices=["text", "json", "markdown"], default="text")
    ap.add_argument("--output", type=str, default=None, help="Write to file")
    ap.add_argument("--fail-under", type=float, default=0, help="Fail if mapped%% < threshold")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    specs_dir = Path(args.specs_dir)
    scan_dirs = [repo_root / d for d in args.scan_dirs]
    manual_file = Path(args.manual_file)
    if not manual_file.is_absolute():
        manual_file = repo_root / manual_file

    if not specs_dir.is_dir():
        print(f"ERROR: specs directory not found: {specs_dir}")
        return 2

    spec_files = sorted(specs_dir.glob("*_spec.md"))
    if not spec_files:
        print("No *_spec.md files found.")
        return 0

    # Build indexes
    automated_index = scan_dirs_for_covers(scan_dirs)
    manual_index = load_manual_entries(manual_file)

    results = []
    for f in spec_files:
        cov = analyze_spec(f, automated_index, manual_index)
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
