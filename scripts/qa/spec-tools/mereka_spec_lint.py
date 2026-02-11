#!/usr/bin/env python3
# @covers AC-002
# @spec: ci-cd-pipeline_spec.md
"""mereka_spec_lint.py — Project-specific spec linter for Mereka LMS.

Wraps the generic spec_lint.py and adds Mereka-specific rules:
- MEREKA-REF-001: related_specs must include cross-cutting-requirements_spec.md
- MEREKA-SEC-001: Must have ### Non-Functional Requirements heading
- MEREKA-AC-001: AC IDs must be unique within each spec
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List

from lint_core import (
    Violation,
    LintResult,
    parse_frontmatter,
    read_text,
    gather_markdown_files,
    format_results_text,
    format_results_json,
    SKIP_FILES,
)
from spec_lint import lint_file as base_lint_file

CROSS_CUTTING_SPEC = "specs/cross-cutting-requirements_spec.md"
AC_ID_RE = re.compile(r"\b(AC-(?:[A-Z]+-)?(\d{3,}))\b")


def mereka_lint_file(path: Path) -> LintResult:
    """Run base lint + Mereka-specific rules."""
    result = base_lint_file(path)
    md = read_text(path)
    fm, body = parse_frontmatter(md)

    # Skip cross-cutting spec itself for the cross-ref rule
    is_cross_cutting = path.name == "cross-cutting-requirements_spec.md"

    # MEREKA-REF-001: related_specs must reference cross-cutting spec
    # Severity: warn (many specs predate this rule; will be error after bulk fix)
    # Check both top-level and nested under links.related_specs
    if fm and not is_cross_cutting:
        related = fm.get("related_specs", []) or fm.get("links", {}).get("related_specs", [])
        if not isinstance(related, list):
            related = [related] if related else []
        related_str = [str(r) for r in related]
        if not any(CROSS_CUTTING_SPEC in r for r in related_str):
            result.violations.append(
                Violation(
                    rule_id="MEREKA-REF-001",
                    severity="warn",
                    file=str(path),
                    message=f"Frontmatter related_specs must include '{CROSS_CUTTING_SPEC}'",
                )
            )

    # MEREKA-SEC-001: Must have ### Non-Functional Requirements
    # Severity: warn (one spec predates this rule; will be error after fix)
    nfr_re = re.compile(r"^###\s+Non-Functional Requirements\s*$", re.MULTILINE)
    if not nfr_re.search(body):
        result.violations.append(
            Violation(
                rule_id="MEREKA-SEC-001",
                severity="warn",
                file=str(path),
                message="Missing required section: '### Non-Functional Requirements'",
            )
        )

    # MEREKA-AC-001: AC IDs must be unique within Acceptance Criteria section
    # Only count the leading AC ID on checkbox lines (- [ ] AC-NNN:) to avoid
    # false positives from references to other ACs in description text or code.
    ac_leading_re = re.compile(r"^[-*]\s+\[ \]\s+(AC-(?:[A-Z]+-)?(\d{3,}))")
    seen_ids: dict[str, int] = {}
    for lineno, line in enumerate(md.splitlines(), 1):
        stripped = line.strip()
        m = ac_leading_re.match(stripped)
        if not m:
            continue
        ac_id = m.group(1)
        if ac_id in seen_ids:
            result.violations.append(
                Violation(
                    rule_id="MEREKA-AC-001",
                    severity="error",
                    file=str(path),
                    line=lineno,
                    message=f"Duplicate AC ID '{ac_id}' (first seen at line {seen_ids[ac_id]})",
                )
            )
        else:
            seen_ids[ac_id] = lineno

    return result


def main() -> int:
    ap = argparse.ArgumentParser(description="Mereka LMS spec linter (base + project rules).")
    ap.add_argument("path", type=str, help="File or folder to lint")
    ap.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)",
    )
    ap.add_argument(
        "--severity-filter",
        choices=["error", "warn", "info"],
        help="Show only violations of this severity and above",
    )
    args = ap.parse_args()

    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}")
        return 2

    files = gather_markdown_files(target)
    if not files:
        print("No markdown files found.")
        return 0

    # Filter: only *_spec.md files, skip index/readme/template
    files = [f for f in files if f.name not in SKIP_FILES and f.name.endswith("_spec.md")]

    results: List[LintResult] = []
    for f in files:
        result = mereka_lint_file(f)

        if args.severity_filter:
            severity_order = {"error": 0, "warn": 1, "info": 2}
            filter_level = severity_order[args.severity_filter]
            result.violations = [
                v for v in result.violations
                if severity_order.get(v.severity, 999) <= filter_level
            ]

        results.append(result)

    if args.format == "json":
        print(format_results_json(results))
    else:
        print(format_results_text(results, show_pass=True))

    return 1 if any(not r.passed for r in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
