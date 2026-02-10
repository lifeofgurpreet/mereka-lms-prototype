#!/usr/bin/env python3
"""lint_core.py — Shared types and utilities for specdocs lint tools.

Provides:
- Violation and LintResult dataclasses
- Frontmatter parsing
- Section detection and extraction
- Output formatting (text/json)

Copied from team-skills: plugins/core/skills/specs-vs-docs/tools/lint_core.py
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip install pyyaml")


@dataclass
class Violation:
    """A single lint violation with structured metadata."""
    rule_id: str           # e.g., SPEC-FM-001
    severity: str          # error | warn | info
    file: str
    line: Optional[int] = None
    message: str = ""
    autofix: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class LintResult:
    """Result of linting a single file."""
    file: str
    violations: List[Violation] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not any(v.severity == "error" for v in self.violations)

    @property
    def error_count(self) -> int:
        return sum(1 for v in self.violations if v.severity == "error")

    @property
    def warn_count(self) -> int:
        return sum(1 for v in self.violations if v.severity == "warn")

    def to_dict(self) -> dict:
        return {
            "file": self.file,
            "passed": self.passed,
            "violations": [v.to_dict() for v in self.violations],
        }


@dataclass
class ClassificationResult:
    """Result of classifying a file as spec, doc, hybrid, or unknown."""
    file: str
    spec_score: float = 0.0
    doc_score: float = 0.0
    classification: str = "UNKNOWN"   # SPEC | DOC | HYBRID | UNKNOWN
    confidence: float = 0.0
    violations: List[Violation] = field(default_factory=list)
    remediation: Optional[str] = None  # MOVE | CONVERT | SPLIT | LEAVE | None

    def to_dict(self) -> dict:
        return {
            "file": self.file,
            "spec_score": round(self.spec_score, 2),
            "doc_score": round(self.doc_score, 2),
            "classification": self.classification,
            "confidence": round(self.confidence, 2),
            "violations": [v.to_dict() for v in self.violations],
            "remediation": self.remediation,
        }


# --- Parsing utilities ---

def read_text(path: Path) -> str:
    """Read a file's text content."""
    return path.read_text(encoding="utf-8")


def parse_frontmatter(md: str) -> Tuple[Optional[Dict], str]:
    """Parse YAML frontmatter from markdown. Returns (frontmatter_dict_or_none, body)."""
    if not md.lstrip().startswith("---"):
        return None, md
    parts = md.split("---", 2)
    if len(parts) < 3:
        return None, md
    fm_raw = parts[1].strip()
    body = parts[2].lstrip("\n")
    try:
        fm = yaml.safe_load(fm_raw) or {}
        if not isinstance(fm, dict):
            return None, body
        return fm, body
    except Exception:
        return None, body


def has_section(body: str, section: str) -> bool:
    """Check if a markdown body has a section with the given header."""
    pattern = re.compile(rf"^#+\s+{re.escape(section)}\s*$", re.MULTILINE)
    return bool(pattern.search(body))


def extract_section(body: str, section: str) -> str:
    """Best-effort extraction of a section's content (between its header and the next same-or-higher-level header)."""
    header_re = re.compile(rf"^(?P<h>#+)\s+{re.escape(section)}\s*$", re.MULTILINE)
    m = header_re.search(body)
    if not m:
        return ""
    start = m.end()
    level = len(m.group("h"))
    next_re = re.compile(rf"^#{{1,{level}}}\s+.+$", re.MULTILINE)
    m2 = next_re.search(body, pos=start)
    end = m2.start() if m2 else len(body)
    return body[start:end].strip()


def gather_markdown_files(p: Path) -> List[Path]:
    """Gather markdown files from a path (file or directory)."""
    if p.is_file():
        return [p]
    return sorted([x for x in p.rglob("*.md") if x.is_file()])


# --- Output formatting ---

SKIP_FILES = {"INDEX.md", "README.md", "_TEMPLATE.md"}

def format_results_text(results: List[LintResult], show_pass: bool = True) -> str:
    """Format lint results as human-readable text."""
    lines = []
    for r in results:
        if r.passed:
            if show_pass:
                lines.append(f"PASS {r.file}")
        else:
            lines.append(f"\nFAIL {r.file}")
            for v in r.violations:
                loc = f":{v.line}" if v.line else ""
                lines.append(f"  [{v.severity.upper()}] {v.rule_id}{loc}: {v.message}")
    return "\n".join(lines)


def format_results_json(results: List[LintResult]) -> str:
    """Format lint results as JSON."""
    total_violations = sum(len(r.violations) for r in results)
    errors = sum(r.error_count for r in results)
    warnings = sum(r.warn_count for r in results)
    passed = all(r.passed for r in results)

    output = {
        "passed": passed,
        "total_violations": total_violations,
        "by_severity": {"error": errors, "warn": warnings},
        "files": [r.to_dict() for r in results],
    }
    return json.dumps(output, indent=2)


def format_classifications_text(results: List[ClassificationResult]) -> str:
    """Format classification results as human-readable text."""
    lines = []
    for r in results:
        label = r.classification
        scores = f"spec={r.spec_score:.2f} doc={r.doc_score:.2f}"
        remedy = f" -> {r.remediation}" if r.remediation else ""
        lines.append(f"  {label:7s} {scores}  {r.file}{remedy}")
        for v in r.violations:
            lines.append(f"    [{v.severity.upper()}] {v.rule_id}: {v.message}")
    return "\n".join(lines)


def format_classifications_json(results: List[ClassificationResult]) -> str:
    """Format classification results as JSON."""
    output = {
        "total": len(results),
        "by_type": {},
        "files": [r.to_dict() for r in results],
    }
    for r in results:
        output["by_type"][r.classification] = output["by_type"].get(r.classification, 0) + 1
    return json.dumps(output, indent=2)
