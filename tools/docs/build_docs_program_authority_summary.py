#!/usr/bin/env python3
"""Generate docs-program authority summary artifacts from the registry verifier."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = REPO_ROOT / "tools" / "docs" / "verify" / "verify_docs_program_authority_registry.py"
REGISTRY = REPO_ROOT / "docs" / "meta" / "docs-program" / "authority-registry.v1.yaml"
JSON_OUT = REPO_ROOT / "generated" / "catalogs" / "docs-program-authority-summary.json"
MD_OUT = REPO_ROOT / "docs" / "reference" / "generated" / "docs-program-authority-summary.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit non-zero if generated files are stale")
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="repository root")
    return parser.parse_args()


def load_registry_last_updated(path: Path) -> str:
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return str(payload.get("last_updated", "unknown"))


def build_summary(repo_root: Path) -> dict:
    with tempfile.NamedTemporaryFile(mode="w+", suffix=".json", delete=False) as handle:
        summary_path = Path(handle.name)
    try:
        proc = subprocess.run(
            [sys.executable, str(VERIFIER), "--repo-root", str(repo_root), "--summary-json", str(summary_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            if proc.stdout:
                sys.stdout.write(proc.stdout)
            if proc.stderr:
                sys.stderr.write(proc.stderr)
            raise SystemExit(proc.returncode)
        return json.loads(summary_path.read_text(encoding="utf-8"))
    finally:
        summary_path.unlink(missing_ok=True)


def render_json(summary: dict, registry_last_updated: str) -> str:
    payload = {
        "source": "docs/meta/docs-program/authority-registry.v1.yaml",
        "registry_last_updated": registry_last_updated,
        "summary": summary,
    }
    return json.dumps(payload, indent=2) + "\n"


def render_markdown(summary: dict, registry_last_updated: str) -> str:
    lines: list[str] = []
    lines.append("# Docs Program Authority Summary")
    lines.append("")
    lines.append(
        "_Generated from `docs/meta/docs-program/authority-registry.v1.yaml` "
        f"(last updated {registry_last_updated})._"
    )
    lines.append(
        "_Do not hand-edit. Regenerate with: "
        "`python3 tools/docs/build_docs_program_authority_summary.py`_"
    )
    lines.append("")
    lines.append("## Current Root State")
    lines.append("")
    lines.append("| Measure | Count |")
    lines.append("|---|---:|")
    lines.append(f"| Root markdown surfaces | {summary['root_file_count']} |")
    lines.append(f"| Active entry points | {len(summary['current_entry_point_paths'])} |")
    lines.append(f"| Active references | {len(summary['active_reference_paths'])} |")
    lines.append(f"| Active bundles | {len(summary['active_bundle_paths'])} |")
    lines.append(f"| Historical retained | {len(summary['historical_paths'])} |")
    lines.append(f"| Generated retained | {len(summary['generated_paths'])} |")
    lines.append(f"| Deprecated retained stubs | {len(summary['deprecated_retained_paths'])} |")
    lines.append("")
    lines.append("## Current Entry Points")
    lines.append("")
    if summary["current_entry_point_paths"]:
        for path in summary["current_entry_point_paths"]:
            rel = path.removeprefix("docs/meta/docs-program/")
            lines.append(f"- [`{rel}`](../../meta/docs-program/{rel})")
    else:
        lines.append("- None")
    lines.append("")
    lines.append("## Retained Compatibility Stubs")
    lines.append("")
    if summary["deprecated_retained_paths"]:
        for path in summary["deprecated_retained_paths"]:
            rel = path.removeprefix("docs/meta/docs-program/")
            lines.append(f"- [`{rel}`](../../meta/docs-program/{rel})")
    else:
        lines.append("- None")
    lines.append("")
    lines.append("## Compression Status")
    lines.append("")
    lines.append(
        f"- Active non-entry-point docs-program surfaces: "
        f"{len(summary['active_reference_paths']) + len(summary['active_bundle_paths'])}"
    )
    lines.append(f"- Active-to-historical links: {len(summary['active_to_historical_links'])}")
    lines.append(f"- Uncovered root surfaces: {len(summary['uncovered_paths'])}")
    lines.append("")
    lines.append("## Registry Counts")
    lines.append("")
    lines.append("| Authority | Count |")
    lines.append("|---|---:|")
    for key, value in summary["authority_counts"].items():
        lines.append(f"| `{key}` | {value} |")
    lines.append("")
    lines.append("| Doc kind | Count |")
    lines.append("|---|---:|")
    for key, value in summary["doc_kind_counts"].items():
        lines.append(f"| `{key}` | {value} |")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    registry_last_updated = load_registry_last_updated(repo_root / REGISTRY.relative_to(REPO_ROOT))
    summary = build_summary(repo_root)
    json_text = render_json(summary, registry_last_updated)
    md_text = render_markdown(summary, registry_last_updated)

    if args.check:
        stale: list[str] = []
        if not JSON_OUT.exists() or JSON_OUT.read_text(encoding="utf-8") != json_text:
            stale.append(str(JSON_OUT.relative_to(REPO_ROOT)))
        if not MD_OUT.exists() or MD_OUT.read_text(encoding="utf-8") != md_text:
            stale.append(str(MD_OUT.relative_to(REPO_ROOT)))
        if stale:
            print("DOCS_PROGRAM_AUTHORITY_SUMMARY_STALE")
            for path in stale:
                print(f"- {path}")
            return 1
        print("DOCS_PROGRAM_AUTHORITY_SUMMARY_OK")
        return 0

    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    MD_OUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUT.write_text(json_text, encoding="utf-8")
    MD_OUT.write_text(md_text, encoding="utf-8")
    print("DOCS_PROGRAM_AUTHORITY_SUMMARY_WRITTEN")
    print(f"- {JSON_OUT.relative_to(REPO_ROOT)}")
    print(f"- {MD_OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
