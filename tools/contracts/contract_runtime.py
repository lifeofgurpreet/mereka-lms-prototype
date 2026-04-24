#!/usr/bin/env python3
"""Helpers for the Wave 6 cross-repo contract runtime."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]


def load_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text())


def changed_files(repo_root: Path, range_spec: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", range_spec],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def load_service_contracts(repo_root: Path) -> dict[str, dict[str, Any]]:
    contracts: dict[str, dict[str, Any]] = {}
    for path in sorted((repo_root / "deploy" / "contracts" / "service-contracts").glob("*.yaml")):
        data = load_yaml(path)
        data["contract_path"] = path.relative_to(repo_root).as_posix()
        contracts[data["service"]] = data
    return contracts


def load_crosswalk(repo_root: Path) -> dict[str, dict[str, Any]]:
    data = load_yaml(repo_root / "deploy" / "contracts" / "infra-crosswalk.yaml")
    return data["crosswalk"]


def build_service_surface_index(contracts: dict[str, dict[str, Any]]) -> dict[str, set[str]]:
    index: dict[str, set[str]] = {}
    for service, contract in contracts.items():
        surfaces: set[str] = {contract["contract_path"]}
        surfaces.update(contract.get("secret_surfaces", []))
        surfaces.update(contract.get("runbook_surfaces", []))
        surfaces.update(contract.get("evidence_surfaces", []))
        image_source = contract.get("image_source") or {}
        surfaces.update(image_source.get("source_surfaces", []))
        index[service] = surfaces
    return index


def match_services(rel_path: str, contracts: dict[str, dict[str, Any]], crosswalk: dict[str, dict[str, Any]]) -> list[str]:
    matched: set[str] = set()
    surface_index = build_service_surface_index(contracts)
    for service, surfaces in surface_index.items():
        if rel_path in surfaces:
            matched.add(service)
        for surface in crosswalk.get(service, {}).get("app_repo_surfaces", []):
            if rel_path == surface:
                matched.add(service)
    return sorted(matched)


def classify_service_impact(service: str, contract: dict[str, Any], crosswalk_entry: dict[str, Any]) -> str:
    expectation = contract.get("infra_counterpart_expectation", "conditional")
    status = (crosswalk_entry.get("infra_counterpart") or {}).get("status", "unknown")

    if status == "unknown":
        return "unknown_mapping"
    if expectation is True:
        return "infra_counterpart_required"
    if expectation is False:
        return "infra_counterpart_not_required"
    if status == "explicit":
        return "infra_counterpart_required"
    if status == "partial":
        return "manual_review_required"
    return "unknown_mapping"


def overall_verdict(verdicts: list[str]) -> str:
    precedence = [
        "unknown_mapping",
        "infra_counterpart_required",
        "manual_review_required",
        "infra_counterpart_not_required",
    ]
    for verdict in precedence:
        if verdict in verdicts:
            return verdict
    return "infra_counterpart_not_required"
