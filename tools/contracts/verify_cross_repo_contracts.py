#!/usr/bin/env python3
"""Verify the Wave 6 cross-repo contract runtime for a diff range."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.contracts.build_cross_repo_manifest import build_manifest
from tools.contracts.build_deployment_impact_report import build_report
from tools.contracts.contract_runtime import load_service_contracts, load_yaml


def verify(repo_root: Path, range_spec: str) -> tuple[int, list[str], dict]:
    manifest = build_manifest(repo_root, range_spec)
    impact = build_report(repo_root, range_spec)
    contracts = load_service_contracts(repo_root)
    ownership = load_yaml(repo_root / "docs" / "meta" / "contracts" / "CROSS_REPO_OWNERSHIP.yaml")
    high_risk = set(ownership.get("high_risk_surfaces", {}))
    errors: list[str] = []

    release_md = (repo_root / "generated" / "contracts" / "release-obligations.md").read_text()
    service_by_name = {item["service"]: item for item in impact["deployment_impacts"]}

    for service, contract in contracts.items():
        if contract["high_risk_surface"] not in high_risk:
            errors.append(f"{service}: unknown high-risk surface {contract['high_risk_surface']}")

    for service_name, service_impact in service_by_name.items():
        contract = contracts[service_name]
        verdict = service_impact["cross_repo_verdict"]
        if verdict == "unknown_mapping" and contract["high_risk_surface"] in high_risk:
            errors.append(f"{service_name}: high-risk service has unknown_mapping verdict")
        if verdict != "infra_counterpart_not_required" and contract["deployment_repo"] not in impact["required_repositories"]:
            errors.append(f"{service_name}: deployment repo missing from required_repositories")
        if f"### {service_name}" not in release_md:
            errors.append(f"{service_name}: missing service section in release-obligations.md")

    for entry in manifest["entries"]:
        path = entry["path"]
        touched = entry["touched_services"]
        if path.startswith("deploy/contracts/service-contracts/") and not touched:
            errors.append(f"{path}: service contract changed without touched service classification")
        if path == "deploy/contracts/infra-crosswalk.yaml" and impact["service_count"] == 0:
            errors.append("infra-crosswalk changed but deployment impact report has zero services")

    summary = {
        "change_count": manifest["change_count"],
        "touched_services": impact["service_count"],
        "required_repositories": impact["required_repositories"],
        "overall_verdict": impact["overall_verdict"],
    }
    return (1 if errors else 0, errors, summary)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    code, errors, summary = verify(repo_root, args.range_spec)
    if errors:
        for error in errors:
            print(f"CROSS_REPO_CONTRACT_ERROR {error}")
        raise SystemExit(code)

    print(
        "CROSS_REPO_CONTRACTS_OK "
        f"changes={summary['change_count']} "
        f"services={summary['touched_services']} "
        f"verdict={summary['overall_verdict']} "
        f"repos={','.join(summary['required_repositories']) or 'none'}"
    )


if __name__ == "__main__":
    main()
