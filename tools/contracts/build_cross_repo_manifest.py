#!/usr/bin/env python3
"""Build the Wave 6 machine-readable cross-repo manifest for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.contracts.contract_runtime import (
    changed_files,
    classify_service_impact,
    load_crosswalk,
    load_service_contracts,
    match_services,
    overall_verdict,
)


def classify_path(rel_path: str) -> str:
    if rel_path.startswith("generated/"):
        return "generated_surface_refresh"
    if rel_path.startswith("docs/meta/contracts/") or rel_path.startswith("deploy/contracts/"):
        return "contract_runtime_source"
    if rel_path.startswith("specs/"):
        return "spec_or_plan_change"
    if rel_path.startswith("docs/ops/") or rel_path.startswith("docs/runbooks/") or rel_path.startswith("docs/reference/operations/"):
        return "runbook_or_ops_change"
    if rel_path.startswith("scripts/infra/") or rel_path.startswith(".github/workflows/"):
        return "deployment_pipeline_change"
    return "repo_support_change"


def build_manifest(repo_root: Path, range_spec: str) -> dict:
    contracts = load_service_contracts(repo_root)
    crosswalk = load_crosswalk(repo_root)
    files = changed_files(repo_root, range_spec)

    entries = []
    per_service_paths: dict[str, list[str]] = defaultdict(list)
    service_verdicts: dict[str, str] = {}

    for rel_path in files:
        services = match_services(rel_path, contracts, crosswalk)
        path_verdicts = []
        for service in services:
            verdict = classify_service_impact(service, contracts[service], crosswalk[service])
            path_verdicts.append(verdict)
            per_service_paths[service].append(rel_path)
            service_verdicts[service] = verdict

        entries.append(
            {
                "path": rel_path,
                "path_class": classify_path(rel_path),
                "touched_services": services,
                "cross_repo_verdict": overall_verdict(path_verdicts) if path_verdicts else "infra_counterpart_not_required",
            }
        )

    service_entries = []
    for service, paths in sorted(per_service_paths.items()):
        contract = contracts[service]
        infra = crosswalk[service]["infra_counterpart"]
        service_entries.append(
            {
                "service": service,
                "service_family": contract["service_family"],
                "deployment_repo": contract["deployment_repo"],
                "review_groups": contract.get("review_groups", []),
                "cross_repo_verdict": service_verdicts[service],
                "touched_paths": sorted(set(paths)),
                "overlay_roots": infra.get("overlays", {}),
                "argocd_surfaces": infra.get("argocd_surfaces", []),
                "unknowns": infra.get("unknowns", []),
            }
        )

    counts = Counter(entry["cross_repo_verdict"] for entry in service_entries)

    return {
        "generated_by": "tools/contracts/build_cross_repo_manifest.py",
        "range": range_spec,
        "change_count": len(entries),
        "touched_service_count": len(service_entries),
        "overall_verdict": overall_verdict([entry["cross_repo_verdict"] for entry in service_entries]),
        "classification_counts": dict(sorted(counts.items())),
        "entries": entries,
        "services": service_entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/contracts/cross-repo-manifest.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    manifest = build_manifest(repo_root, args.range_spec)
    rendered = json.dumps(manifest, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("CROSS_REPO_MANIFEST_DRIFT")
        print(
            "CROSS_REPO_MANIFEST_OK "
            f"changes={manifest['change_count']} services={manifest['touched_service_count']} mode=check"
        )
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(
        "CROSS_REPO_MANIFEST_OK "
        f"changes={manifest['change_count']} services={manifest['touched_service_count']} mode=write"
    )


if __name__ == "__main__":
    main()
