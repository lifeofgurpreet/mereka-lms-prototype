#!/usr/bin/env python3
"""Build Wave 7 task bundles for agent consumption."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.resolve_task_context import resolve_context
from tools.knowledge.skill_runtime import load_runtime_inputs


def split_related_surfaces(bundle: dict) -> tuple[list[str], list[str], list[str]]:
    related_contracts = [p for p in bundle["affected_truth_surfaces"] if p.startswith("deploy/contracts/") or p.startswith("docs/meta/contracts/")]
    related_specs = [p for p in bundle["affected_truth_surfaces"] if p.startswith("specs/")]
    related_runbooks = [p for p in bundle["affected_truth_surfaces"] if "/runbook" in p.lower() or "/runbooks/" in p.lower() or p.startswith("docs/ops/")]
    return sorted(set(related_contracts)), sorted(set(related_specs)), sorted(set(related_runbooks))


def build_bundle_payload(repo_root: Path, range_spec: str, task_type: str) -> dict:
    runtime = load_runtime_inputs(repo_root)
    taxonomy_rule = runtime["taxonomy"]["task_types"][task_type]
    context = resolve_context(repo_root, range_spec, task_type)
    related_contracts, related_specs, related_runbooks = split_related_surfaces(context)

    source_runtime_artifacts = [
        "generated/knowledge/change-manifest.json",
        "generated/knowledge/review-bundle.md",
        "generated/knowledge/truth-impact-report.json",
        "generated/knowledge/wrapper-retirement-report.json",
        "generated/contracts/cross-repo-manifest.json",
        "generated/contracts/deployment-impact-report.json",
        "generated/contracts/release-obligations.md",
    ]

    bundle = {
        "task_type": task_type,
        "intent": taxonomy_rule["description"],
        "authority_order": runtime["bundle_rules"]["authority_order"],
        "primary_roots": taxonomy_rule.get("primary_signal_roots", []),
        "read_first": context["read_first"],
        "related_contracts": related_contracts,
        "related_specs": related_specs,
        "related_runbooks": related_runbooks,
        "related_generated_surfaces": context["generated_surfaces_implicated"],
        "affected_truth_surfaces": context["affected_truth_surfaces"] or [item["path"] for item in context["read_first"]],
        "required_reviewers": context["reviewers_required"],
        "required_evidence": context["evidence_required"],
        "required_commands": context["commands_required"],
        "likely_cross_repo_dependencies": context["cross_repo_dependencies"],
        "out_of_scope": runtime["bundle_rules"]["forbidden_surfaces_by_task_type"].get(task_type, []),
        "escalation_conditions": runtime["bundle_rules"]["escalation_triggers"].get(task_type, []),
        "source_runtime_artifacts": [p for p in source_runtime_artifacts if (repo_root / p).exists()],
        "generated_by": "tools/knowledge/build_task_bundle.py",
        "bundle_version": 1,
        "bundle_json_path": f"generated/knowledge/task-bundles/{task_type}.json",
        "bundle_markdown_path": f"generated/knowledge/task-bundles/{task_type}.md",
    }
    return bundle


def render_markdown(bundle: dict) -> str:
    lines = [
        f"# Task Bundle: {bundle['task_type']}",
        "",
        f"- Intent: {bundle['intent']}",
        "",
        "## Read First",
    ]
    for item in bundle["read_first"]:
        lines.append(f"- `{item['path']}` priority `{item['priority']}`: {item['reason']}")
    lines.extend(["", "## Commands"])
    lines.extend(f"- `{cmd}`" for cmd in bundle["required_commands"])
    lines.extend(["", "## Related Contracts"])
    lines.extend(f"- `{path}`" for path in bundle["related_contracts"] or ["none"])
    lines.extend(["", "## Related Specs"])
    lines.extend(f"- `{path}`" for path in bundle["related_specs"] or ["none"])
    lines.extend(["", "## Related Runbooks"])
    lines.extend(f"- `{path}`" for path in bundle["related_runbooks"] or ["none"])
    lines.extend(["", "## Reviewers And Evidence"])
    lines.extend(f"- reviewers: {', '.join(bundle['required_reviewers']) or 'none'}")
    lines.extend(f"- evidence: {', '.join(bundle['required_evidence']) or 'none'}")
    lines.extend(["", "## Cross-Repo Dependencies"])
    if bundle["likely_cross_repo_dependencies"]:
        for item in bundle["likely_cross_repo_dependencies"]:
            lines.append(
                f"- `{item['service']}` -> `{item['verdict']}`; "
                f"reviewers: {', '.join(item['reviewers']) or 'none'}"
            )
    else:
        lines.append("- none")
    lines.extend(["", "## Out Of Scope"])
    lines.extend(f"- `{item}`" for item in bundle["out_of_scope"] or ["none"])
    lines.extend(["", "## Escalation Conditions"])
    lines.extend(f"- {item}" for item in bundle["escalation_conditions"] or ["none"])
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--task-type")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--output-dir", default="generated/knowledge/task-bundles")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    runtime = load_runtime_inputs(repo_root)
    if args.task_type and args.all:
        raise SystemExit("Use --task-type or --all, not both")
    if args.task_type:
        task_types = [args.task_type]
    else:
        task_types = runtime["taxonomy"]["task_resolution_order"]
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
