from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SPEC_TOOLS = REPO_ROOT / "scripts" / "qa" / "spec-tools"


def load_tool(name: str):
    spec = importlib.util.spec_from_file_location(name, SPEC_TOOLS / f"{name}.py")
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_spec_tools_extract_checked_and_unchecked_acceptance_criteria(tmp_path: Path) -> None:
    discover_testmap = load_tool("discover_testmap")
    spec_verify = load_tool("spec_verify")
    spec_coverage_report = load_tool("spec_coverage_report")

    content = """# Sample

## Acceptance Criteria
- [ ] AC-BAUTH-001: unchecked criteria
- [x] AC-BAUTH-002: checked criteria
* [X] AC-BAUTH-003: checked star criteria
"""
    spec_path = tmp_path / "sample_spec.md"
    spec_path.write_text(content, encoding="utf-8")

    assert discover_testmap.parse_spec_acs(spec_path) == [
        ("AC-BAUTH-001", "unchecked criteria"),
        ("AC-BAUTH-002", "checked criteria"),
        ("AC-BAUTH-003", "checked star criteria"),
    ]
    assert spec_verify.parse_acceptance_criteria(content) == [
        ("AC-BAUTH-001", "- [ ] AC-BAUTH-001: unchecked criteria"),
        ("AC-BAUTH-002", "- [x] AC-BAUTH-002: checked criteria"),
        ("AC-BAUTH-003", "* [X] AC-BAUTH-003: checked star criteria"),
    ]
    assert spec_coverage_report.extract_ac_ids(content) == [
        "AC-BAUTH-001",
        "AC-BAUTH-002",
        "AC-BAUTH-003",
    ]


def test_discover_testmap_keeps_globally_prefixed_acs_across_spec_scope(
    tmp_path: Path,
) -> None:
    discover_testmap = load_tool("discover_testmap")
    scan_dir = tmp_path / "scripts"
    scan_dir.mkdir()
    (scan_dir / "verify.sh").write_text(
        "\n".join(
            [
                "# @" + "covers AC-BAUTH-001, AC-001",
                "# @" + "spec: ci-cd-pipeline_spec.md",
                "true",
            ]
        ),
        encoding="utf-8",
    )

    covers = discover_testmap.scan_dirs(
        [scan_dir],
        spec_filter="build-authority-deterministic-builds_spec.md",
    )

    assert covers["AC-BAUTH-001"] == [scan_dir / "verify.sh"]
    assert "AC-001" not in covers
