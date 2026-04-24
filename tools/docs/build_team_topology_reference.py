#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


DEFAULT_JSON_OUTPUT = Path("generated/platform/team-topology-reference.json")
DEFAULT_MD_OUTPUT = Path("docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md")
DOMAIN_ACCESS_INPUT = Path("generated/platform/domain-access-reference.json")
BOOTSTRAP_TOPOLOGY_INPUT = Path("/home/gurpreet/projects/k8s/bbi-infrastructure/config/bootstrap-lane-topology.yaml")
DOMAIN_REGISTRY_INPUT = Path("/home/gurpreet/projects/k8s/bbi-infrastructure/config/domain-registry.yaml")
SERVICE_IDENTITY_INPUT = Path("/home/gurpreet/projects/platform-control-plane/contracts/service-identity-contract.yaml")
RELEASE_CONTRACTS_INPUT = Path("/home/gurpreet/projects/platform-control-plane/contracts/release-contracts.yaml")
USER_FACING_URLS_INPUT = Path("docs/reference/operations/USER_FACING_URLS.md")
MULTI_SITE_GUIDE_INPUT = Path("docs/guides/admin/MULTI_SITE_GUIDE.md")

CANONICAL_INPUTS = [
    "generated/platform/domain-access-reference.json",
    "bbi-infrastructure/config/bootstrap-lane-topology.yaml",
    "bbi-infrastructure/config/domain-registry.yaml",
    "platform-control-plane/contracts/service-identity-contract.yaml",
    "platform-control-plane/contracts/release-contracts.yaml",
    "docs/reference/operations/USER_FACING_URLS.md",
    "docs/guides/admin/MULTI_SITE_GUIDE.md",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 14 team topology reference.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--json-output", default=str(DEFAULT_JSON_OUTPUT))
    parser.add_argument("--md-output", default=str(DEFAULT_MD_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def ensure_exists(path: Path, label: str) -> Path:
    if not path.exists():
        raise FileNotFoundError(f"Missing {label}: {path}")
    return path


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text())


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_or_check(path: Path, content: str, check: bool, label: str) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"{label} drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def extract_bullets(text: str, marker: str) -> list[str]:
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit(f"Required marker missing: {marker}")
    lines = text[idx:].splitlines()[1:]
    bullets: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if bullets:
                break
            continue
        if stripped.startswith("**") and bullets:
            break
        if stripped.startswith("- "):
            bullets.append(stripped[2:])
        elif bullets:
            break
    if not bullets:
        raise SystemExit(f"No bullets found after marker: {marker}")
    return bullets


def extract_table_rows(text: str, heading: str) -> list[dict[str, str]]:
    idx = text.find(heading)
    if idx == -1:
        raise SystemExit(f"Required heading missing: {heading}")
    section = text[idx:].split("\n### ", 1)[0]
    lines = [line.strip() for line in section.splitlines() if line.strip()]
    table_start = next((i for i, line in enumerate(lines) if line.startswith("|")), None)
    if table_start is None or table_start + 2 > len(lines):
        raise SystemExit(f"Table missing under heading: {heading}")
    header = [cell.strip() for cell in lines[table_start].strip("|").split("|")]
    rows: list[dict[str, str]] = []
    for line in lines[table_start + 2 :]:
        if not line.startswith("|"):
            break
        values = [cell.strip() for cell in line.strip("|").split("|")]
        if len(values) != len(header):
            continue
        rows.append(dict(zip(header, values, strict=True)))
    return rows


def build_lane_entries(bootstrap_topology: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for lane, payload in bootstrap_topology["lanes"].items():
        entries.append(
            {
                "lane": lane,
                "cluster_class": payload["cluster_class"],
                "root_count": len(payload["roots"]),
                "note": payload.get("note"),
                "roots": [
                    {
                        "name": root["name"],
                        "path": root["path"],
                        "owns": root["owns"],
                        "prune": root["prune"],
                        "reason": root["reason"],
                        "active": root.get("active", True),
                    }
                    for root in payload["roots"]
                ],
            }
        )
    entries.sort(key=lambda item: item["lane"])
    return entries


def build_tenant_entries(domain_access: dict[str, Any]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    for entry in domain_access["entries"]:
        tenant = entry["tenant_site"]
        tenant_payload = grouped.setdefault(
            tenant,
            {
                "tenant_site": tenant,
                "tenant_display_name": entry["tenant_display_name"],
                "lanes_present": [],
                "lane_domains": {},
                "status": "resolved",
                "unresolved_fields": [],
            },
        )
        tenant_payload["lanes_present"].append(entry["lane"])
        tenant_payload["lane_domains"][entry["lane"]] = {
            "learner_url": entry["learner_url"],
            "studio_url": entry["studio_url"],
            "admin_url": entry["admin_url"],
            "support_ops_url": entry["support_ops_url"],
            "extra_urls": entry.get("extra_urls", {}),
        }
        if entry["status"] != "resolved":
            tenant_payload["status"] = entry["status"]
    for conflict in domain_access["unresolved_conflicts"]:
        grouped[conflict["tenant_site"]]["unresolved_fields"].append(conflict["field"])
    return [grouped[key] for key in sorted(grouped)]


def build_payload(repo_root: Path) -> dict[str, Any]:
    domain_access = load_json(ensure_exists(repo_root / DOMAIN_ACCESS_INPUT, "domain access reference"))
    bootstrap_topology = load_yaml(ensure_exists(BOOTSTRAP_TOPOLOGY_INPUT, "bootstrap lane topology"))
    domain_registry = load_yaml(ensure_exists(DOMAIN_REGISTRY_INPUT, "domain registry"))
    service_identity = load_yaml(ensure_exists(SERVICE_IDENTITY_INPUT, "service identity contract"))
    release_contracts = load_yaml(ensure_exists(RELEASE_CONTRACTS_INPUT, "release contracts"))
    user_facing_text = ensure_exists(repo_root / USER_FACING_URLS_INPUT, "user-facing URLs").read_text()
    multi_site_text = ensure_exists(repo_root / MULTI_SITE_GUIDE_INPUT, "multi-site guide").read_text()

    isolated_per_tenant = extract_bullets(user_facing_text, "**Isolated per Tenant**:")
    shared_across_tenants = extract_bullets(user_facing_text, "**Shared Across Tenants**:")
    production_domain_rows = extract_table_rows(multi_site_text, "### Production Domains")

    service_release_lanes = sorted(release_contracts["lanes"].keys())
    canonical_services = [service["service_id"] for service in service_identity["canonical_services"]]
    lane_entries = build_lane_entries(bootstrap_topology)
    tenant_entries = build_tenant_entries(domain_access)

    return {
        "pack_id": "team-topology-reference",
        "schema_version": 1,
        "generated_by": "tools/docs/build_team_topology_reference.py",
        "canonical_inputs": CANONICAL_INPUTS,
        "topology_truth_lives_in": [
            "bbi-infrastructure/config/bootstrap-lane-topology.yaml",
            "bbi-infrastructure/config/domain-registry.yaml",
            "platform-control-plane/contracts/service-identity-contract.yaml",
            "platform-control-plane/contracts/release-contracts.yaml",
        ],
        "humans_should_not_edit_directly": [
            "generated/platform/domain-access-reference.json",
            "generated/platform/team-topology-reference.json",
            "docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md",
            "docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md",
        ],
        "lane_environment_relationships": lane_entries,
        "tenant_site_relationships": tenant_entries,
        "isolated_per_tenant": isolated_per_tenant,
        "shared_across_tenants": shared_across_tenants,
        "platform_services": {
            "canonical_service_ids": canonical_services,
            "release_contract_lanes": service_release_lanes,
            "global_platform_endpoints": sorted(domain_registry["platform"].keys()),
        },
        "multi_site_guide_domain_rows": production_domain_rows,
        "unresolved_conflicts": domain_access["unresolved_conflicts"],
    }


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "<!-- Generated file. Do not hand-edit. -->",
        "# Team Topology Reference",
        "",
        "This page is a projection from lane topology, domain registry, release-control contracts, and the generated domain access reference.",
        "",
        f"- Canonical JSON: `generated/platform/team-topology-reference.json`",
        f"- Generated by: `{payload['generated_by']}`",
        "",
        "## Lane And Environment Relationships",
        "",
        "| Lane | Cluster Class | Root Count | Notes |",
        "| --- | --- | --- | --- |",
    ]
    for lane in payload["lane_environment_relationships"]:
        lines.append(
            f"| {lane['lane']} | {lane['cluster_class']} | {lane['root_count']} | {lane['note'] or 'n/a'} |"
        )
    lines.extend(["", "## Tenant And Site Relationships", "", "| Tenant/Site | Status | Lanes Present | Unresolved Fields |", "| --- | --- | --- | --- |"])
    for tenant in payload["tenant_site_relationships"]:
        lines.append(
            f"| {tenant['tenant_site']} | {tenant['status']} | {', '.join(tenant['lanes_present'])} | {', '.join(tenant['unresolved_fields']) or 'none'} |"
        )
    lines.extend(["", "## Shared Globally", ""])
    for item in payload["shared_across_tenants"]:
        lines.append(f"- {item}")
    lines.extend(["", "## Tenant-Specific", ""])
    for item in payload["isolated_per_tenant"]:
        lines.append(f"- {item}")
    lines.extend(["", "## Topology Truth Lives In", ""])
    for item in payload["topology_truth_lives_in"]:
        lines.append(f"- `{item}`")
    lines.extend(["", "## Humans Should Not Edit Directly", ""])
    for item in payload["humans_should_not_edit_directly"]:
        lines.append(f"- `{item}`")
    if payload["unresolved_conflicts"]:
        lines.extend(["", "## Explicit Unresolved Conflicts", "", "| Tenant/Site | Field | Observed Values | Resolution |", "| --- | --- | --- | --- |"])
        for item in payload["unresolved_conflicts"]:
            observed = "<br>".join(f"`{value['source']}` -> `{value['value']}`" for value in item["observed_values"])
            lines.append(
                f"| {item['tenant_site']} | {item['field']} | {observed} | {item['resolution']} |"
            )
    lines.extend(["", "## Platform Service Context", ""])
    lines.append(f"- Canonical service IDs: `{', '.join(payload['platform_services']['canonical_service_ids'])}`")
    lines.append(f"- Release contract lanes: `{', '.join(payload['platform_services']['release_contract_lanes'])}`")
    lines.append(f"- Global platform endpoints: `{', '.join(payload['platform_services']['global_platform_endpoints'])}`")
    lines.extend(["", "## Canonical Inputs", ""])
    for item in payload["canonical_inputs"]:
        lines.append(f"- `{item}`")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    json_output = repo_root / args.json_output
    md_output = repo_root / args.md_output

    payload = build_payload(repo_root)
    json_content = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    md_content = render_markdown(payload)
    write_or_check(json_output, json_content, args.check, "TEAM_TOPOLOGY_REFERENCE_JSON")
    write_or_check(md_output, md_content, args.check, "TEAM_TOPOLOGY_REFERENCE_MD")
    mode = "check" if args.check else "write"
    print(
        "TEAM_TOPOLOGY_REFERENCE_OK "
        f"mode={mode} lanes={len(payload['lane_environment_relationships'])} tenants={len(payload['tenant_site_relationships'])} conflicts={len(payload['unresolved_conflicts'])}"
    )


if __name__ == "__main__":
    main()
