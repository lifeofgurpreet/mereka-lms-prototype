#!/usr/bin/env python3
"""Generate the canonical runtime-routing browser contract from tenant-registry.

This is the first lane-governance slice for tenant-facing routing truth.
It promotes deploy/k8s/tenancy/tenant-registry.yaml into a single machine-
readable contract for the runtime-routing lane.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. Install with `pip install pyyaml`.")


REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
ALLOWED_ENVS = {"production", "staging", "dev", "profiles-dev", "local"}


def load_registry() -> dict[str, Any]:
    return yaml.safe_load(REGISTRY_PATH.read_text(encoding="utf-8"))


def _active_domain_rows(registry: dict[str, Any], env: str) -> list[dict[str, Any]]:
    return [
        row
        for row in registry.get("domains", [])
        if row.get("environment") == env
        and row.get("status") == "active"
        and row.get("role") in {"primary", "studio", "mfe"}
    ]


def _proof_priority_value(row: dict[str, Any]) -> int:
    priority = str(row.get("proof_priority", "P9"))
    if priority.startswith("P") and priority[1:].isdigit():
        return int(priority[1:])
    return 9


def _host_map_for_env(registry: dict[str, Any], env: str) -> dict[str, dict[str, str]]:
    host_map: dict[str, dict[str, str]] = {}
    chosen_rows: dict[tuple[str, str], dict[str, Any]] = {}
    for row in _active_domain_rows(registry, env):
        key = (row["tenant"], row["role"])
        current = chosen_rows.get(key)
        if current is None:
            chosen_rows[key] = row
            continue
        current_rank = (
            0 if bool(current.get("release_critical", False)) else 1,
            _proof_priority_value(current),
            current.get("domain", ""),
        )
        candidate_rank = (
            0 if bool(row.get("release_critical", False)) else 1,
            _proof_priority_value(row),
            row.get("domain", ""),
        )
        if candidate_rank < current_rank:
            chosen_rows[key] = row

    for (tenant, role), row in chosen_rows.items():
        host_map.setdefault(tenant, {})[role] = row["domain"]
    return host_map


def _runtime_routing_contract(registry: dict[str, Any], env: str) -> dict[str, Any]:
    return (
        registry.get("lane_contracts", {})
        .get("runtime-routing", {})
        .get("environments", {})
        .get(env, {})
    )


def _forbidden_hosts(
    host_map: dict[str, dict[str, str]],
    tenant_record: dict[str, Any],
    lane_contract: dict[str, Any],
) -> list[str]:
    forbidden_cfg = lane_contract.get("forbidden_hosts", {})
    source_tenant = forbidden_cfg.get("source_tenant", "")
    if not source_tenant:
        return []
    if forbidden_cfg.get("apply_to_non_primary_tenants_only", False) and tenant_record.get("is_primary", False):
        return []
    source_hosts = host_map.get(source_tenant, {})
    roles = forbidden_cfg.get("roles", [])
    return [source_hosts.get(role, "") for role in roles if source_hosts.get(role, "")]


def _build_assertions(
    hosts: dict[str, str],
    lane_contract: dict[str, Any],
    forbidden_hosts: list[str],
) -> list[dict[str, Any]]:
    assertions: list[dict[str, Any]] = []
    dashboard_cfg = lane_contract.get("dashboard_redirect", {})
    dashboard_source = hosts.get("primary")
    dashboard_target = hosts.get(dashboard_cfg.get("expect_final_role", ""))
    if dashboard_source and dashboard_target:
        assertions.append(
            {
                "id": "dashboard-route",
                "kind": "redirect-contract",
                "url": f"https://{dashboard_source}{dashboard_cfg.get('path', '/dashboard')}",
                "expect_final_host": dashboard_target,
                "forbid_hosts": forbidden_hosts,
            }
        )

    for path in lane_contract.get("apps_host_stability_paths", []):
        apps_host = hosts.get("mfe")
        if not apps_host:
            continue
        assertion_id = "apps-root" if path == "/" else f"apps-{path.strip('/').replace('/', '-')}"
        assertion = {
            "id": assertion_id,
            "kind": "host-stability",
            "url": f"https://{apps_host}{path}",
            "expect_host": apps_host,
            "forbid_redirect_hosts": forbidden_hosts,
        }
        if path in {"/", "/dashboard"}:
            # Release-critical staging regressions showed same-host stability alone
            # is insufficient. Require non-empty HTML for apps root/dashboard too.
            assertion.update(
                {
                    "expect_content_type_prefix": "text/html",
                    "expect_min_body_bytes": 1,
                }
            )
        assertions.append(assertion)

    studio_cfg = lane_contract.get("studio_sso", {})
    studio_entry_host = hosts.get(studio_cfg.get("entry_role", ""))
    apps_host = hosts.get(studio_cfg.get("expect_apps_role", ""))
    if studio_entry_host and apps_host:
        assertions.append(
            {
                "id": "studio-sso-login",
                "kind": "sso-contract",
                "url": f"https://{studio_entry_host}{studio_cfg.get('entry_path', '/')}",
                "expect_apps_host": apps_host,
                "forbid_hosts": forbidden_hosts,
            }
        )

    return assertions


def build_payload(
    registry: dict[str, Any],
    env: str,
    tenant_filter: str | None = None,
) -> dict[str, Any]:
    if env not in ALLOWED_ENVS:
        raise ValueError(f"Unsupported env {env!r}. Expected one of: {sorted(ALLOWED_ENVS)}")

    environments = registry.get("environments", {})
    env_block = environments.get(env, {})
    lane_contract = _runtime_routing_contract(registry, env)
    host_map = _host_map_for_env(registry, env)
    tenants = []

    for tenant in registry.get("tenants", []):
        slug = tenant["slug"]
        if tenant_filter and slug != tenant_filter:
            continue
        hosts = host_map.get(slug, {})
        if not hosts:
            continue

        forbidden_hosts = _forbidden_hosts(host_map, tenant, lane_contract)
        missing_roles = [role for role in ("primary", "mfe") if role not in hosts]
        playwright_cfg = lane_contract.get("playwright", {})
        footer_cfg = lane_contract.get("footer_probe", {})
        playwright_base_role = playwright_cfg.get("base_url_role", "primary")
        footer_lms_role = footer_cfg.get("lms_role", "primary")
        footer_mfe_role = footer_cfg.get("mfe_role", "mfe")
        tenants.append(
            {
                "tenant": slug,
                "display_name": tenant["name"],
                "is_primary": bool(tenant.get("is_primary", False)),
                "theme": tenant.get("theme", ""),
                "playwright_base_url": f"https://{hosts[playwright_base_role]}" if playwright_base_role in hosts else None,
                "playwright_selector_audit_routes": playwright_cfg.get("selector_audit_routes", []),
                "studio_sso_entry_domain": hosts.get(lane_contract.get("studio_sso", {}).get("entry_role", "primary")),
                "footer_probe": {
                    "lms_url": f"https://{hosts[footer_lms_role]}" if footer_lms_role in hosts else None,
                    "mfe_url": f"https://{hosts[footer_mfe_role]}" if footer_mfe_role in hosts else None,
                },
                "hosts": hosts,
                "forbidden_hosts": forbidden_hosts,
                "contract_ready": not missing_roles,
                "missing_roles": missing_roles,
                "assertions": _build_assertions(hosts, lane_contract, forbidden_hosts),
            }
        )

    return {
        "schema_version": "runtime-routing-contract/v1",
        "source": str(REGISTRY_PATH.relative_to(REPO_ROOT)),
        "source_version": registry.get("version", ""),
        "lane": "runtime-routing",
        "environment": env,
        "environment_contract": {
            "lane_contract_version": registry.get("lane_contracts", {}).get("runtime-routing", {}).get("schema_version", ""),
            "root_domain": env_block.get("root_domain"),
            "auth_host": env_block.get("auth_host"),
            "namespace": env_block.get("namespace"),
            "argocd_app": env_block.get("argocd_app"),
            "gitops_overlay_path": env_block.get("gitops_overlay_path"),
            "runtime_proof_script": env_block.get("runtime_proof_script", ""),
            "acceptance_profile": lane_contract,
        },
        "tenants": tenants,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", required=True)
    parser.add_argument("--tenant")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    payload = build_payload(load_registry(), args.env, args.tenant)
    rendered = json.dumps(payload, indent=2) + "\n"

    if args.stdout:
        sys.stdout.write(rendered)
        return 0

    output_path = args.output or (REPO_ROOT / "generated" / "tenant-runtime" / f"browser-matrix-{args.env}.json")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if args.check:
        current = output_path.read_text(encoding="utf-8") if output_path.exists() else ""
        if current != rendered:
            print(f"Runtime-routing matrix drift detected: {output_path}", file=sys.stderr)
            return 1
        return 0

    output_path.write_text(rendered, encoding="utf-8")
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
