#!/usr/bin/env python3
"""Generate docs-program merge-back wave summary artifacts from the wave manifest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = REPO_ROOT / "docs" / "meta" / "docs-program" / "metadata" / "merge-back-waves.v1.yaml"
JSON_OUT = REPO_ROOT / "generated" / "catalogs" / "docs-program-merge-back-waves.json"
MD_OUT = REPO_ROOT / "docs" / "reference" / "generated" / "docs-program-merge-back-waves.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit non-zero if generated files are stale")
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="repository root")
    return parser.parse_args()


def load_manifest(path: Path) -> dict:
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload.get("waves"), list):
        raise SystemExit("ERROR: merge-back wave manifest must declare a waves list")
    return payload


def resolve_dependencies(waves: list[dict]) -> tuple[list[str], list[dict[str, str]]]:
    wave_ids = {str(wave["id"]) for wave in waves}
    errors: list[dict[str, str]] = []
    graph: dict[str, list[str]] = {}

    for wave in waves:
        wave_id = str(wave["id"])
        deps = [str(dep) for dep in wave.get("depends_on", [])]
        graph[wave_id] = deps
        for dep in deps:
            if dep not in wave_ids:
                errors.append({"wave": wave_id, "dependency": dep, "kind": "missing"})

    ordered: list[str] = []
    state: dict[str, str] = {}

    def visit(node: str, stack: list[str]) -> None:
        current = state.get(node)
        if current == "done":
            return
        if current == "visiting":
            errors.append(
                {"wave": node, "dependency": " -> ".join(stack + [node]), "kind": "cycle"}
            )
            return
        state[node] = "visiting"
        for dep in graph.get(node, []):
            if dep in wave_ids:
                visit(dep, stack + [node])
        state[node] = "done"
        ordered.append(node)

    for wave_id in graph:
        visit(wave_id, [])

    extraction_order: list[str] = []
    seen: set[str] = set()
    for wave_id in ordered:
        if wave_id not in seen:
            extraction_order.append(wave_id)
            seen.add(wave_id)
    return extraction_order, errors


def build_summary(repo_root: Path, manifest: dict) -> dict:
    seen: dict[str, str] = {}
    overlaps: list[dict[str, str]] = []
    missing_paths: list[dict[str, str]] = []
    wave_rows: list[dict] = []
    extraction_order, dependency_errors = resolve_dependencies(manifest["waves"])

    for wave in manifest["waves"]:
        wave_id = str(wave["id"])
        include_paths = [str(p) for p in wave.get("include_paths", [])]
        remove_paths = [str(p) for p in wave.get("remove_paths", [])]
        for rel in include_paths:
            if not (repo_root / rel).exists():
                missing_paths.append({"wave": wave_id, "path": rel})
            previous = seen.get(rel)
            if previous:
                overlaps.append({"path": rel, "waves": f"{previous},{wave_id}"})
            else:
                seen[rel] = wave_id
        for rel in remove_paths:
            previous = seen.get(rel)
            if previous:
                overlaps.append({"path": rel, "waves": f"{previous},{wave_id}"})
            else:
                seen[rel] = wave_id
        wave_rows.append(
            {
                "id": wave_id,
                "title": str(wave["title"]),
                "readiness": str(wave.get("readiness", "unknown")),
                "depends_on": [str(dep) for dep in wave.get("depends_on", [])],
                "pr_title": str(wave["pr_title"]),
                "include_count": len(include_paths),
                "include_paths": include_paths,
                "remove_count": len(remove_paths),
                "remove_paths": remove_paths,
                "validators": [str(v) for v in wave.get("validators", [])],
                "out_of_scope": [str(v) for v in wave.get("out_of_scope", [])],
            }
        )

    return {
        "source": "docs/meta/docs-program/metadata/merge-back-waves.v1.yaml",
        "manifest_last_updated": str(manifest.get("last_updated", "unknown")),
        "wave_count": len(wave_rows),
        "extraction_order": extraction_order,
        "waves": wave_rows,
        "missing_paths": missing_paths,
        "overlaps": overlaps,
        "dependency_errors": dependency_errors,
        "status": "fail" if missing_paths or overlaps or dependency_errors else "pass",
    }


def render_json(summary: dict) -> str:
    return json.dumps(summary, indent=2) + "\n"


def render_markdown(summary: dict) -> str:
    lines: list[str] = []
    lines.append("# Docs Program Merge-Back Waves")
    lines.append("")
    lines.append(
        "_Generated from `docs/meta/docs-program/metadata/merge-back-waves.v1.yaml` "
        f"(last updated {summary['manifest_last_updated']})._"
    )
    lines.append(
        "_Do not hand-edit. Regenerate with: "
        "`python3 tools/docs/build_docs_program_merge_back_wave_summary.py`_"
    )
    lines.append("")
    lines.append("## Overview")
    lines.append("")
    lines.append("| Measure | Count |")
    lines.append("|---|---:|")
    lines.append(f"| Defined waves | {summary['wave_count']} |")
    lines.append(f"| Missing manifest paths | {len(summary['missing_paths'])} |")
    lines.append(f"| Overlapping include paths | {len(summary['overlaps'])} |")
    lines.append(f"| Dependency errors | {len(summary['dependency_errors'])} |")
    lines.append("")
    lines.append("## Extraction Order")
    lines.append("")
    for index, wave_id in enumerate(summary["extraction_order"], start=1):
        lines.append(f"{index}. `{wave_id}`")
    lines.append("")
    for wave in summary["waves"]:
        lines.append(f"## {wave['id']}: {wave['title']}")
        lines.append("")
        lines.append(f"- readiness: `{wave['readiness']}`")
        if wave["depends_on"]:
            lines.append(f"- depends on: `{', '.join(wave['depends_on'])}`")
        else:
            lines.append("- depends on: none")
        lines.append(f"- proposed PR title: `{wave['pr_title']}`")
        lines.append(f"- include paths: `{wave['include_count']}`")
        lines.append(f"- remove paths: `{wave['remove_count']}`")
        lines.append("- validators:")
        for validator in wave["validators"]:
            lines.append(f"  - `{validator}`")
        lines.append("- out of scope:")
        for item in wave["out_of_scope"]:
            lines.append(f"  - {item}")
        lines.append("- bundle:")
        for path in wave["include_paths"]:
            if path.startswith("docs/"):
                lines.append(f"  - [`{path}`](../../{path.removeprefix('docs/')})")
            else:
                lines.append(f"  - `{path}`")
        if wave["remove_paths"]:
            lines.append("- removes:")
            for path in wave["remove_paths"]:
                lines.append(f"  - `{path}`")
        lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    manifest = load_manifest(repo_root / MANIFEST.relative_to(REPO_ROOT))
    summary = build_summary(repo_root, manifest)
    json_text = render_json(summary)
    md_text = render_markdown(summary)

    if args.check:
        stale: list[str] = []
        if not JSON_OUT.exists() or JSON_OUT.read_text(encoding="utf-8") != json_text:
            stale.append(str(JSON_OUT.relative_to(REPO_ROOT)))
        if not MD_OUT.exists() or MD_OUT.read_text(encoding="utf-8") != md_text:
            stale.append(str(MD_OUT.relative_to(REPO_ROOT)))
        if stale:
            print("DOCS_PROGRAM_MERGE_BACK_WAVES_STALE")
            for path in stale:
                print(f"- {path}")
            return 1
        if summary["status"] != "pass":
            print("DOCS_PROGRAM_MERGE_BACK_WAVES_INVALID")
            for item in summary["missing_paths"]:
                print(f"- missing {item['wave']}: {item['path']}")
            for item in summary["overlaps"]:
                print(f"- overlap {item['waves']}: {item['path']}")
            for item in summary["dependency_errors"]:
                print(f"- {item['kind']} {item['wave']}: {item['dependency']}")
            return 1
        print("DOCS_PROGRAM_MERGE_BACK_WAVES_OK")
        return 0

    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    MD_OUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUT.write_text(json_text, encoding="utf-8")
    MD_OUT.write_text(md_text, encoding="utf-8")
    print("DOCS_PROGRAM_MERGE_BACK_WAVES_WRITTEN")
    print(f"- {JSON_OUT.relative_to(REPO_ROOT)}")
    print(f"- {MD_OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
