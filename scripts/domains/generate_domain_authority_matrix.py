#!/usr/bin/env python3
"""D-07: Domain Authority Matrix Generator.

Reads deploy/k8s/tenancy/tenant-registry.yaml and produces:
  - generated/domain/domain-authority-matrix.json   (machine-readable)
  - docs/reference/generated/domain-authority-matrix.md (human-readable)

Usage:
  python scripts/domains/generate_domain_authority_matrix.py              # Generate
  python scripts/domains/generate_domain_authority_matrix.py --check      # Verify current
  python scripts/domains/generate_domain_authority_matrix.py --env dev    # Filter to one env
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit(
        "ERROR: PyYAML is required.  pip install pyyaml"
    )

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
JSON_OUT = REPO_ROOT / "generated" / "domain" / "domain-authority-matrix.json"
MD_OUT = REPO_ROOT / "docs" / "reference" / "generated" / "domain-authority-matrix.md"

# ---------------------------------------------------------------------------
# Default placement fields (v1.3.0 forward; gracefully absent in v1.2.0)
# ---------------------------------------------------------------------------
# NOTE: gitops_overlay_path values point at the AUTHORITATIVE bbi-infrastructure
# overlay paths per ADR-025 deployment boundary. The old app-repo shadow paths
# under deploy/k8s/overlays/{production,staging,rke2-nonprod}/ were deleted by
# Wave 9 (PR #1900). cluster_ref is the RKE2 cluster now — GKE is decommissioned.
ENV_DEFAULTS: dict[str, dict[str, str | None]] = {
    "production": {
        "namespace": "mereka-lms",
        "argocd_app": "mereka-lms-prod",
        "cluster_ref": "rke2-prod",
        "cluster_class": "rke2",
        "gitops_overlay_path": "bbi-infrastructure:apps/mereka-lms/overlays/prod",
        "dns_zone": "mereka.io",
    },
    "dev": {
        "namespace": "mereka-lms-dev",
        "argocd_app": "mereka-lms-dev",
        "cluster_ref": "rke2-nonprod",
        "cluster_class": "rke2",
        "gitops_overlay_path": "bbi-infrastructure:apps/mereka-lms/overlays/profiles/dev",
        "dns_zone": "mereka.dev",
    },
    "profiles-dev": {
        "namespace": "mereka-lms-dev",
        "argocd_app": "mereka-lms-dev",
        "cluster_ref": "rke2-nonprod",
        "cluster_class": "rke2",
        "gitops_overlay_path": "bbi-infrastructure:apps/mereka-lms/overlays/profiles/dev",
        "dns_zone": "mereka.dev",
    },
    "staging": {
        "namespace": "stg-mereka-lms",
        "argocd_app": "mereka-lms-staging",
        "cluster_ref": "rke2-nonprod",
        "cluster_class": "rke2",
        "gitops_overlay_path": "bbi-infrastructure:apps/mereka-lms/overlays/staging",
        "dns_zone": "mereka.io",
    },
    "local": {
        "namespace": "mereka-lms",
        "argocd_app": None,
        "cluster_ref": "local",
        "cluster_class": "kind",
        "gitops_overlay_path": "deploy/k8s/overlays/local",
        "dns_zone": "localhost",
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_registry(path: Path) -> dict:
    """Load and return the tenant registry YAML."""
    with open(path) as fh:
        return yaml.safe_load(fh)


def _env_field(env_block: dict, env_name: str, field: str) -> str | None:
    """Resolve a placement/environment field with fallback to defaults."""
    # First try direct field on environment block (v1.3.0+)
    val = env_block.get(field)
    if val is not None:
        return val
    # Fallback to hardcoded defaults
    defaults = ENV_DEFAULTS.get(env_name, {})
    return defaults.get(field)


def build_matrix(
    registry: dict,
    env_filter: str | None = None,
) -> list[dict]:
    """Build the flat domain-authority list from the registry."""
    envs = registry.get("environments", {})
    domains_list = registry.get("domains", [])

    rows: list[dict] = []
    for d in domains_list:
        env_name = d.get("environment", "")
        if env_filter and env_name != env_filter:
            continue

        env_block = envs.get(env_name, {})

        rows.append({
            "tenant": d.get("tenant", ""),
            "environment": env_name,
            "hostname": d.get("domain", ""),
            "role": d.get("role", ""),
            "status": d.get("status", ""),
            "namespace": _env_field(env_block, env_name, "namespace"),
            "argocd_app": _env_field(env_block, env_name, "argocd_app"),
            "cluster_ref": _env_field(env_block, env_name, "cluster_ref"),
            "cluster_class": _env_field(env_block, env_name, "cluster_class"),
            "gitops_overlay_path": _env_field(env_block, env_name, "gitops_overlay_path"),
            "dns_zone": _env_field(env_block, env_name, "dns_zone"),
            "cookie_domain": d.get("cookie_domain") or "",
            "auth_class": d.get("auth_class", ""),
            "proof_priority": d.get("proof_priority", ""),
            "ingress_tls": d.get("ingress_tls", False),
        })

    # Sort: environment order, then tenant, then role
    env_order = ["production", "staging", "dev", "profiles-dev", "local"]

    def sort_key(row: dict) -> tuple:
        try:
            ei = env_order.index(row["environment"])
        except ValueError:
            ei = len(env_order)
        return (ei, row["tenant"], row["role"])

    rows.sort(key=sort_key)
    return rows


# ---------------------------------------------------------------------------
# Output generators
# ---------------------------------------------------------------------------

def generate_json(
    rows: list[dict],
    version: str,
    now: str,
) -> str:
    """Return the JSON string for the authority matrix."""
    payload = {
        "generated_at": now,
        "source": "deploy/k8s/tenancy/tenant-registry.yaml",
        "source_version": version,
        "domains": rows,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def generate_markdown(
    rows: list[dict],
    version: str,
    now_date: str,
) -> str:
    """Return the Markdown string for the authority matrix."""
    lines: list[str] = []
    lines.append("# Domain Authority Matrix")
    lines.append("")
    lines.append(
        f"_Generated from `deploy/k8s/tenancy/tenant-registry.yaml` v{version}"
        f" on {now_date}._"
    )
    lines.append(
        "_Do not hand-edit. Regenerate with:"
        " `python scripts/domains/generate_domain_authority_matrix.py`_"
    )
    lines.append("")

    # Group by environment
    env_order = ["production", "staging", "dev", "profiles-dev", "local"]
    grouped: dict[str, list[dict]] = {}
    for r in rows:
        grouped.setdefault(r["environment"], []).append(r)

    # Determine ordered env keys
    ordered_envs = [e for e in env_order if e in grouped]
    ordered_envs += [e for e in grouped if e not in env_order]

    for env in ordered_envs:
        env_rows = grouped[env]
        lines.append(f"## {env}")
        lines.append("")
        lines.append(
            "| Tenant | Env | Hostname | Role | Status "
            "| Namespace | Cluster | ArgoCD App | Priority |"
        )
        lines.append(
            "|--------|-----|----------|------|--------"
            "|-----------|---------|------------|----------|"
        )
        for r in env_rows:
            lines.append(
                f"| {r['tenant']} "
                f"| {r['environment']} "
                f"| `{r['hostname']}` "
                f"| {r['role']} "
                f"| {r['status']} "
                f"| {r['namespace'] or '-'} "
                f"| {r['cluster_ref'] or '-'} "
                f"| {r['argocd_app'] or '-'} "
                f"| {r['proof_priority']} |"
            )
        lines.append("")

    # Summary
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- **Total domains**: {len(rows)}")
    active = sum(1 for r in rows if r["status"] == "active")
    planned = sum(1 for r in rows if r["status"] == "planned")
    deprecated = sum(1 for r in rows if r["status"] == "deprecated")
    lines.append(f"- **Active**: {active}")
    if planned:
        lines.append(f"- **Planned**: {planned}")
    if deprecated:
        lines.append(f"- **Deprecated**: {deprecated}")
    envs_seen = sorted({r["environment"] for r in rows})
    lines.append(f"- **Environments**: {', '.join(envs_seen)}")
    tenants_seen = sorted({r["tenant"] for r in rows})
    lines.append(f"- **Tenants**: {', '.join(tenants_seen)}")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# --check mode
# ---------------------------------------------------------------------------

def _content_hash(text: str) -> str:
    """SHA-256 of text, ignoring the generated_at timestamp line."""
    # Strip the generated_at / date line so regeneration only detects real drift
    stable_lines = []
    for line in text.splitlines():
        # JSON: skip "generated_at" key
        stripped = line.strip()
        if stripped.startswith('"generated_at"'):
            continue
        # Markdown: skip the _Generated from ... on DATE_ line
        if stripped.startswith("_Generated from"):
            continue
        stable_lines.append(line)
    return hashlib.sha256("\n".join(stable_lines).encode()).hexdigest()


def check_freshness(
    rows: list[dict],
    version: str,
) -> bool:
    """Return True if on-disk files match what would be generated."""
    now_placeholder = "CHECK_MODE"
    expected_json = generate_json(rows, version, now_placeholder)
    expected_md = generate_markdown(rows, version, now_placeholder)

    ok = True
    for path, expected in [(JSON_OUT, expected_json), (MD_OUT, expected_md)]:
        if not path.exists():
            print(f"MISSING: {path.relative_to(REPO_ROOT)}")
            ok = False
            continue
        on_disk = path.read_text()
        if _content_hash(on_disk) != _content_hash(expected):
            print(f"STALE:   {path.relative_to(REPO_ROOT)}")
            ok = False
        else:
            print(f"OK:      {path.relative_to(REPO_ROOT)}")

    return ok


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the domain authority matrix from the tenant registry."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify generated files are current (exit 1 if stale).",
    )
    parser.add_argument(
        "--env",
        type=str,
        default=None,
        help="Filter to a single environment (e.g. dev, production, staging).",
    )
    args = parser.parse_args()

    if not REGISTRY_PATH.exists():
        sys.exit(f"ERROR: Registry not found at {REGISTRY_PATH}")

    registry = load_registry(REGISTRY_PATH)
    version = registry.get("version", "unknown")
    rows = build_matrix(registry, env_filter=args.env)

    if not rows:
        env_msg = f" for --env={args.env}" if args.env else ""
        sys.exit(f"ERROR: No domains found{env_msg}")

    if args.check:
        if args.env:
            sys.exit("ERROR: --check cannot be combined with --env (checks full matrix)")
        ok = check_freshness(rows, version)
        if ok:
            print("\nAll generated domain authority files are current.")
            return 0
        else:
            print(
                "\nGenerated files are stale. "
                "Run: python scripts/domains/generate_domain_authority_matrix.py"
            )
            return 1

    # Generate
    now = datetime.now(timezone.utc).isoformat()
    now_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    json_text = generate_json(rows, version, now)
    md_text = generate_markdown(rows, version, now_date)

    # Ensure output dirs exist
    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    MD_OUT.parent.mkdir(parents=True, exist_ok=True)

    JSON_OUT.write_text(json_text)
    MD_OUT.write_text(md_text)

    print(f"Generated {JSON_OUT.relative_to(REPO_ROOT)} ({len(rows)} domains)")
    print(f"Generated {MD_OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
