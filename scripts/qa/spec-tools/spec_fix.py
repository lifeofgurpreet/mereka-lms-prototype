#!/usr/bin/env python3
# @covers AC-002
# @spec: ci-cd-pipeline_spec.md
"""spec_fix.py — Bulk spec fixer for common lint violations.

Automatically fixes common spec lint issues:
- Add sequential AC IDs to bare checkboxes (--add-ac-ids)
- Add missing ### Non-Functional Requirements section (--fix)
- Add missing cross-cutting reference to related_specs (--fix)

Usage:
  python3 spec_fix.py specs/                     # Dry-run: show what would be fixed
  python3 spec_fix.py specs/ --add-ac-ids        # Add AC-001, AC-002... to bare checkboxes
  python3 spec_fix.py specs/ --fix               # Apply all safe fixes
  python3 spec_fix.py specs/ --add-ac-ids --fix  # Add AC IDs and apply fixes
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import List, Tuple

try:
    import yaml
except ImportError:
    yaml = None

from lint_core import (
    parse_frontmatter,
    read_text,
    gather_markdown_files,
    SKIP_FILES,
)

CROSS_CUTTING_SPEC = "specs/cross-cutting-requirements_spec.md"
AC_ID_RE = re.compile(r"^[-*]\s+\[ \]\s+(AC-(?:[A-Z]+-)?(\d{3}))")
BARE_CHECKBOX_RE = re.compile(r"^([-*]\s+\[ \]\s+)(?!AC-)(.+)$")


def extract_highest_ac_num(content: str) -> int:
    """Find the highest AC-NNN number in the file (ignore prefixed ACs)."""
    highest = 0
    for line in content.splitlines():
        m = AC_ID_RE.match(line.strip())
        if m:
            # Check if it's a simple AC-NNN (group 2 is the number)
            num_str = m.group(2)
            try:
                num = int(num_str)
                highest = max(highest, num)
            except ValueError:
                pass
    return highest


def add_ac_ids_to_bare_checkboxes(content: str) -> Tuple[str, int]:
    """Add AC-NNN: prefix to bare checkboxes. Returns (new_content, count_fixed)."""
    lines = content.splitlines(keepends=True)
    next_num = extract_highest_ac_num(content) + 1
    count_fixed = 0

    result = []
    for line in lines:
        stripped = line.strip()
        m = BARE_CHECKBOX_RE.match(stripped)
        if m:
            # Bare checkbox without AC- prefix
            prefix = m.group(1)
            text = m.group(2)
            indent = line[:len(line) - len(line.lstrip())]
            new_line = f"{indent}{prefix}AC-{next_num:03d}: {text}\n"
            result.append(new_line)
            next_num += 1
            count_fixed += 1
        else:
            result.append(line)

    return "".join(result), count_fixed


def add_nfr_section(content: str) -> Tuple[str, bool]:
    """Add '### Non-Functional Requirements' section if missing. Returns (new_content, was_added)."""
    nfr_re = re.compile(r"^###\s+Non-Functional Requirements\s*$", re.MULTILINE)
    if nfr_re.search(content):
        return content, False

    # Find the end of Acceptance Criteria section (next ## or ### heading)
    ac_section_end_re = re.compile(
        r"(^##\s+Acceptance Criteria\s*$.*?)(^##[^#]|\Z)",
        re.MULTILINE | re.DOTALL
    )
    m = ac_section_end_re.search(content)
    if not m:
        return content, False

    # Insert NFR section after Acceptance Criteria
    insertion_point = m.end(1)
    nfr_section = "\n\n### Non-Functional Requirements\n\n(To be defined)\n"
    new_content = content[:insertion_point] + nfr_section + content[insertion_point:]
    return new_content, True


def add_cross_cutting_reference(content: str) -> Tuple[str, bool]:
    """Add cross-cutting spec to related_specs in frontmatter. Returns (new_content, was_added)."""
    if yaml is None:
        return content, False

    fm, body = parse_frontmatter(content)
    if not fm:
        return content, False

    # Check if already present
    related = fm.get("related_specs", []) or fm.get("links", {}).get("related_specs", [])
    if not isinstance(related, list):
        related = [related] if related else []
    related_str = [str(r) for r in related]
    if any(CROSS_CUTTING_SPEC in r for r in related_str):
        return content, False

    # Add to related_specs
    if "related_specs" not in fm:
        fm["related_specs"] = []
    if not isinstance(fm["related_specs"], list):
        fm["related_specs"] = [fm["related_specs"]]
    fm["related_specs"].append(CROSS_CUTTING_SPEC)

    # Rebuild content
    new_frontmatter = yaml.dump(fm, default_flow_style=False, sort_keys=False)
    new_content = f"---\n{new_frontmatter}---\n{body}"
    return new_content, True


def fix_file(
    path: Path,
    add_ac_ids: bool,
    apply_fixes: bool,
    dry_run: bool
) -> Tuple[int, List[str]]:
    """Fix a single spec file. Returns (fix_count, messages)."""
    content = read_text(path)
    original_content = content
    messages = []
    fix_count = 0

    # Skip cross-cutting spec itself for related_specs fix
    is_cross_cutting = path.name == "cross-cutting-requirements_spec.md"

    # In dry-run mode, check all possible fixes
    check_ac_ids = add_ac_ids or dry_run
    check_general_fixes = apply_fixes or dry_run

    # Add AC IDs to bare checkboxes
    if check_ac_ids:
        content, ac_count = add_ac_ids_to_bare_checkboxes(content)
        if ac_count > 0:
            fix_count += ac_count
            messages.append(f"  [AC-ID] Added AC IDs to {ac_count} bare checkbox(es)")

    # Apply general fixes
    if check_general_fixes:
        # Add missing NFR section
        content, nfr_added = add_nfr_section(content)
        if nfr_added:
            fix_count += 1
            messages.append("  [MEREKA-SEC-001] Added '### Non-Functional Requirements' section")

        # Add cross-cutting reference
        if not is_cross_cutting:
            content, ref_added = add_cross_cutting_reference(content)
            if ref_added:
                fix_count += 1
                messages.append(f"  [MEREKA-REF-001] Added '{CROSS_CUTTING_SPEC}' to related_specs")

    # Write changes if not dry run and content changed
    if fix_count > 0:
        if not dry_run:
            path.write_text(content, encoding="utf-8")
        return fix_count, messages

    return 0, []


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Bulk spec fixer for common lint violations.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 spec_fix.py specs/                     # Dry-run: show what would be fixed
  python3 spec_fix.py specs/ --add-ac-ids        # Add AC-001, AC-002... to bare checkboxes
  python3 spec_fix.py specs/ --fix               # Apply all safe fixes
  python3 spec_fix.py specs/ --add-ac-ids --fix  # Add AC IDs and apply all fixes
        """
    )
    ap.add_argument("path", type=str, help="File or folder containing spec files")
    ap.add_argument(
        "--add-ac-ids",
        action="store_true",
        help="Add sequential AC-NNN IDs to bare checkboxes"
    )
    ap.add_argument(
        "--fix",
        action="store_true",
        help="Apply all safe fixes (NFR section, cross-cutting ref)"
    )
    args = ap.parse_args()

    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    # Determine if dry run
    dry_run = not (args.add_ac_ids or args.fix)
    if not dry_run and not (args.add_ac_ids or args.fix):
        # If neither flag is set, default to dry run
        dry_run = True

    files = gather_markdown_files(target)
    if not files:
        print("No markdown files found.")
        return 0

    # Filter: only *_spec.md files, skip index/readme/template
    files = [f for f in files if f.name not in SKIP_FILES and f.name.endswith("_spec.md")]

    total_fixes = 0
    files_with_fixes = 0

    if dry_run:
        print("DRY RUN: Showing what would be fixed (use --add-ac-ids or --fix to apply)\n")

    for spec_file in files:
        fix_count, messages = fix_file(
            spec_file,
            add_ac_ids=args.add_ac_ids,
            apply_fixes=args.fix,
            dry_run=dry_run
        )

        if fix_count > 0:
            files_with_fixes += 1
            total_fixes += fix_count
            status = "WOULD FIX" if dry_run else "FIXED"
            print(f"{status}: {spec_file.name}")
            for msg in messages:
                print(msg)
            print()

    # Summary
    if total_fixes == 0:
        print("No issues found to fix.")
    else:
        action = "would fix" if dry_run else "fixed"
        print(f"Summary: {action} {total_fixes} issue(s) across {files_with_fixes} file(s)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
