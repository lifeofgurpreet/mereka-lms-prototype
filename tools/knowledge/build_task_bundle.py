#!/usr/bin/env python3
"""Build Wave 7 task bundles for agent consumption."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.resolve_task_context import resolve_context
from tools.knowledge.task_runtime import load_task_runtime_inputs


def render_markdown(bundle: dict) -> str:
    lines = [
        f"# Task Bundle: {bundle['task_type']}",
        "",
        f"- Intent: {bundle['one_line_intent']}",
        f"- Range: `{bundle['range']}`",
        "",
        "## Authority Order",
    ]
    lines.extend(f"- `{item}`" for item in bundle["authority_order"])
    lines.extend(["", "## Read First"])
    lines.extend(f"- `{path}`" for path in bundle["read_first"])
    lines.extend(["", "## Generated Surfaces To Refresh"])
    lines.extend(f"- `{path}`" for path in bundle["generated_surfaces_to_refresh"])
    lines.extend(["", "## Affected Truth Surfaces"])
    lines.extend(f"- `{path}`" for path in bundle["affected_truth_surfaces"])
    lines.extend(["", "## Required Reviewers"])
    lines.extend(f"- `{item}`" for item in bundle["required_reviewers"])
    lines.extend(["", "## Required Evidence"])
    lines.extend(f"- `{item}`" for item in bundle["required_evidence"])
    lines.extend(["", "## Required Commands"])
    lines.extend(f"- `{item}`" for item in bundle["required_commands"])
    lines.extend(["", "## Likely Cross-Repo Dependencies"])
    if bundle["likely_cross_repo_dependencies"]:
        for item in bundle["likely_cross_repo_dependencies"]:
            lines.append(
                f"- `{item['service']}` -> verdict `{item['overall_verdict']}`; "
                f"reviewers: {', '.join(item['review_groups']) or 'none'}"
            )
    else:
        lines.append("- none")
    lines.extend(["", "## Out Of Scope"])
    lines.extend(f"- {item}" for item in bundle["out_of_scope"])
    lines.extend(["", "## Escalation Conditions"])
    lines.extend(f"- {item}" for item in bundle["escalation_conditions"])
    return "\n".join(lines).rstrip() + "\n"


def build_bundle_payload(repo_root: Path, range_spec: str, task_type: str) -> dict:
    context = resolve_context(repo_root, range_spec, task_type)
    if not context["affected_truth_surfaces"]:
        context["affected_truth_surfaces"] = list(context["read_first"])
    context["bundle_version"] = 1
    context["bundle_json_path"] = f"generated/knowledge/task-bundles/{task_type}.json"
    context["bundle_markdown_path"] = f"generated/knowledge/task-bundles/{task_type}.md"
    return context


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output-dir", default="generated/knowledge/task-bundles")
    parser.add_argument("--task-type")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    runtime = load_task_runtime_inputs(repo_root)
    task_types = [args.task_type] if args.task_type else runtime["taxonomy"]["task_resolution_order"]
    output_dir = repo_root / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    for task_type in task_types:
        bundle = build_bundle_payload(repo_root, args.range_spec, task_type)
        rendered_json = json.dumps(bundle, indent=2, sort_keys=True) + "\n"
        rendered_md = render_markdown(bundle)
        json_path = output_dir / f"{task_type}.json"
        md_path = output_dir / f"{task_type}.md"
        if args.check:
            if not json_path.exists() or json_path.read_text() != rendered_json:
                raise SystemExit(f"TASK_BUNDLE_JSON_DRIFT:{task_type}")
            if not md_path.exists() or md_path.read_text() != rendered_md:
                raise SystemExit(f"TASK_BUNDLE_MD_DRIFT:{task_type}")
        else:
            json_path.write_text(rendered_json)
            md_path.write_text(rendered_md)

    print(f"TASK_BUNDLES_OK mode={'check' if args.check else 'write'} task_types={len(task_types)}")


if __name__ == "__main__":
    main()
