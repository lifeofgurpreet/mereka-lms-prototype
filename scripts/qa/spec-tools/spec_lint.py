#!/usr/bin/env python3
"""spec_lint.py

A lightweight linter for spec markdown files.

Copied from team-skills: plugins/core/skills/specs-vs-docs/tools/spec_lint.py
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List

from lint_core import (
    Violation,
    LintResult,
    parse_frontmatter,
    has_section,
    extract_section,
    read_text,
    gather_markdown_files,
    format_results_text,
    format_results_json,
    SKIP_FILES,
)


NORMATIVE = ["MUST", "MUST NOT", "SHOULD", "SHOULD NOT", "MAY"]

REQUIRED_FRONTMATTER = ["title", "type", "status", "owner", "vehicle", "last_updated"]

# Mapping: frontmatter key -> (rule_id, severity)
FRONTMATTER_RULES = {
    "title": ("SPEC-FM-002", "error"),
    "type": ("SPEC-FM-003", "error"),
    "status": ("SPEC-FM-004", "error"),
    "owner": ("SPEC-FM-005", "error"),
    "vehicle": ("SPEC-FM-006", "error"),
    "last_updated": ("SPEC-FM-007", "error"),
}

# Mapping: section name -> (rule_id, severity)
SECTION_RULES = {
    "Scope": ("SPEC-SEC-001", "error"),
    "Non-goals": ("SPEC-SEC-002", "error"),
    "Requirements": ("SPEC-SEC-003", "error"),
    "Acceptance Criteria": ("SPEC-SEC-004", "error"),
    "Edge Cases": ("SPEC-SEC-005", "warn"),
    "Observability": ("SPEC-SEC-006", "warn"),
    "Rollout & Rollback": ("SPEC-SEC-007", "warn"),
    "Open Questions": ("SPEC-SEC-008", "warn"),
}


def lint_file(path: Path) -> LintResult:
    violations: List[Violation] = []
    md = read_text(path)
    fm, body = parse_frontmatter(md)

    # Check frontmatter existence
    if fm is None:
        violations.append(
            Violation(
                rule_id="SPEC-FM-001",
                severity="error",
                file=str(path),
                message="Missing YAML frontmatter (--- ... ---) at top of file.",
            )
        )
    else:
        # Check required frontmatter keys
        for k in REQUIRED_FRONTMATTER:
            if k not in fm or fm.get(k) in (None, "", []):
                rule_id, severity = FRONTMATTER_RULES[k]
                violations.append(
                    Violation(
                        rule_id=rule_id,
                        severity=severity,
                        file=str(path),
                        message=f"Frontmatter missing required key: {k}",
                    )
                )

    # Check required sections
    for section, (rule_id, severity) in SECTION_RULES.items():
        if not has_section(body, section):
            violations.append(
                Violation(
                    rule_id=rule_id,
                    severity=severity,
                    file=str(path),
                    message=f"Missing required section header: '{section}'",
                )
            )

    # Check Requirements section content
    req = extract_section(body, "Requirements")
    if req:
        if not any(word in req for word in NORMATIVE):
            violations.append(
                Violation(
                    rule_id="SPEC-NORM-001",
                    severity="error",
                    file=str(path),
                    message="Requirements section has no normative keywords (MUST/SHOULD/MAY).",
                )
            )

    # Check Acceptance Criteria section content
    ac = extract_section(body, "Acceptance Criteria")
    if ac:
        if "- [ ]" not in ac and "* [ ]" not in ac:
            violations.append(
                Violation(
                    rule_id="SPEC-AC-001",
                    severity="warn",
                    file=str(path),
                    message="Acceptance Criteria should include checkbox items like '- [ ] ...'.",
                )
            )

    return LintResult(file=str(path), violations=violations)


def main() -> int:
    ap = argparse.ArgumentParser(description="Lint spec markdown files.")
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

    # Filter out skip files
    files = [f for f in files if f.name not in SKIP_FILES]

    # Lint all files
    results: List[LintResult] = []
    for f in files:
        result = lint_file(f)

        # Apply severity filter if specified
        if args.severity_filter:
            severity_order = {"error": 0, "warn": 1, "info": 2}
            filter_level = severity_order[args.severity_filter]
            result.violations = [
                v for v in result.violations
                if severity_order.get(v.severity, 999) <= filter_level
            ]

        results.append(result)

    # Output results
    if args.format == "json":
        print(format_results_json(results))
    else:
        print(format_results_text(results, show_pass=True))

    # Return exit code: 1 if any errors, 0 if all pass
    return 1 if any(not r.passed for r in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
