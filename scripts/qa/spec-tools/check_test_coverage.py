#!/usr/bin/env python3
"""check_test_coverage.py

Contract-to-Test Coverage Tool using @covers annotations.

Enforces Gate C: Every AC must have @covers annotation in code or manual entry.

Usage:
  python3 check_test_coverage.py <project_root> [--threshold 80] [--scan-dirs tests/ scripts/] [--verbose]

Dependencies:
  pip install pyyaml
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

COVERS_RE = re.compile(r"(?://|#)\s*@covers\s+((?:AC-[A-Z]*-?\d+(?:\s*,\s*)*)+)")
SPEC_RE = re.compile(r"(?://|#)\s*@spec:\s*(\S+)")
AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")

SCAN_EXTENSIONS = {".sh", ".py", ".ts", ".js", ".tsx", ".jsx", ".yaml", ".yml"}
SKIP_FILES = {"INDEX.md", "README.md", "_TEMPLATE.md"}


def scan_file_for_covers(path: Path) -> dict[str, str]:
    """Returns {ac_id: spec_name_or_empty} for all @covers annotations in file."""
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        return {}

    spec_name = None
    for m in SPEC_RE.finditer(content):
        spec_name = m.group(1)

    covers: dict[str, str] = {}
    for m in COVERS_RE.finditer(content):
        ids = [s.strip() for s in m.group(1).split(",") if s.strip()]
        for raw_id in ids:
            ac_match = AC_ID_RE.match(raw_id)
            if ac_match:
                covers[ac_match.group(1)] = spec_name or ""
    return covers


def scan_dirs_for_covers(dirs: list[Path]) -> dict[str, list[tuple[Path, str]]]:
    """Scan directories for @covers annotations.

    Returns {ac_id: [(file_path, spec_name), ...]}
    """
    result: dict[str, list[tuple[Path, str]]] = {}
    for d in dirs:
        if not d.exists():
            continue
        for f in sorted(d.rglob("*")):
            if not f.is_file() or f.suffix not in SCAN_EXTENSIONS:
                continue
            covers = scan_file_for_covers(f)
            for ac_id, spec_name in covers.items():
                result.setdefault(ac_id, []).append((f, spec_name))
    return result


def extract_ac_ids_from_spec(spec_path: Path) -> list[str]:
    """Extract AC IDs from checkbox lines in a spec."""
    content = spec_path.read_text(encoding="utf-8")
    ids = []
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith(("- [ ]", "* [ ]")):
            m = AC_ID_RE.search(line)
            if m:
                ids.append(m.group(1))
    return ids


def find_spec_files(specs_root: Path) -> list[Path]:
    """Find all spec markdown files."""
    if not specs_root.exists() or not specs_root.is_dir():
        return []
    return sorted(
        f
        for f in specs_root.rglob("*.md")
        if f.is_file()
        and f.name not in SKIP_FILES
        and ("_spec" in f.name or "specs" in f.parts)
    )


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Check @covers annotation coverage for specs."
    )
    ap.add_argument("project_root", type=str, help="Path to the project root")
    ap.add_argument(
        "--threshold", type=int, default=80, help="Minimum coverage %% (default: 80)"
    )
    ap.add_argument(
        "--specs-dir", type=str, default="specs/", help="Specs directory"
    )
    ap.add_argument(
        "--scan-dirs",
        nargs="+",
        default=["tests/", "scripts/", "deploy/", "infrastructure/", "services/", ".github/workflows/"],
        help="Directories to scan for @covers",
    )
    ap.add_argument(
        "--verbose", action="store_true", help="Show per-AC details"
    )
    args = ap.parse_args()

    project_root = Path(args.project_root).resolve()
    if not project_root.exists():
        print(f"ERROR: project_root not found: {project_root}")
        return 2

    specs_root = project_root / args.specs_dir
    scan_dirs = [project_root / d for d in args.scan_dirs]

    spec_files = find_spec_files(specs_root)
    if not spec_files:
        print(f"No spec files found in {specs_root}")
        return 0

    all_covers = scan_dirs_for_covers(scan_dirs)

    total_acs = 0
    covered_acs = 0

    print("=== @covers Annotation Coverage Report ===\n")

    for spec_file in spec_files:
        ac_ids = extract_ac_ids_from_spec(spec_file)
        if not ac_ids:
            continue

        total_acs += len(ac_ids)
        spec_covered = 0

        if args.verbose:
            print(f"{spec_file.relative_to(specs_root)} ({len(ac_ids)} ACs)")

        for ac_id in ac_ids:
            if ac_id in all_covers:
                spec_covered += 1
                if args.verbose:
                    files = [
                        str(p.relative_to(project_root))
                        for p, _ in all_covers[ac_id]
                    ]
                    print(f"  COVERED {ac_id} -> {', '.join(files)}")
            else:
                if args.verbose:
                    print(f"  MISSING {ac_id}")

        covered_acs += spec_covered
        if args.verbose:
            pct = (spec_covered / len(ac_ids) * 100) if ac_ids else 0
            print(f"  Coverage: {spec_covered}/{len(ac_ids)} ({pct:.0f}%)\n")

    print("=" * 45)
    overall_pct = (covered_acs / total_acs * 100) if total_acs > 0 else 0
    print(f"TOTAL: {covered_acs}/{total_acs} ACs covered ({overall_pct:.0f}%)")
    print(f"Threshold: {args.threshold}%")
    result = "PASS" if overall_pct >= args.threshold else "FAIL"
    print(f"Result: {result}")
    print("=" * 45)

    return 0 if overall_pct >= args.threshold else 1


if __name__ == "__main__":
    raise SystemExit(main())
