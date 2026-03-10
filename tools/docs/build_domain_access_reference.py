#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import yaml


DEFAULT_JSON_OUTPUT = Path("generated/platform/domain-access-reference.json")
DEFAULT_MD_OUTPUT = Path("docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md")
DOMAIN_REGISTRY_INPUT = Path("/home/gurpreet/projects/k8s/bbi-infrastructure/config/domain-registry.yaml")
DOMAIN_MATRIX_INPUT = Path("docs/reference/operations/DOMAIN_MATRIX.md")
USER_FACING_URLS_INPUT = Path("docs/reference/operations/USER_FACING_URLS.md")

PRIMARY_CANONICAL_SOURCES = [
    "bbi-infrastructure/config/domain-registry.yaml",
    "docs/reference/operations/DOMAIN_MATRIX.md",
    "docs/reference/operations/USER_FACING_URLS.md",
]

LANE_ORDER = {"dev": 0, "staging": 1, "prod": 2}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Wave 14 domain and access reference.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--json-output", default=str(DEFAULT_JSON_OUTPUT))
    parser.add_argument("--md-output", default=str(DEFAULT_MD_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def ensure_exists(path: Path, label: str) -> Path:
    if not path.exists():
        raise FileNotFoundError(f"Missing {label}: {path}")
    return path


def write_or_check(path: Path, content: str, check: bool, label: str) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"{label} drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def https_url(hostname: str | None) -> str | None:
    if not hostname:
        return None
    return f"https://{hostname}"


def parse_markdown_table(text: str, heading: str) -> list[dict[str, str]]:
    heading_index = text.find(heading)
    if heading_index == -1:
        raise SystemExit(f"Required section not found: {heading}")
    section = text[heading_index:].split("\n## ", 1)[0]
    lines = [line.strip() for line in section.splitlines() if line.strip()]
    table_start = next((i for i, line in enumerate(lines) if line.startswith("|")), None)
    if table_start is None or table_start + 2 > len(lines):
        raise SystemExit(f"Markdown table missing under section: {heading}")
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


def clean_markdown_cell(value: str) -> str:
    cleaned = value.replace("**", "").replace("`", "").strip()
    return cleaned if cleaned not in {"-", "—", ""} else ""


def parse_user_facing_section(text: str, heading: str) -> dict[str, str]:
    heading_index = text.find(heading)
    if heading_index == -1:
        raise SystemExit(f"Required tenant section not found: {heading}")
    section = text[heading_index:].split("\n### ", 1)[0]
    result: dict[str, str] = {}
    lms_match = re.search(r"\*\*LMS\*\*\s*-\s*(https://\S+)", section)
    if lms_match:
        result["learner_url"] = lms_match.group(1).rstrip()
    admin_match = re.search(r"Admin:\s*(https://\S+)", section)
    if admin_match:
        result["admin_url"] = admin_match.group(1).rstrip()
    studio_match = re.search(r"\*\*Studio\*\*\s*-\s*(https://\S+)", section)
    if studio_match:
        result["studio_url"] = studio_match.group(1).rstrip()
    mfe_match = re.search(r"\*\*MFE Hub\*\*\s*-\s*(https://\S+)", section)
    if mfe_match:
        result["mfe_url"] = mfe_match.group(1).rstrip()
    if "shared with main tenant" in section.lower():
        result["studio_url"] = "shared-with-main-tenant"
    if "uses main MFE hub" in section:
        result["mfe_url"] = "shared-main-mfe-hub"
    return result


def build_main_entries(domain_registry: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    platform = domain_registry["platform"]
    openedx = domain_registry["apps"]["openedx"]
    for lane in ["dev", "staging", "prod"]:
        lane_data = openedx.get(lane)
        if not lane_data:
            continue
        learner_url = https_url(lane_data.get("lms"))
        studio_url = https_url(lane_data.get("studio"))
        support_url = https_url(platform["argocd"].get(lane))
        admin_url = f"{learner_url}/admin" if learner_url else None
        entries.append(
            {
                "lane": lane,
                "tenant_site": "main",
                "tenant_display_name": "Mereka Academy",
                "status": "resolved",
                "learner_url": learner_url,
                "studio_url": studio_url,
                "admin_url": admin_url,
                "support_ops_url": support_url,
                "owner": "Platform Team",
                "canonical_source": "bbi-infrastructure/config/domain-registry.yaml",
                "generated_from_registry_contract_input": True,
                "notes": [
                    "Main tenant entry is generated directly from the canonical domain registry.",
                ],
                "extra_urls": {
                    key: https_url(value)
                    for key, value in lane_data.items()
                    if key not in {"lms", "studio"}
                }
                | {
                    "authentik": https_url(platform["authentik"].get(lane)),
                },
            }
        )
    return entries


def build_partner_entries(domain_matrix_text: str, user_facing_text: str, argocd_prod_url: str | None) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    partner_rows = parse_markdown_table(domain_matrix_text, "## Multisite / Subsites (Production Only)")
    partner_entries: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    section_map = {
        "Biji-Biji": "### Biji-Biji Academy Tenant (Production Microsite)",
        "SkillOurFuture": "### SkillOurFuture Tenant (MCT Migration Target)",
    }
    for row in partner_rows:
        tenant_site = clean_markdown_cell(row["Subsite"]).lower().replace("-", "").replace(" ", "_")
        matrix_values = {
            "learner_url": https_url(clean_markdown_cell(row["LMS"])) if clean_markdown_cell(row["LMS"]) else None,
            "studio_url": https_url(clean_markdown_cell(row["Studio"])) if clean_markdown_cell(row["Studio"]) else None,
            "mfe_url": https_url(clean_markdown_cell(row["MFE"])) if clean_markdown_cell(row["MFE"]) else None,
        }
        user_values = parse_user_facing_section(user_facing_text, section_map[clean_markdown_cell(row["Subsite"])])
        conflicts: list[dict[str, Any]] = []
        resolved: dict[str, str | None] = {}
        for field in ["learner_url", "studio_url", "mfe_url"]:
            matrix_value = matrix_values.get(field)
            user_value = user_values.get(field)
            if matrix_value and user_value and matrix_value != user_value:
                conflicts.append(
                    {
                        "tenant_site": tenant_site,
                        "lane": "prod",
                        "field": field,
                        "observed_values": [
                            {"source": "docs/reference/operations/DOMAIN_MATRIX.md", "value": matrix_value},
                            {"source": "docs/reference/operations/USER_FACING_URLS.md", "value": user_value},
                        ],
                        "resolution": "left-null-in-domain-access-reference-until-canonical-source-converges",
                    }
                )
                resolved[field] = None
            else:
                resolved[field] = user_value or matrix_value
        partner_entries.append(
            {
                "lane": "prod",
                "tenant_site": tenant_site,
                "tenant_display_name": clean_markdown_cell(row["Subsite"]),
                "status": "conflict" if conflicts else "resolved",
                "learner_url": resolved["learner_url"],
                "studio_url": resolved["studio_url"],
                "admin_url": user_values.get("admin_url"),
                "support_ops_url": argocd_prod_url,
                "owner": "Platform Team",
                "canonical_source": "docs/reference/operations/DOMAIN_MATRIX.md",
                "generated_from_registry_contract_input": False,
                "notes": [
                    "Production-only tenant alias entry is compiled from current operations references.",
                ],
                "extra_urls": {
                    "mfe": resolved["mfe_url"],
                },
                "source_observations": {
                    "docs/reference/operations/DOMAIN_MATRIX.md": matrix_values,
                    "docs/reference/operations/USER_FACING_URLS.md": user_values,
                },
            }
        )
        unresolved.extend(conflicts)
    return partner_entries, unresolved


def build_payload(repo_root: Path) -> dict[str, Any]:
    domain_registry = yaml.safe_load(ensure_exists(DOMAIN_REGISTRY_INPUT, "domain registry").read_text())
    domain_matrix_text = ensure_exists(repo_root / DOMAIN_MATRIX_INPUT, "domain matrix").read_text()
    user_facing_text = ensure_exists(repo_root / USER_FACING_URLS_INPUT, "user-facing URLs reference").read_text()

    entries = build_main_entries(domain_registry)
    partner_entries, unresolved = build_partner_entries(
        domain_matrix_text=domain_matrix_text,
        user_facing_text=user_facing_text,
        argocd_prod_url=https_url(domain_registry["platform"]["argocd"].get("prod")),
    )
    entries.extend(partner_entries)
    entries.sort(key=lambda item: (LANE_ORDER[item["lane"]], item["tenant_site"]))

    return {
        "pack_id": "domain-access-reference",
        "schema_version": 1,
        "generated_by": "tools/docs/build_domain_access_reference.py",
        "canonical_inputs": PRIMARY_CANONICAL_SOURCES,
        "entry_count": len(entries),
        "entries": entries,
        "unresolved_conflicts": unresolved,
    }


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "<!-- Generated file. Do not hand-edit. -->",
        "# Domain And Access Reference",
        "",
        "This page is a projection from canonical registry and reference inputs.",
        "",
        f"- Canonical JSON: `generated/platform/domain-access-reference.json`",
        f"- Generated by: `{payload['generated_by']}`",
        f"- Entry count: `{payload['entry_count']}`",
        "",
        "## Access Matrix",
        "",
        "| Lane | Tenant/Site | Status | Learner URL | Studio URL | Admin URL | Support/Ops URL | Owner | Canonical Source | Registry-backed |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for entry in payload["entries"]:
        lines.append(
            "| {lane} | {tenant_site} | {status} | {learner} | {studio} | {admin} | {support} | {owner} | `{source}` | {registry} |".format(
                lane=entry["lane"],
                tenant_site=entry["tenant_site"],
                status=entry["status"],
                learner=entry["learner_url"] or "unresolved",
                studio=entry["studio_url"] or "unresolved",
                admin=entry["admin_url"] or "unresolved",
                support=entry["support_ops_url"] or "n/a",
                owner=entry["owner"],
                source=entry["canonical_source"],
                registry="yes" if entry["generated_from_registry_contract_input"] else "no",
            )
        )
    lines.extend(["", "## Notes", ""])
    for entry in payload["entries"]:
        for note in entry["notes"]:
            lines.append(f"- `{entry['lane']}/{entry['tenant_site']}`: {note}")
    if payload["unresolved_conflicts"]:
        lines.extend(["", "## Explicit Unresolved Conflicts", "", "| Lane | Tenant/Site | Field | Observed Values | Resolution |", "| --- | --- | --- | --- | --- |"])
        for item in payload["unresolved_conflicts"]:
            observed = "<br>".join(f"`{value['source']}` -> `{value['value']}`" for value in item["observed_values"])
            lines.append(
                f"| {item['lane']} | {item['tenant_site']} | {item['field']} | {observed} | {item['resolution']} |"
            )
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
    write_or_check(json_output, json_content, args.check, "DOMAIN_ACCESS_REFERENCE_JSON")
    write_or_check(md_output, md_content, args.check, "DOMAIN_ACCESS_REFERENCE_MD")
    mode = "check" if args.check else "write"
    print(
        "DOMAIN_ACCESS_REFERENCE_OK "
        f"mode={mode} entries={payload['entry_count']} conflicts={len(payload['unresolved_conflicts'])}"
    )


if __name__ == "__main__":
    main()
