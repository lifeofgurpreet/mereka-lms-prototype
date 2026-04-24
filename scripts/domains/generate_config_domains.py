#!/usr/bin/env python3
"""Generate config-domains.sh from tenant-registry.yaml.

Reads the canonical tenant/domain registry and produces a shell script
that exports the same domain variables previously hand-maintained in
scripts/shared/config.sh (lines 36-117).

Usage:
    python scripts/domains/generate_config_domains.py              # Generate
    python scripts/domains/generate_config_domains.py --check      # Verify
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
OUTPUT_PATH = REPO_ROOT / "generated" / "domains" / "config-domains.sh"

# ---------------------------------------------------------------------------
# Mapping: (environment, tenant, role) -> shell variable name
# ---------------------------------------------------------------------------
# Primary tenant (mereka) role -> variable name mappings per environment.
MEREKA_ROLE_MAP: dict[str, dict[str, str]] = {
    "production": {
        "primary": "LMS_DOMAIN",
        "studio": "STUDIO_DOMAIN",
        "mfe": "MFE_DOMAIN",
        "auth": "AUTHENTIK_DOMAIN",
        "preview": "PREVIEW_DOMAIN",
        "discovery": "DISCOVERY_DOMAIN",
        "ecommerce": "ECOMMERCE_DOMAIN",
        "notes": "NOTES_DOMAIN",
        "credentials": "CREDENTIALS_DOMAIN",
        "forum": "FORUM_DOMAIN",
        "enterprise-admin": "ENTERPRISE_ADMIN_DOMAIN",
        "enterprise-learner": "ENTERPRISE_PORTAL_DOMAIN",
    },
    "dev": {
        "primary": "DEV_LMS_DOMAIN",
        "studio": "DEV_STUDIO_DOMAIN",
        "mfe": "DEV_MFE_DOMAIN",
        "auth": "DEV_AUTHENTIK_DOMAIN",
        "preview": "DEV_PREVIEW_DOMAIN",
        "discovery": "DEV_DISCOVERY_DOMAIN",
        "notes": "DEV_NOTES_DOMAIN",
        "credentials": "DEV_CREDENTIALS_DOMAIN",
        "forum": "DEV_FORUM_DOMAIN",
        "enterprise-admin": "DEV_ENTERPRISE_ADMIN_DOMAIN",
        "enterprise-learner": "DEV_ENTERPRISE_PORTAL_DOMAIN",
    },
    "staging": {
        "primary": "STAGING_LMS_DOMAIN",
        "studio": "STAGING_STUDIO_DOMAIN",
        "mfe": "STAGING_MFE_DOMAIN",
        "auth": "STAGING_AUTHENTIK_DOMAIN",
        "preview": "STAGING_PREVIEW_DOMAIN",
        "discovery": "STAGING_DISCOVERY_DOMAIN",
        "notes": "STAGING_NOTES_DOMAIN",
        "credentials": "STAGING_CREDENTIALS_DOMAIN",
        "forum": "STAGING_FORUM_DOMAIN",
        "enterprise-admin": "STAGING_ENTERPRISE_ADMIN_DOMAIN",
        "enterprise-learner": "STAGING_ENTERPRISE_PORTAL_DOMAIN",
    },
}

# Alternative tenants: (environment, tenant, role) -> variable name
ALT_TENANT_MAP: dict[tuple[str, str, str], str] = {
    # Production biji-biji
    ("production", "biji-biji", "primary"): "BIJI_DOMAIN",
    ("production", "biji-biji", "studio"): "BIJI_STUDIO_DOMAIN",
    ("production", "biji-biji", "mfe"): "BIJI_MFE_DOMAIN",
    # Production skillourfuture
    ("production", "skillourfuture", "primary"): "SKILLOURFUTURE_DOMAIN",
    ("production", "skillourfuture", "studio"): "SKILLOURFUTURE_STUDIO_DOMAIN",
    ("production", "skillourfuture", "mfe"): "SKILLOURFUTURE_MFE_DOMAIN",
    # Dev biji-biji
    ("dev", "biji-biji", "primary"): "DEV_BIJI_DOMAIN",
    ("dev", "biji-biji", "studio"): "DEV_BIJI_STUDIO_DOMAIN",
    ("dev", "biji-biji", "mfe"): "DEV_BIJI_MFE_DOMAIN",
    # Dev skillourfuture
    ("dev", "skillourfuture", "primary"): "DEV_SKILLOURFUTURE_DOMAIN",
    ("dev", "skillourfuture", "studio"): "DEV_SKILLOURFUTURE_STUDIO_DOMAIN",
    ("dev", "skillourfuture", "mfe"): "DEV_SKILLOURFUTURE_MFE_DOMAIN",
}


def load_registry() -> dict:
    """Load and return the parsed tenant registry."""
    return yaml.safe_load(REGISTRY_PATH.read_text(encoding="utf-8"))


def build_domain_index(registry: dict) -> dict[tuple[str, str, str], str]:
    """Build (environment, tenant, role) -> domain mapping from registry.

    Every exported domain must exist in tenant-registry.yaml.
    No fabricated/derived domains outside the canonical source.

    When multiple entries exist for the same (env, tenant, role) tuple
    (e.g. during a root migration), prefer the 'active' entry over 'planned'.
    """
    index: dict[tuple[str, str, str], str] = {}
    status_index: dict[tuple[str, str, str], str] = {}
    for entry in registry.get("domains", []):
        env = entry.get("environment")
        tenant = entry.get("tenant")
        role = entry.get("role")
        domain = entry.get("domain")
        status = entry.get("status", "")
        if env and tenant and role and domain:
            key = (env, tenant, role)
            existing_status = status_index.get(key)
            # Prefer active over planned/other statuses
            if key not in index or (existing_status != "active" and status == "active"):
                index[key] = domain
                status_index[key] = status

    return index


def generate(registry: dict) -> str:
    """Generate the config-domains.sh content."""
    index = build_domain_index(registry)
    lines: list[str] = []

    lines.append("#!/usr/bin/env bash")
    lines.append("# =============================================================================")
    lines.append("# Domain Settings — GENERATED from tenant-registry.yaml")
    lines.append("# DO NOT EDIT — regenerate with:")
    lines.append("#   python scripts/domains/generate_config_domains.py")
    lines.append("# =============================================================================")
    lines.append("")

    # --- Production ---
    lines.append("# Canonical app-owned tenant/domain source lives in")
    lines.append("# deploy/k8s/tenancy/tenant-registry.yaml.")
    lines.append("# This file provides derived shell defaults for scripts and must stay aligned")
    lines.append("# with the tenant registry rather than becoming a second authority plane.")
    lines.append("# Production")
    _emit_mereka_block(lines, index, "production", MEREKA_ROLE_MAP["production"])

    lines.append("")
    lines.append("# Alternative domains (multisite)")
    _emit_alt_tenant_block(lines, index, "production")

    lines.append("")
    lines.append("# Biji-Biji dedicated subdomains (public DNS)")
    # These are the same variables but emitted in a specific order matching
    # the original config.sh layout. They are already covered above via
    # ALT_TENANT_MAP, but the original config.sh has biji studio/mfe in a
    # separate section. We emit them all in the alt_tenant block above, then
    # add an empty section header for documentation continuity. The actual
    # exports for BIJI_STUDIO_DOMAIN and BIJI_MFE_DOMAIN are in the block above.

    lines.append("")
    lines.append("# Development")
    _emit_mereka_block(lines, index, "dev", MEREKA_ROLE_MAP["dev"])

    lines.append("")
    lines.append("# DEV tenant-pattern domains")
    _emit_alt_tenant_block(lines, index, "dev")

    lines.append("")
    lines.append("# Purchase Gateway is path-routed under the LMS host via /payments/*.")
    lines.append("# There is no standalone payments.<domain> hostname in the active platform contract.")

    lines.append("")
    lines.append("# Staging (active non-prod lane on shared rke2-nonprod today)")
    _emit_mereka_block(lines, index, "staging", MEREKA_ROLE_MAP["staging"])

    lines.append("")
    lines.append("# Purchase Gateway (staging)")
    lines.append("")

    return "\n".join(lines)


def _emit_mereka_block(
    lines: list[str],
    index: dict[tuple[str, str, str], str],
    env: str,
    role_map: dict[str, str],
) -> None:
    """Emit export lines for the primary (mereka) tenant."""
    # Ordered roles to match the original config.sh layout
    ordered_roles = [
        "primary",
        "studio",
        "mfe",
        "auth",
        "preview",
        "discovery",
        "ecommerce",
        "notes",
        "credentials",
        "forum",
        "enterprise-admin",
        "enterprise-learner",
    ]

    ecommerce_emitted = False
    enterprise_header_emitted = False

    for role in ordered_roles:
        var_name = role_map.get(role)
        if not var_name:
            continue
        domain = index.get((env, "mereka", role))
        if not domain:
            continue

        # Ecommerce deprecation comment
        if role == "ecommerce" and not ecommerce_emitted:
            ecommerce_emitted = True
            lines.append("")
            lines.append(
                "# Legacy Oscar ecommerce (deprecated — being replaced by purchase-gateway)"
            )
            lines.append(
                "# Kept during dual-stack transition period; will be removed after AC-027/AC-028 close"
            )

        # Enterprise header
        if role == "enterprise-admin" and not enterprise_header_emitted:
            enterprise_header_emitted = True
            lines.append("")
            if env == "production":
                lines.append("# Enterprise MFE domains")
            elif env == "dev":
                lines.append("# Enterprise MFE domains (dev)")
            elif env == "staging":
                lines.append("# Enterprise MFE domains (staging)")

        lines.append(f'export {var_name}="${{{var_name}:-{domain}}}"')


def _emit_alt_tenant_block(
    lines: list[str],
    index: dict[tuple[str, str, str], str],
    env: str,
) -> None:
    """Emit export lines for alternative tenants (biji-biji, skillourfuture)."""
    for (entry_env, tenant, role), var_name in ALT_TENANT_MAP.items():
        if entry_env != env:
            continue
        domain = index.get((env, tenant, role))
        if not domain:
            continue
        lines.append(f'export {var_name}="${{{var_name}:-{domain}}}"')


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate config-domains.sh from tenant registry")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify generated output matches committed file",
    )
    args = parser.parse_args()

    registry = load_registry()
    content = generate(registry)

    if args.check:
        if not OUTPUT_PATH.exists():
            print(f"FAIL: {OUTPUT_PATH} does not exist", file=sys.stderr)
            print("Run: python scripts/domains/generate_config_domains.py", file=sys.stderr)
            return 1
        existing = OUTPUT_PATH.read_text(encoding="utf-8")
        if existing != content:
            print(f"FAIL: {OUTPUT_PATH} is out of date", file=sys.stderr)
            print("Run: python scripts/domains/generate_config_domains.py", file=sys.stderr)
            return 1
        print(f"OK: {OUTPUT_PATH} is up to date")
        return 0

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(content, encoding="utf-8")
    OUTPUT_PATH.chmod(0o755)
    print(f"Generated {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
