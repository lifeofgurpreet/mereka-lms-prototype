#!/usr/bin/env python3
# @covers AC-002
# @spec: ci-cd-pipeline_spec.md
"""mereka_spec_lint.py — Project-specific spec linter for Mereka LMS.

Wraps the generic spec_lint.py and adds Mereka-specific rules:
- MEREKA-REF-001: related_specs must include cross-cutting-requirements_spec.md
- MEREKA-SEC-001: Must have ### Non-Functional Requirements heading
- MEREKA-AC-001: AC IDs must be unique within each spec
- MEREKA-AC-002: AC IDs must match AC-NNN or AC-PREFIX-NNN format
- MEREKA-TYPE-001: Type-specific required sections (migration needs Migration Strategy, etc.)
- MEREKA-NORM-001: Acceptance Criteria must use normative language
- MEREKA-CFG-001: Frontmatter keys validated against specdocs.config.yml
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

from lint_core import (
    SKIP_FILES,
    LintResult,
    Violation,
    format_results_json,
    format_results_text,
    gather_markdown_files,
    has_section,
    parse_frontmatter,
    read_text,
)
from spec_lint import lint_file as base_lint_file

CROSS_CUTTING_SPEC = "specs/cross-cutting-requirements_spec.md"

# Valid AC ID pattern: AC-NNN or AC-PREFIX-NNN (prefix = 1+ uppercase letters)
AC_ID_VALID_RE = re.compile(r"^AC-(?:[A-Z]+-)?(\d{3})$")

# Type-specific required sections beyond the base set
TYPE_REQUIRED_SECTIONS: dict[str, list[tuple]] = {
    "migration_spec": [
        ("Migration Strategy", "MEREKA-TYPE-001", "error"),
    ],
    "service_spec": [
        ("API Contract", "MEREKA-TYPE-001", "warn"),
        ("Data Model", "MEREKA-TYPE-001", "warn"),
    ],
    "infrastructure_spec": [
        ("Configuration", "MEREKA-TYPE-001", "warn"),
    ],
}

# Valid frontmatter status values
VALID_STATUSES = {"draft", "review", "approved", "in_progress", "completed", "deferred"}

# Valid spec types
VALID_TYPES = {"feature_spec", "migration_spec", "infrastructure_spec", "service_spec",
               "data_pipeline_spec"}


def _load_config(spec_path: Path) -> dict | None:
    """Try to load specdocs.config.yml from repo root."""
    if yaml is None:
        return None
    # Walk up from spec path to find repo root with specdocs.config.yml
    for parent in [spec_path.parent, spec_path.parent.parent, spec_path.parent.parent.parent]:
        cfg_path = parent / "specdocs.config.yml"
        if cfg_path.exists():
            return yaml.safe_load(cfg_path.read_text())
    return None


def mereka_lint_file(path: Path) -> LintResult:
    """Run base lint + Mereka-specific rules."""
    result = base_lint_file(path)
    md = read_text(path)
    fm, body = parse_frontmatter(md)

    # Skip cross-cutting spec itself for the cross-ref rule
    is_cross_cutting = path.name == "cross-cutting-requirements_spec.md"

    # Load project config for config-driven validation
    config = _load_config(path)

    # MEREKA-CFG-001: Validate frontmatter status value
    if fm:
        status = fm.get("status", "")
        if status and status not in VALID_STATUSES:
            result.violations.append(
                Violation(
                    rule_id="MEREKA-CFG-001",
                    severity="error",
                    file=str(path),
                    message=f"Invalid frontmatter status '{status}'. Must be one of: {', '.join(sorted(VALID_STATUSES))}",
                )
            )

        spec_type = fm.get("type", "")
        if spec_type and spec_type not in VALID_TYPES:
            result.violations.append(
                Violation(
                    rule_id="MEREKA-CFG-001",
                    severity="warn",
                    file=str(path),
                    message=f"Unknown spec type '{spec_type}'. Known types: {', '.join(sorted(VALID_TYPES))}",
                )
            )

        # Validate quality gates from config
        if config:
            gates = config.get("quality_gates", {}).get("specs", {})
            max_acs = gates.get("max_ac_count", 50)
            ac_count = len(re.findall(r"^[-*]\s+\[ \]\s+AC-", md, re.MULTILINE))
            if ac_count > max_acs:
                result.violations.append(
                    Violation(
                        rule_id="MEREKA-CFG-001",
                        severity="warn",
                        file=str(path),
                        message=f"Spec has {ac_count} ACs, exceeds max_ac_count={max_acs} from specdocs.config.yml",
                    )
                )

    # MEREKA-REF-001: related_specs must reference cross-cutting spec
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

    # MEREKA-TYPE-001: Type-specific required sections
    if fm:
        spec_type = fm.get("type", "")
        for section, rule_id, severity in TYPE_REQUIRED_SECTIONS.get(spec_type, []):
            if not has_section(body, section):
                result.violations.append(
                    Violation(
                        rule_id=rule_id,
                        severity=severity,
                        file=str(path),
                        message=f"Spec type '{spec_type}' requires section: '{section}'",
                    )
                )

    # MEREKA-NORM-001: Acceptance Criteria should use normative language
    # Check that at least some ACs contain MUST/SHOULD/MAY or Given-When-Then
    ac_lines = [l for l in md.splitlines() if re.match(r"^\s*[-*]\s+\[ \]\s+AC-", l)]
    if ac_lines:
        normative_count = sum(
            1 for l in ac_lines
            if any(w in l for w in ["MUST", "SHOULD", "MAY", "Given", "given", "When", "when", "Then", "then"])
        )
        if normative_count == 0:
            result.violations.append(
                Violation(
                    rule_id="MEREKA-NORM-001",
                    severity="warn",
                    file=str(path),
                    message="No ACs use normative language (MUST/SHOULD/MAY) or Given-When-Then format",
                )
            )

    # MEREKA-AC-001: AC IDs must be unique within spec
    # MEREKA-AC-002: AC IDs must match valid format
    ac_leading_re = re.compile(r"^[-*]\s+\[ \]\s+(AC-[A-Za-z0-9-]+)")
    seen_ids: dict[str, int] = {}
    for lineno, line in enumerate(md.splitlines(), 1):
        stripped = line.strip()
        m = ac_leading_re.match(stripped)
        if not m:
            continue
        ac_id = m.group(1)

        # AC-002: Format validation
        if not AC_ID_VALID_RE.match(ac_id):
            result.violations.append(
                Violation(
                    rule_id="MEREKA-AC-002",
                    severity="warn",
                    file=str(path),
                    line=lineno,
                    message=f"AC ID '{ac_id}' does not match format AC-NNN or AC-PREFIX-NNN (e.g., AC-001 or AC-AUTH-001)",
                )
            )

        # AC-001: Uniqueness
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

    results: list[LintResult] = []
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
