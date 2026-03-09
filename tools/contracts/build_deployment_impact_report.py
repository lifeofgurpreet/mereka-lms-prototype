#!/usr/bin/env python3
"""Build the Wave 6 deployment impact report for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.contracts.build_cross_repo_manifest import build_manifest
from tools.contracts.contract_runtime import load_crosswalk, load_service_contracts, overall_verdict


def build_report(repo_root: Path, range_spec: str) -> dict:
    manifest = build_manifest(repo_root, range_spec)
    contracts = load_service_contracts(repo_root)
    crosswalk = load_crosswalk(repo_root)

    deployment_impacts = []
    required_reviewers = set()
    required_repos = set()

    for service_entry in manifest["services"]:
        service = service_entry["service"]
        contract = contracts[service]
        crosswalk_entry = crosswalk[service]["infra_counterpart"]
        review_groups = set(contract.get("review_groups", []))
        required_reviewers.update(review_groups)
        if service_entry["cross_repo_verdict"] != "infra_counterpart_not_required":
            required_repos.add(contract["deployment_repo"])

        deployment_impacts.append(
            {
                "service": service,
                "cross_repo_verdict": service_entry["cross_repo_verdict"],
                "deployment_repo": contract["deployment_repo"],
                "overlay_roots": crosswalk_entry.get("overlays", {}),
                "argocd_surfaces": crosswalk_entry.get("argocd_surfaces", []),
                "required_reviewers": sorted(review_groups),
                "notes": crosswalk_entry.get("notes", []),
                "unknowns": crosswalk_entry.get("unknowns", []),
            }
        )

    return {
        "generated_by": "tools/contracts/build_deployment_impact_report.py",
        "range": range_spec,
        "overall_verdict": manifest["overall_verdict"],
        "required_repositories": sorted(required_repos),
        "required_reviewers": sorted(required_reviewers),
        "service_count": len(deployment_impacts),
        "deployment_impacts": deployment_impacts,
        "summary": {
            "infra_counterpart_required": [
                item["service"] for item in deployment_impacts if item["cross_repo_verdict"] == "infra_counterpart_required"
            ],
            "manual_review_required": [
                item["service"] for item in deployment_impacts if item["cross_repo_verdict"] == "manual_review_required"
            ],
            "unknown_mapping": [
                item["service"] for item in deployment_impacts if item["cross_repo_verdict"] == "unknown_mapping"
            ],
            "infra_counterpart_not_required": [
                item["service"] for item in deployment_impacts if item["cross_repo_verdict"] == "infra_counterpart_not_required"
            ],
        },
        "cross_repo_manifest_overall_verdict": overall_verdict(
            [item["cross_repo_verdict"] for item in deployment_impacts]
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/contracts/deployment-impact-report.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    report = build_report(repo_root, args.range_spec)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("DEPLOYMENT_IMPACT_REPORT_DRIFT")
        print(
            "DEPLOYMENT_IMPACT_REPORT_OK "
            f"services={report['service_count']} verdict={report['overall_verdict']} mode=check"
        )
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(
        "DEPLOYMENT_IMPACT_REPORT_OK "
        f"services={report['service_count']} verdict={report['overall_verdict']} mode=write"
    )


if __name__ == "__main__":
    main()
