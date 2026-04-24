#!/usr/bin/env python3
"""Build the Wave 5 human-facing review bundle for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.knowledge.build_change_manifest import build_manifest

CLASS_PRIORITY = {
    "normative_contract_change": 0,
    "proposal_only": 1,
    "plan_only": 2,
    "compatibility_wrapper_update": 3,
    "docs_support_change": 4,
    "evidence_only_change": 5,
    "generated_surface_refresh": 6,
    "reviewer_handoff_only": 7,
    "archival_only_change": 8,
}


def summarize_counts(entries: list[dict], key: str) -> list[str]:
    counts = Counter(entry.get(key, "other") for entry in entries)
    return [f"- `{name}`: {counts[name]}" for name in sorted(counts)]


def required_evidence(entries: list[dict]) -> list[str]:
    obligations = {
        "status update": "require_status_update",
        "evidence pack": "require_evidence_pack",
        "runbook update": "require_runbook_update",
        "ADR update": "require_adr_update",
        "plan refresh": "require_plan_refresh",
        "testplan refresh": "require_testplan_refresh",
    }
    missing = []
    for label, key in obligations.items():
        affected = [entry["path"] for entry in entries if entry.get("evidence", {}).get(key)]
        if affected:
            preview = ", ".join(f"`{path}`" for path in affected[:3])
            suffix = "" if len(affected) <= 3 else f", +{len(affected) - 3} more"
            missing.append(f"- {label}: {preview}{suffix}")
    return missing or ["- none"]


def read_first(entries: list[dict]) -> list[str]:
    ordered = sorted(
        entries,
        key=lambda entry: (
            CLASS_PRIORITY.get(entry.get("change_class", "generated_surface_refresh"), 99),
            entry.get("change_risk", "low"),
            entry.get("path", ""),
        ),
    )
    lines = []
    for entry in ordered[:12]:
        lines.append(
            f"- `{entry['path']}`"
            f" [{entry.get('change_class', 'unknown')}; risk={entry.get('change_risk', 'low')}]"
        )
    return lines or ["- none"]


def ignore_first(entries: list[dict]) -> list[str]:
    ignored = [
        entry
        for entry in entries
        if entry.get("change_class") in {"generated_surface_refresh", "reviewer_handoff_only", "archival_only_change"}
    ]
    ignored = sorted(ignored, key=lambda entry: entry.get("path", ""))[:12]
    lines = [f"- `{entry['path']}` [{entry.get('change_class')}]" for entry in ignored]
    return lines or ["- none"]


def grouped_paths(entries: list[dict], key: str) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for entry in entries:
        grouped[str(entry.get(key, "other"))].append(entry["path"])
    return {name: sorted(paths) for name, paths in grouped.items()}


def build_bundle(repo_root: Path, range_spec: str) -> str:
    manifest = build_manifest(repo_root, range_spec)
    entries = manifest["entries"]
    review_required = manifest["required_reviewers"] or ["none"]
    impacted = manifest["impacted_truth_surfaces"][:20]

    lines = [
        "# Wave 5 Review Bundle",
        "",
        f"- Range: `{range_spec}`",
        f"- Changes classified: `{manifest['change_count']}`",
        f"- Roots touched: {', '.join(f'`{root}`' for root in manifest['changed_roots']) or '`none`'}",
        f"- Required reviewers: {', '.join(f'`{name}`' for name in review_required)}",
        "",
        "## What Changed",
        "",
        "### Change Classes",
        *summarize_counts(entries, "change_class"),
        "",
        "### Lanes",
        *summarize_counts(entries, "lane"),
        "",
        "## Read First",
        *read_first(entries),
        "",
        "## Safe To Triage Later",
        *ignore_first(entries),
        "",
        "## Required Evidence And Follow-Up",
        *required_evidence(entries),
        "",
        "## Impacted Truth Surfaces",
    ]

    if impacted:
        lines.extend(f"- `{path}`" for path in impacted)
    else:
        lines.append("- none")

    lines.extend(["", "## Owner Teams By Change Class"])
    by_class = grouped_paths(entries, "change_class")
    for change_class in sorted(by_class, key=lambda name: CLASS_PRIORITY.get(name, 99)):
        owners = sorted(
            {
                entry["review"].get("owner_team", "")
                for entry in entries
                if entry.get("change_class") == change_class and entry.get("review", {}).get("owner_team")
            }
        )
        owner_text = ", ".join(f"`{owner}`" for owner in owners) if owners else "`unowned`"
        lines.append(f"- `{change_class}` -> {owner_text}")

    lines.extend(["", "## Changed Files By Lane"])
    by_lane = grouped_paths(entries, "lane")
    for lane in sorted(by_lane):
        lines.append(f"### {lane}")
        lines.extend(f"- `{path}`" for path in by_lane[lane][:20])
        if len(by_lane[lane]) > 20:
            lines.append(f"- `... {len(by_lane[lane]) - 20} more`")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/knowledge/review-bundle.md")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    rendered = build_bundle(repo_root, args.range_spec)

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("REVIEW_BUNDLE_DRIFT")
        print("REVIEW_BUNDLE_OK mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print("REVIEW_BUNDLE_OK mode=write")


if __name__ == "__main__":
    main()
