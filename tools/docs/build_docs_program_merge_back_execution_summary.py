#!/usr/bin/env python3
"""Generate docs-program merge-back execution summary artifacts from wave receipts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parents[2]
WAVES_MANIFEST = REPO_ROOT / "docs" / "meta" / "docs-program" / "metadata" / "merge-back-waves.v1.yaml"
EXECUTION_MANIFEST = REPO_ROOT / "docs" / "meta" / "docs-program" / "metadata" / "merge-back-wave-execution.v1.yaml"
JSON_OUT = REPO_ROOT / "generated" / "catalogs" / "docs-program-merge-back-execution.json"
MD_OUT = REPO_ROOT / "docs" / "reference" / "generated" / "docs-program-merge-back-execution.md"
COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")
PR_URL_RE = re.compile(r"^https://github\.com/[^/]+/[^/]+/pull/\d+$")
MERGE_COMMIT_RE = COMMIT_RE


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit non-zero if generated files are stale")
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="repository root")
    return parser.parse_args()


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def build_summary(repo_root: Path) -> dict:
    waves_manifest = load_yaml(repo_root / WAVES_MANIFEST.relative_to(REPO_ROOT))
    execution_manifest = load_yaml(repo_root / EXECUTION_MANIFEST.relative_to(REPO_ROOT))
    waves = waves_manifest.get("waves", [])
    executions = execution_manifest.get("executions", [])
    allowed_statuses = set(str(v) for v in execution_manifest.get("allowed_statuses", []))

    wave_map = {str(wave["id"]): wave for wave in waves}
    seen_wave_ids: set[str] = set()
    seen_branches: set[str] = set()
    errors: list[dict[str, str]] = []
    rows: list[dict] = []

    for execution in executions:
        wave_id = str(execution["wave_id"])
        branch = str(execution["branch"])
        tip_commit = str(execution["tip_commit"])
        status = str(execution["status"])
        pr_url = execution.get("pr_url")
        pr_url_str = str(pr_url) if pr_url is not None else None
        merged_commit = execution.get("merged_commit")
        merged_commit_str = str(merged_commit) if merged_commit is not None else None
        superseded_by_wave = execution.get("superseded_by_wave")
        superseded_by_wave_str = str(superseded_by_wave) if superseded_by_wave is not None else None
        if wave_id not in wave_map:
            errors.append({"kind": "unknown_wave", "value": wave_id})
            continue
        if wave_id in seen_wave_ids:
            errors.append({"kind": "duplicate_wave", "value": wave_id})
            continue
        if branch in seen_branches:
            errors.append({"kind": "duplicate_branch", "value": branch})
            continue
        if status not in allowed_statuses:
            errors.append({"kind": "invalid_status", "value": f"{wave_id}:{status}"})
        if not COMMIT_RE.match(tip_commit):
            errors.append({"kind": "invalid_commit", "value": f"{wave_id}:{tip_commit}"})
        if pr_url_str is not None and not PR_URL_RE.match(pr_url_str):
            errors.append({"kind": "invalid_pr_url", "value": f"{wave_id}:{pr_url_str}"})
        if merged_commit_str is not None and not MERGE_COMMIT_RE.match(merged_commit_str):
            errors.append({"kind": "invalid_merged_commit", "value": f"{wave_id}:{merged_commit_str}"})
        if status == "pr_open_draft" and not pr_url_str:
            errors.append({"kind": "missing_pr_url", "value": wave_id})
        if status == "merged" and not pr_url_str:
            errors.append({"kind": "missing_pr_url", "value": wave_id})
        if status == "merged" and not merged_commit_str:
            errors.append({"kind": "missing_merged_commit", "value": wave_id})
        if status == "superseded" and not superseded_by_wave_str:
            errors.append({"kind": "missing_superseded_by_wave", "value": wave_id})
        if superseded_by_wave_str is not None and superseded_by_wave_str not in wave_map:
            errors.append({"kind": "unknown_superseded_by_wave", "value": f"{wave_id}:{superseded_by_wave_str}"})
        seen_wave_ids.add(wave_id)
        seen_branches.add(branch)
        wave = wave_map[wave_id]
        rows.append(
            {
                "wave_id": wave_id,
                "title": str(wave["title"]),
                "status": status,
                "branch": branch,
                "tip_commit": tip_commit,
                "pr_url": pr_url_str,
                "merged_commit": merged_commit_str,
                "superseded_by_wave": superseded_by_wave_str,
                "depends_on": [str(v) for v in wave.get("depends_on", [])],
                "pr_title": str(wave["pr_title"]),
                "include_count": len(wave.get("include_paths", [])),
                "remove_count": len(wave.get("remove_paths", [])),
                "validators": [str(v) for v in wave.get("validators", [])],
            }
        )

    for wave_id in wave_map:
        if wave_id not in seen_wave_ids:
            errors.append({"kind": "missing_execution", "value": wave_id})

    order = [str(wave["id"]) for wave in waves]
    rows.sort(key=lambda row: order.index(row["wave_id"]))
    return {
        "source_wave_manifest": "docs/meta/docs-program/metadata/merge-back-waves.v1.yaml",
        "source_execution_manifest": "docs/meta/docs-program/metadata/merge-back-wave-execution.v1.yaml",
        "wave_manifest_last_updated": str(waves_manifest.get("last_updated", "unknown")),
        "execution_manifest_last_updated": str(execution_manifest.get("last_updated", "unknown")),
        "wave_count": len(waves),
        "execution_count": len(rows),
        "executions": rows,
        "errors": errors,
        "status": "fail" if errors else "pass",
    }


def render_json(summary: dict) -> str:
    return json.dumps(summary, indent=2) + "\n"


def render_markdown(summary: dict) -> str:
    lines = [
        "# Docs Program Merge-Back Execution",
        "",
        "_Generated from `docs/meta/docs-program/metadata/merge-back-wave-execution.v1.yaml`"
        f" (last updated {summary['execution_manifest_last_updated']})._",
        "_Do not hand-edit. Regenerate with:"
        " `python3 tools/docs/build_docs_program_merge_back_execution_summary.py`_",
        "",
        "## Overview",
        "",
        "| Measure | Count |",
        "|---|---:|",
        f"| Defined waves | {summary['wave_count']} |",
        f"| Recorded executions | {summary['execution_count']} |",
        f"| Execution manifest errors | {len(summary['errors'])} |",
        "",
    ]
    for row in summary["executions"]:
        lines.extend(
            [
                f"## {row['wave_id']}: {row['title']}",
                "",
                f"- status: `{row['status']}`",
                f"- branch: `{row['branch']}`",
                f"- tip commit: `{row['tip_commit']}`",
                f"- PR: {row['pr_url']}" if row["pr_url"] else "- PR: not opened",
                f"- merged commit: `{row['merged_commit']}`" if row["merged_commit"] else None,
                f"- superseded by: `{row['superseded_by_wave']}`" if row["superseded_by_wave"] else None,
                f"- depends on: `{', '.join(row['depends_on'])}`" if row["depends_on"] else "- depends on: none",
                f"- proposed PR title: `{row['pr_title']}`",
                f"- include paths: `{row['include_count']}`",
                f"- remove paths: `{row['remove_count']}`",
                "- validators:",
            ]
        )
        lines = [line for line in lines if line is not None]
        for validator in row["validators"]:
            lines.append(f"  - `{validator}`")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    summary = build_summary(repo_root)
    json_text = render_json(summary)
    md_text = render_markdown(summary) + "\n"

    if args.check:
        stale: list[str] = []
        if not JSON_OUT.exists() or JSON_OUT.read_text(encoding="utf-8") != json_text:
            stale.append(str(JSON_OUT.relative_to(REPO_ROOT)))
        if not MD_OUT.exists() or MD_OUT.read_text(encoding="utf-8") != md_text:
            stale.append(str(MD_OUT.relative_to(REPO_ROOT)))
        if stale:
            print("DOCS_PROGRAM_MERGE_BACK_EXECUTION_STALE")
            for path in stale:
                print(f"- {path}")
            return 1
        if summary["status"] != "pass":
            print("DOCS_PROGRAM_MERGE_BACK_EXECUTION_INVALID")
            for item in summary["errors"]:
                print(f"- {item['kind']}: {item['value']}")
            return 1
        print("DOCS_PROGRAM_MERGE_BACK_EXECUTION_OK")
        return 0

    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    MD_OUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUT.write_text(json_text, encoding="utf-8")
    MD_OUT.write_text(md_text, encoding="utf-8")
    print("DOCS_PROGRAM_MERGE_BACK_EXECUTION_WRITTEN")
    print(f"- {JSON_OUT.relative_to(REPO_ROOT)}")
    print(f"- {MD_OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
