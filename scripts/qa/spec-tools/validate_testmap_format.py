#!/usr/bin/env python3
# @covers AC-002
# @spec: ci-cd-pipeline_spec.md
"""validate_testmap_format.py — Validate testmap YAML schema and structure.

Validates testmap files for:
- Required schema fields (spec, acceptance_criteria)
- AC entry structure (id, description, verify)
- Valid verify types and type-specific fields
- Duplicate AC IDs within a testmap
- AC ID format (AC-XXX or AC-PREFIX-XXX)
- Empty verify lists (warning only)

Usage:
  python3 validate_testmap_format.py specs/testmaps/
  python3 validate_testmap_format.py specs/testmaps/feature.testmap.yml
  python3 validate_testmap_format.py specs/testmaps/ --format json
  python3 validate_testmap_format.py specs/testmaps/ --strict
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

from lint_core import (
    LintResult,
    Violation,
    format_results_json,
    format_results_text,
)

# Valid verify types per spec architecture
VALID_VERIFY_TYPES = {
    "automated",
    "manual",
    "monitoring",
    "shell_verification",
    "unit",
    "integration",
    "contract",
}

# AC ID pattern: AC-XXX or AC-PREFIX-XXX where XXX is 3+ digits
AC_ID_RE = re.compile(r"^AC-(?:[A-Z]+-)?(\d{3,})$")


def validate_ac_id(ac_id: str) -> bool:
    """Check if AC ID matches expected pattern."""
    return bool(AC_ID_RE.match(ac_id))


def validate_verify_entry(
    entry: dict, ac_id: str, file: str
) -> list[Violation]:
    """Validate a single verify entry structure."""
    violations = []

    if not isinstance(entry, dict):
        violations.append(
            Violation(
                rule_id="TESTMAP-VE-001",
                severity="error",
                file=file,
                message=f"AC {ac_id}: verify entry must be a dict, got {type(entry).__name__}",
            )
        )
        return violations

    # Check required 'type' field
    if "type" not in entry:
        violations.append(
            Violation(
                rule_id="TESTMAP-VE-002",
                severity="error",
                file=file,
                message=f"AC {ac_id}: verify entry missing required 'type' field",
            )
        )
        return violations

    vtype = entry["type"]
    if vtype not in VALID_VERIFY_TYPES:
        violations.append(
            Violation(
                rule_id="TESTMAP-VE-003",
                severity="error",
                file=file,
                message=(
                    f"AC {ac_id}: invalid verify type '{vtype}'. "
                    f"Must be one of: {', '.join(sorted(VALID_VERIFY_TYPES))}"
                ),
            )
        )

    # Type-specific field validation
    if vtype == "automated":
        if "file" not in entry:
            violations.append(
                Violation(
                    rule_id="TESTMAP-VE-004",
                    severity="error",
                    file=file,
                    message=f"AC {ac_id}: 'automated' verify entry must have 'file' field",
                )
            )

    elif vtype in ("manual", "monitoring"):
        if "procedure" not in entry and "check" not in entry:
            violations.append(
                Violation(
                    rule_id="TESTMAP-VE-005",
                    severity="warn",
                    file=file,
                    message=(
                        f"AC {ac_id}: '{vtype}' verify entry should have "
                        "'procedure' or 'check' field"
                    ),
                )
            )

    return violations


def validate_ac_entry(
    entry: dict, file: str, seen_ids: set[str]
) -> list[Violation]:
    """Validate a single AC entry structure."""
    violations = []

    if not isinstance(entry, dict):
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-001",
                severity="error",
                file=file,
                message=f"AC entry must be a dict, got {type(entry).__name__}",
            )
        )
        return violations

    # Check required 'id' field
    if "id" not in entry:
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-002",
                severity="error",
                file=file,
                message="AC entry missing required 'id' field",
            )
        )
        return violations

    ac_id = entry["id"]

    # Validate AC ID format
    if not validate_ac_id(ac_id):
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-003",
                severity="error",
                file=file,
                message=(
                    f"AC {ac_id}: invalid AC ID format. "
                    "Must match AC-XXX or AC-PREFIX-XXX (3+ digits)"
                ),
            )
        )

    # Check for duplicate AC IDs
    if ac_id in seen_ids:
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-004",
                severity="error",
                file=file,
                message=f"Duplicate AC ID '{ac_id}' in testmap",
            )
        )
    else:
        seen_ids.add(ac_id)

    # Check required 'description' field
    if "description" not in entry:
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-005",
                severity="error",
                file=file,
                message=f"AC {ac_id}: missing required 'description' field",
            )
        )

    # Check required 'verify' field
    if "verify" not in entry:
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-006",
                severity="error",
                file=file,
                message=f"AC {ac_id}: missing required 'verify' field",
            )
        )
        return violations

    verify = entry["verify"]
    if not isinstance(verify, list):
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-007",
                severity="error",
                file=file,
                message=f"AC {ac_id}: 'verify' must be a list, got {type(verify).__name__}",
            )
        )
        return violations

    # Empty verify list is a warning (AC may be pending implementation)
    if len(verify) == 0:
        violations.append(
            Violation(
                rule_id="TESTMAP-AC-008",
                severity="warn",
                file=file,
                message=f"AC {ac_id}: 'verify' list is empty (unmapped AC)",
            )
        )
    else:
        # Validate each verify entry
        for ve in verify:
            violations.extend(validate_verify_entry(ve, ac_id, file))

    return violations


def validate_testmap_file(path: Path) -> LintResult:
    """Validate a single testmap file."""
    result = LintResult(file=str(path))

    try:
        content = path.read_text(encoding="utf-8")
    except Exception as e:
        result.violations.append(
            Violation(
                rule_id="TESTMAP-IO-001",
                severity="error",
                file=str(path),
                message=f"Failed to read file: {e}",
            )
        )
        return result

    try:
        data = yaml.safe_load(content)
    except yaml.YAMLError as e:
        result.violations.append(
            Violation(
                rule_id="TESTMAP-YAML-001",
                severity="error",
                file=str(path),
                message=f"Invalid YAML: {e}",
            )
        )
        return result

    if data is None:
        result.violations.append(
            Violation(
                rule_id="TESTMAP-YAML-002",
                severity="error",
                file=str(path),
                message="Empty YAML file",
            )
        )
        return result

    if not isinstance(data, dict):
        result.violations.append(
            Violation(
                rule_id="TESTMAP-ROOT-001",
                severity="error",
                file=str(path),
                message=f"Root element must be a dict, got {type(data).__name__}",
            )
        )
        return result

    # Check required top-level fields
    if "spec" not in data:
        result.violations.append(
            Violation(
                rule_id="TESTMAP-ROOT-002",
                severity="error",
                file=str(path),
                message="Missing required top-level field: 'spec'",
            )
        )

    if "acceptance_criteria" not in data:
        result.violations.append(
            Violation(
                rule_id="TESTMAP-ROOT-003",
                severity="error",
                file=str(path),
                message="Missing required top-level field: 'acceptance_criteria'",
            )
        )
        return result

    acs = data["acceptance_criteria"]
    if not isinstance(acs, list):
        result.violations.append(
            Violation(
                rule_id="TESTMAP-ROOT-004",
                severity="error",
                file=str(path),
                message=(
                    f"'acceptance_criteria' must be a list, "
                    f"got {type(acs).__name__}"
                ),
            )
        )
        return result

    # Validate each AC entry
    seen_ids: set[str] = set()
    for ac_entry in acs:
        violations = validate_ac_entry(ac_entry, str(path), seen_ids)
        result.violations.extend(violations)

    # Optional _unmapped field validation
    if "_unmapped" in data:
        unmapped = data["_unmapped"]
        if not isinstance(unmapped, list):
            result.violations.append(
                Violation(
                    rule_id="TESTMAP-ROOT-005",
                    severity="error",
                    file=str(path),
                    message=(
                        f"'_unmapped' must be a list, got {type(unmapped).__name__}"
                    ),
                )
            )
        else:
            # Validate unmapped AC IDs
            for unmapped_id in unmapped:
                if not validate_ac_id(unmapped_id):
                    result.violations.append(
                        Violation(
                            rule_id="TESTMAP-ROOT-006",
                            severity="warn",
                            file=str(path),
                            message=(
                                f"Invalid AC ID in _unmapped: '{unmapped_id}'"
                            ),
                        )
                    )

    return result


def gather_testmap_files(path: Path) -> list[Path]:
    """Gather testmap YAML files from path (file or directory).

    Skips 'all.testmap.yml' — it is a generated multi-document YAML aggregate
    and individual per-spec testmaps are already validated separately.
    """
    if path.is_file():
        return [path]

    files = []
    for pattern in ("*.testmap.yml", "*.testmap.yaml"):
        files.extend(sorted(path.glob(pattern)))
    return [f for f in files if f.name != "all.testmap.yml"]


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Validate testmap YAML schema and structure."
    )
    ap.add_argument(
        "path",
        type=str,
        help="Path to testmap file or directory containing testmap files",
    )
    ap.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)",
    )
    ap.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors",
    )
    args = ap.parse_args()

    target = Path(args.path)
    if not target.exists():
        print(f"ERROR: path not found: {target}", file=sys.stderr)
        return 2

    files = gather_testmap_files(target)
    if not files:
        print(f"No testmap files found in {target}")
        return 0

    results: list[LintResult] = []
    for f in files:
        result = validate_testmap_file(f)

        # In strict mode, upgrade warnings to errors
        if args.strict:
            for v in result.violations:
                if v.severity == "warn":
                    v.severity = "error"

        results.append(result)

    if args.format == "json":
        print(format_results_json(results))
    else:
        print(format_results_text(results, show_pass=True))

    return 1 if any(not r.passed for r in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
