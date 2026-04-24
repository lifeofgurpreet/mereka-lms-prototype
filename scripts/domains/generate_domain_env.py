#!/usr/bin/env python3
"""Generate per-environment domain-env.yaml from tenant-registry.yaml.

Reads the canonical tenant/domain registry and produces K8s deployment patches
matching the hand-maintained domain-env.yaml files in each overlay.

Usage:
    python scripts/domains/generate_domain_env.py                 # All envs
    python scripts/domains/generate_domain_env.py --env local     # One env
    python scripts/domains/generate_domain_env.py --check         # Verify
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import yaml

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
OUTPUT_DIR = REPO_ROOT / "generated" / "domains"

# ---------------------------------------------------------------------------
# Registry environment → overlay directory mapping
# ---------------------------------------------------------------------------
# "local" overlay reads from the "dev" environment in the registry (same domains).
# "rke2-nonprod" overlay also reads from "dev" environment.
ENV_TO_REGISTRY: dict[str, str] = {
    "local": "dev",
    "dev": "dev",
    "staging": "staging",
    "production": "production",
}

# ---------------------------------------------------------------------------
# Deployment env map
# ---------------------------------------------------------------------------
# Each entry describes a K8s resource (Deployment, CronJob) and the env vars
# it needs, parameterized by tenant/role lookups against the registry.
#
# Values are:
#   - ("tenant", "role")        → resolved to domain from registry
#   - ("tenant", "role", "X")   → special attribute (cookie_domain, etc.)
#   - "scheme"                  → resolved from environment config
#   - "{scheme}://{tenant:role}" → template resolved at generation time

# We define the deployment targets as an ordered list to control YAML doc order.

def _core_lms_env() -> list[tuple[str, Any]]:
    """Core env vars shared by lms, cms, lms-worker, cms-worker."""
    return [
        ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
        ("MEREKA_SCHEME", "scheme"),
        ("MEREKA_COOKIE_DOMAIN", ("mereka", "primary", "cookie_domain")),
        ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
        ("MFE_BASE_URL", "{scheme}://{mereka:mfe}"),
    ]


def _core_lms_env_with_auth() -> list[tuple[str, Any]]:
    """Core env vars + auth domain (for rke2-nonprod/staging overlays)."""
    return _core_lms_env() + [
        ("MEREKA_AUTH_DOMAIN", ("mereka", "auth")),
        ("MEREKA_CREDENTIALS_DOMAIN", ("mereka", "credentials")),
    ]


def _caddy_env_specs(overlay_env: str) -> list[tuple[str, Any]]:
    """Caddy host env vars for an overlay environment."""
    specs: list[tuple[str, Any]] = [
        ("LMS_HOST", ("mereka", "primary")),
        ("LMS_HOST_PREVIEW", ("mereka", "preview")),
        ("STUDIO_HOST", ("mereka", "studio")),
        ("MFE_HOST", ("mereka", "mfe")),
        ("DISCOVERY_HOST", ("mereka", "discovery")),
        ("NOTES_HOST", ("mereka", "notes")),
        ("CREDENTIALS_HOST", ("mereka", "credentials")),
        ("ENTERPRISE_ADMIN_HOST", ("mereka", "enterprise-admin")),
        ("ENTERPRISE_LEARNER_HOST", ("mereka", "enterprise-learner")),
    ]
    if overlay_env in {"local", "dev"}:
        specs.extend([
            ("TENANT_BIJIBIJI_LMS_HOST", ("biji-biji", "primary")),
            ("TENANT_SOF_LMS_HOST", ("skillourfuture", "primary")),
            ("TENANT_BIJIBIJI_MFE_HOST", ("biji-biji", "mfe")),
            ("TENANT_SOF_MFE_HOST", ("skillourfuture", "mfe")),
        ])
    return specs


# The deployment map differs per overlay environment because the overlays
# evolved independently.  We define per-env maps.

def _labeled(name: str, d: dict[str, Any]) -> dict[str, Any]:
    """Add standard app.kubernetes.io/name label to a deployment entry."""
    d.setdefault("labels", {"app.kubernetes.io/name": name})
    return d


def _get_deployment_map_local() -> list[dict[str, Any]]:
    """local overlay deployment map — matches deploy/k8s/overlays/local/patches/domain-env.yaml."""
    core = _core_lms_env()
    return [
        _labeled("lms", {"kind": "Deployment", "name": "lms", "container": "lms", "env": core}),
        _labeled("cms", {"kind": "Deployment", "name": "cms", "container": "cms", "env": core}),
        _labeled("lms-worker", {"kind": "Deployment", "name": "lms-worker", "container": "lms-worker", "env": core}),
        _labeled("cms-worker", {"kind": "Deployment", "name": "cms-worker", "container": "cms-worker", "env": core}),
        _labeled("discovery", {
            "kind": "Deployment", "name": "discovery", "container": "discovery",
            "env": [
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("MEREKA_SCHEME", "scheme"),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
                ("MFE_BASE_URL", "{scheme}://{mereka:mfe}"),
            ],
        }),
        _labeled("notes", {
            "kind": "Deployment", "name": "notes", "container": "notes",
            "env": [
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("NOTES_DOMAIN", ("mereka", "notes")),
            ],
        }),
        _labeled("credentials", {
            "kind": "Deployment", "name": "credentials", "container": "credentials",
            "env": [
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("MEREKA_MFE_DOMAIN", ("mereka", "mfe")),
                ("MEREKA_CREDENTIALS_DOMAIN", ("mereka", "credentials")),
                ("MEREKA_SCHEME", "scheme"),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
                ("MFE_BASE_URL", "{scheme}://{mereka:mfe}"),
            ],
        }),
        _labeled("caddy", {
            "kind": "Deployment", "name": "caddy", "container": "caddy",
            "env": _caddy_env_specs("local"),
        }),
        {
            "kind": "Deployment", "name": "mfe", "container": "mfe",
            "labels": {"app.kubernetes.io/name": "mfe"},
            "comment": "MFE Caddy domain env vars for CSP header template interpolation.",
            "env": [
                ("LMS_HOST", ("mereka", "primary")),
                ("CMS_HOST", ("mereka", "studio")),
                ("AUTH_HOST", ("mereka", "auth")),
                ("TENANT_BIJIBIJI_HOST", ("biji-biji", "primary")),
                ("TENANT_SOF_HOST", ("skillourfuture", "primary")),
            ],
        },
    ]


def _get_deployment_map_dev() -> list[dict[str, Any]]:
    """rke2-nonprod (dev) overlay deployment map."""
    core = _core_lms_env_with_auth()
    return [
        {"kind": "Deployment", "name": "lms", "container": "lms", "env": core},
        {"kind": "Deployment", "name": "cms", "container": "cms", "env": core},
        {"kind": "Deployment", "name": "lms-worker", "container": "lms-worker", "env": core},
        {"kind": "Deployment", "name": "cms-worker", "container": "cms-worker", "env": core},
        {
            "kind": "Deployment", "name": "credentials", "container": "credentials",
            "env": [
                ("MEREKA_CREDENTIALS_DOMAIN", ("mereka", "credentials")),
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("MEREKA_SCHEME", "scheme"),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
            ],
        },
        {
            "kind": "Deployment", "name": "discovery", "container": "discovery",
            "env": [
                ("MEREKA_SCHEME", "scheme"),
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
                ("DISCOVERY_DOMAIN", ("mereka", "discovery")),
                ("DISCOVERY_BASE_URL", "{scheme}://{mereka:discovery}"),
            ],
        },
        {
            "kind": "Deployment", "name": "notes", "container": "notes",
            "env": [
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("NOTES_DOMAIN", ("mereka", "notes")),
            ],
        },
        {
            "kind": "CronJob", "name": "discovery-sync", "namespace": "mereka-lms",
            "container": "sync",
            "env": [
                ("LMS_URL", "{scheme}://{mereka:primary}"),
                ("DISCOVERY_URL", "{scheme}://{mereka:discovery}"),
            ],
        },
        # Enterprise services (init + main containers)
        *_enterprise_service_entries(),
        _enterprise_catalog_worker_entry(),
        {
            "kind": "Deployment", "name": "caddy", "container": "caddy",
            "env": [
                ("ENTERPRISE_ADMIN_HOST", ("mereka", "enterprise-admin")),
                ("ENTERPRISE_LEARNER_HOST", ("mereka", "enterprise-learner")),
            ],
        },
        _enterprise_access_worker_entry(),
    ]


def _get_deployment_map_staging() -> list[dict[str, Any]]:
    """Staging overlay deployment map."""
    core = _core_lms_env_with_auth()
    entries = [
        {"kind": "Deployment", "name": "lms", "container": "lms", "env": core},
        {"kind": "Deployment", "name": "cms", "container": "cms", "env": core},
        {"kind": "Deployment", "name": "lms-worker", "container": "lms-worker", "env": core},
        {"kind": "Deployment", "name": "cms-worker", "container": "cms-worker", "env": core},
        {
            "kind": "Deployment", "name": "credentials", "container": "credentials",
            "env": [
                ("MEREKA_CREDENTIALS_DOMAIN", ("mereka", "credentials")),
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("MEREKA_SCHEME", "scheme"),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
            ],
        },
        {
            "kind": "Deployment", "name": "discovery", "container": "discovery",
            "env": [
                ("MEREKA_SCHEME", "scheme"),
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("LMS_BASE_URL", "{scheme}://{mereka:primary}"),
                ("DISCOVERY_DOMAIN", ("mereka", "discovery")),
                ("DISCOVERY_BASE_URL", "{scheme}://{mereka:discovery}"),
            ],
        },
        {
            "kind": "Deployment", "name": "notes", "container": "notes",
            "env": [
                ("MEREKA_LMS_DOMAIN", ("mereka", "primary")),
                ("NOTES_DOMAIN", ("mereka", "notes")),
            ],
        },
        {
            "kind": "CronJob", "name": "discovery-sync", "namespace": "mereka-lms",
            "container": "sync",
            "env": [
                ("LMS_URL", "{scheme}://{mereka:primary}"),
                ("DISCOVERY_URL", "{scheme}://{mereka:discovery}"),
            ],
        },
        *_enterprise_service_entries(),
        _enterprise_catalog_worker_entry(),
        _enterprise_access_worker_entry(),
        {
            "kind": "Deployment", "name": "caddy", "container": "caddy",
            "env": [
                ("ENTERPRISE_ADMIN_HOST", ("mereka", "enterprise-admin")),
                ("ENTERPRISE_LEARNER_HOST", ("mereka", "enterprise-learner")),
            ],
        },
        {
            "kind": "Deployment", "name": "mfe", "container": "mfe",
            "labels": {"app.kubernetes.io/name": "mfe"},
            "comment": "MFE Caddy domain env vars for CSP header template interpolation.",
            "env": [
                ("LMS_HOST", ("mereka", "primary")),
                ("CMS_HOST", ("mereka", "studio")),
                ("AUTH_HOST", ("mereka", "auth")),
                ("TENANT_BIJIBIJI_HOST", ("biji-biji", "primary")),
                ("TENANT_SOF_HOST", ("skillourfuture", "primary")),
            ],
        },
    ]
    return entries


def _enterprise_service_entries() -> list[dict[str, Any]]:
    """Enterprise service Deployments (config-gen init + main container)."""
    services = [
        "enterprise-catalog",
        "enterprise-access",
        "enterprise-subsidy",
        "license-manager",
    ]
    result = []
    for svc in services:
        result.append({
            "kind": "Deployment", "name": svc, "container": svc,
            "init_container": "config-gen",
            "env": [("LMS_ROOT_URL", "{scheme}://{mereka:primary}")],
        })
    return result


def _enterprise_catalog_worker_entry() -> dict[str, Any]:
    """Enterprise catalog worker Deployment."""
    return {
        "kind": "Deployment", "name": "enterprise-catalog-worker",
        "container": "enterprise-catalog-worker",
        "init_container": "config-gen",
        "env": [("LMS_ROOT_URL", "{scheme}://{mereka:primary}")],
    }


def _enterprise_access_worker_entry() -> dict[str, Any]:
    """Enterprise access worker Deployment."""
    return {
        "kind": "Deployment", "name": "enterprise-access-worker",
        "container": "enterprise-access-worker",
        "init_container": "config-gen",
        "env": [("LMS_ROOT_URL", "{scheme}://{mereka:primary}")],
    }


DEPLOYMENT_MAPS: dict[str, Any] = {
    "local": _get_deployment_map_local,
    "dev": _get_deployment_map_dev,
    "staging": _get_deployment_map_staging,
}

# Per-overlay file header comments (before the first YAML document)
OVERLAY_HEADERS: dict[str, str] = {
    "dev": (
        "# Domain overrides for rke2-nonprod dev environment.\n"
        "#\n"
        "# AUTH DOMAIN NOTE (issue #174):\n"
        "# MEREKA_AUTH_DOMAIN is HYBRID ownership: the *value* (auth0.mereka.dev) is env-specific\n"
        "# and must stay here. However, MEREKA_AUTH_DOMAIN must NOT be used to set\n"
        "# SOCIAL_AUTH_OIDC_OIDC_ENDPOINT or SOCIAL_AUTH_OIDC_KEY — those are owned by\n"
        "# bbi-infrastructure (overlays/dev/patches/production-staging.py). This variable\n"
        "# is only for URL construction in application code that needs the auth domain hostname.\n"
    ),
    "staging": (
        "# Domain overrides for staging environment.\n"
        "#\n"
        "# Staging uses staging.academyv2.mereka.io domains on the rke2-nonprod cluster.\n"
        "# AUTH DOMAIN NOTE (issue #174): same ownership rules as rke2-nonprod.\n"
    ),
}


# ---------------------------------------------------------------------------
# Registry helpers
# ---------------------------------------------------------------------------

def load_registry() -> dict:
    return yaml.safe_load(REGISTRY_PATH.read_text(encoding="utf-8"))


def _prefer_active(
    index: dict[tuple[str, str, str], str],
    status_index: dict[tuple[str, str, str], str],
    key: tuple[str, str, str],
    value: str,
    status: str,
) -> None:
    """Insert into index, preferring 'active' entries over others."""
    existing_status = status_index.get(key)
    if key not in index or (existing_status != "active" and status == "active"):
        index[key] = value
        status_index[key] = status


def build_domain_index(registry: dict) -> dict[tuple[str, str, str], str]:
    index: dict[tuple[str, str, str], str] = {}
    status_index: dict[tuple[str, str, str], str] = {}
    for entry in registry.get("domains", []):
        env = entry.get("environment")
        tenant = entry.get("tenant")
        role = entry.get("role")
        domain = entry.get("domain")
        status = entry.get("status", "")
        if env and tenant and role and domain:
            _prefer_active(index, status_index, (env, tenant, role), domain, status)
    return index


def build_cookie_index(registry: dict) -> dict[tuple[str, str, str], str]:
    index: dict[tuple[str, str, str], str] = {}
    status_index: dict[tuple[str, str, str], str] = {}
    for entry in registry.get("domains", []):
        env = entry.get("environment")
        tenant = entry.get("tenant")
        role = entry.get("role")
        cd = entry.get("cookie_domain")
        status = entry.get("status", "")
        if env and tenant and role and cd:
            _prefer_active(index, status_index, (env, tenant, role), cd, status)
    return index


def resolve_value(
    spec: Any,
    reg_env: str,
    domains: dict[tuple[str, str, str], str],
    cookies: dict[tuple[str, str, str], str],
    scheme: str,
) -> str:
    """Resolve a single env var value."""
    if spec == "scheme":
        return scheme
    if isinstance(spec, tuple):
        if len(spec) == 3 and spec[2] == "cookie_domain":
            return cookies.get((reg_env, spec[0], spec[1]), "")
        return domains.get((reg_env, spec[0], spec[1]), "")
    if isinstance(spec, str) and "{" in spec:
        # Template like "{scheme}://{mereka:primary}"
        result = spec.replace("{scheme}", scheme)
        import re
        for m in re.finditer(r"\{(\w[\w-]*):([\w-]+)\}", spec):
            tenant, role = m.group(1), m.group(2)
            domain = domains.get((reg_env, tenant, role), "")
            result = result.replace(m.group(0), domain)
        return result
    return str(spec)


# ---------------------------------------------------------------------------
# YAML generation — domain-env.yaml (existing)
# ---------------------------------------------------------------------------

def generate_env(overlay_env: str, registry: dict) -> str:
    """Generate domain-env.yaml content for a given overlay environment."""
    reg_env = ENV_TO_REGISTRY[overlay_env]
    domains = build_domain_index(registry)
    cookies = build_cookie_index(registry)

    env_config = registry.get("environments", {}).get(reg_env, {})
    scheme = env_config.get("scheme", "https")

    map_fn = DEPLOYMENT_MAPS.get(overlay_env)
    if not map_fn:
        return ""
    deploy_map = map_fn()

    docs: list[str] = []
    for entry in deploy_map:
        doc = _render_resource(entry, reg_env, domains, cookies, scheme)
        docs.append(doc)

    content = "---\n".join(docs)
    header = OVERLAY_HEADERS.get(overlay_env, "")
    if header:
        content = header + "\n" + content
    return content


def _render_resource(
    entry: dict[str, Any],
    reg_env: str,
    domains: dict,
    cookies: dict,
    scheme: str,
) -> str:
    """Render a single YAML document for a K8s resource patch."""
    kind = entry["kind"]
    name = entry["name"]
    container = entry["container"]
    env_vars = entry["env"]
    comment = entry.get("comment", "")
    labels = entry.get("labels")
    namespace = entry.get("namespace")
    init_container = entry.get("init_container")

    resolved_env = []
    for env_name, spec in env_vars:
        value = resolve_value(spec, reg_env, domains, cookies, scheme)
        resolved_env.append({"name": env_name, "value": value})

    if kind == "Deployment":
        return _render_deployment(
            name, container, resolved_env, labels, comment, init_container
        )
    elif kind == "CronJob":
        return _render_cronjob(name, namespace, container, resolved_env, comment)
    return ""


def _render_deployment(
    name: str,
    container: str,
    env_vars: list[dict],
    labels: dict | None,
    comment: str,
    init_container: str | None,
) -> str:
    lines: list[str] = []
    if comment:
        lines.append(f"# {comment}")
    lines.append("apiVersion: apps/v1")
    lines.append("kind: Deployment")
    lines.append("metadata:")
    lines.append(f"  name: {name}")
    if labels:
        lines.append("  labels:")
        for k, v in labels.items():
            lines.append(f"    {k}: {v}")
    lines.append("spec:")
    lines.append("  template:")
    lines.append("    spec:")

    if init_container:
        lines.append("      initContainers:")
        lines.append(f"        - name: {init_container}")
        lines.append("          env:")
        for ev in env_vars:
            lines.append(f"            - name: {ev['name']}")
            lines.append(f"              value: {ev['value']}")

    lines.append("      containers:")
    lines.append(f"        - name: {container}")
    lines.append("          env:")
    for ev in env_vars:
        lines.append(f"            - name: {ev['name']}")
        lines.append(f"              value: {ev['value']}")

    lines.append("")
    return "\n".join(lines)


def _render_cronjob(
    name: str,
    namespace: str | None,
    container: str,
    env_vars: list[dict],
    comment: str,
) -> str:
    lines: list[str] = []
    if comment:
        lines.append(f"# {comment}")
    else:
        lines.append("# CronJob domain overrides")
    lines.append("apiVersion: batch/v1")
    lines.append("kind: CronJob")
    lines.append("metadata:")
    lines.append(f"  name: {name}")
    if namespace:
        lines.append(f"  namespace: {namespace}")
    lines.append("spec:")
    lines.append("  jobTemplate:")
    lines.append("    spec:")
    lines.append("      template:")
    lines.append("        spec:")
    lines.append("          containers:")
    lines.append(f"            - name: {container}")
    lines.append("              env:")
    for ev in env_vars:
        lines.append(f"                - name: {ev['name']}")
        lines.append(f"                  value: {ev['value']}")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# YAML generation — caddy-env-patch.yaml
# ---------------------------------------------------------------------------

def generate_caddy_env_patch(overlay_env: str, registry: dict) -> str:
    """Generate caddy-env-patch.yaml for a given overlay environment."""
    reg_env = ENV_TO_REGISTRY[overlay_env]
    domains = build_domain_index(registry)
    lms_host = domains.get((reg_env, "mereka", "primary"), "")

    lines: list[str] = []
    lines.append(
        "# GENERATED — do not hand-edit."
        " Source: deploy/k8s/tenancy/tenant-registry.yaml"
    )
    lines.append("# Regenerate: python scripts/domains/generate_domain_env.py")
    lines.append(
        f"# Patch Caddy Deployment env vars for {lms_host} domain."
    )
    lines.append(
        "# The Caddyfile uses {$VAR} placeholders;"
        " these env vars set the actual hostnames."
    )
    lines.append("apiVersion: apps/v1")
    lines.append("kind: Deployment")
    lines.append("metadata:")
    lines.append("  name: caddy")
    lines.append("spec:")
    lines.append("  template:")
    lines.append("    spec:")
    lines.append("      containers:")
    lines.append("        - name: caddy")
    lines.append("          env:")
    for env_name, spec in _caddy_env_specs(overlay_env):
        value = resolve_value(spec, reg_env, domains, {}, "https")
        lines.append(f"            - name: {env_name}")
        lines.append(f'              value: "{value}"')
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# YAML generation — lms-env-patch.yaml (ConfigMap)
# ---------------------------------------------------------------------------

def generate_lms_env_patch(overlay_env: str, registry: dict) -> str:
    """Generate lms-env-patch.yaml (openedx-config ConfigMap) for a given overlay."""
    reg_env = ENV_TO_REGISTRY[overlay_env]
    domains = build_domain_index(registry)
    env_config = registry.get("environments", {}).get(reg_env, {})
    scheme = env_config.get("scheme", "https")

    lms_host = domains.get((reg_env, "mereka", "primary"), "")
    cms_host = domains.get((reg_env, "mereka", "studio"), "")
    preview_host = domains.get((reg_env, "mereka", "preview"), "")
    mfe_host = domains.get((reg_env, "mereka", "mfe"), "")
    enable_https = "true" if scheme == "https" else "false"

    lines: list[str] = []
    lines.append(
        "# GENERATED — do not hand-edit."
        " Source: deploy/k8s/tenancy/tenant-registry.yaml"
    )
    lines.append("# Regenerate: python scripts/domains/generate_domain_env.py")
    lines.append(
        f"# Patch LMS environment config for {lms_host} domain"
    )
    lines.append("apiVersion: v1")
    lines.append("kind: ConfigMap")
    lines.append("metadata:")
    lines.append("  name: openedx-config")
    lines.append("  namespace: mereka-lms")
    lines.append("data:")
    lines.append(f'  LMS_HOST: "{lms_host}"')
    lines.append(f'  LMS_BASE: "{lms_host}"')
    lines.append(f'  CMS_HOST: "{cms_host}"')
    lines.append(f'  CMS_BASE: "{cms_host}"')
    lines.append(f'  PREVIEW_LMS_BASE: "{preview_host}"')
    lines.append(f'  MFE_HOST: "{mfe_host}"')
    lines.append(f'  ENABLE_HTTPS: "{enable_https}"')
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# YAML generation — mfe-env-patch.yaml
# ---------------------------------------------------------------------------

# Per-environment MFE env var definitions.
# Production and dev include MFE_HOST; staging does not (matches reference files).
MFE_ENV_VARS: dict[str, list[tuple[str, str, str]]] = {
    # (env_name, tenant, role_or_special)
    # role_or_special: "auth_host" means use environment auth_host field
    "dev": [
        ("LMS_HOST", "mereka", "primary"),
        ("CMS_HOST", "mereka", "studio"),
        ("AUTH_HOST", "", "auth_host"),
        ("MFE_HOST", "mereka", "mfe"),
    ],
    "staging": [
        ("LMS_HOST", "mereka", "primary"),
        ("CMS_HOST", "mereka", "studio"),
        ("AUTH_HOST", "", "auth_host"),
    ],
    "production": [
        ("LMS_HOST", "mereka", "primary"),
        ("MFE_HOST", "mereka", "mfe"),
        ("CMS_HOST", "mereka", "studio"),
        ("AUTH_HOST", "", "auth_host"),
    ],
}
# local reuses dev
MFE_ENV_VARS["local"] = MFE_ENV_VARS["dev"]


def generate_mfe_env_patch(overlay_env: str, registry: dict) -> str:
    """Generate mfe-env-patch.yaml for a given overlay environment."""
    reg_env = ENV_TO_REGISTRY[overlay_env]
    domains = build_domain_index(registry)
    env_config = registry.get("environments", {}).get(reg_env, {})
    auth_host = env_config.get("auth_host", "")

    lms_host = domains.get((reg_env, "mereka", "primary"), "")

    lines: list[str] = []
    lines.append(
        "# GENERATED — do not hand-edit."
        " Source: deploy/k8s/tenancy/tenant-registry.yaml"
    )
    lines.append("# Regenerate: python scripts/domains/generate_domain_env.py")
    lines.append(
        f"# Patch MFE Deployment env vars for {lms_host} domain."
    )
    lines.append(
        "# The MFE Caddyfile uses {$VAR:localhost} placeholders in CSP headers;"
    )
    lines.append(
        "# these env vars set the actual hostnames so CSP connect-src, frame-src"
    )
    lines.append(
        "# etc. reference real hosts instead of falling back to 'localhost'."
    )
    lines.append("apiVersion: apps/v1")
    lines.append("kind: Deployment")
    lines.append("metadata:")
    lines.append("  name: mfe")
    lines.append("spec:")
    lines.append("  template:")
    lines.append("    spec:")
    lines.append("      containers:")
    lines.append("        - name: mfe")
    lines.append("          env:")

    mfe_vars = MFE_ENV_VARS.get(overlay_env, MFE_ENV_VARS["dev"])
    for env_name, tenant, role_or_special in mfe_vars:
        if role_or_special == "auth_host":
            value = auth_host
        else:
            value = domains.get((reg_env, tenant, role_or_special), "")
        lines.append(f"            - name: {env_name}")
        lines.append(f'              value: "{value}"')
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# All generated file types
# ---------------------------------------------------------------------------

# Environments that support all patch types (caddy, lms, mfe).
# Includes production which doesn't have a deployment map (domain-env.yaml)
# but does need the standalone patch files.
ALL_ENVS = list(ENV_TO_REGISTRY.keys())

# Patch-only generators — available for every environment in ENV_TO_REGISTRY.
PATCH_GENERATORS: list[tuple[str, Any]] = [
    ("caddy-env-patch.yaml", generate_caddy_env_patch),
    ("lms-env-patch.yaml", generate_lms_env_patch),
    ("mfe-env-patch.yaml", generate_mfe_env_patch),
]


def _get_generated_files(overlay_env: str) -> list[tuple[str, Any]]:
    """Return the list of (filename, generator_fn) pairs for an overlay."""
    files: list[tuple[str, Any]] = []
    # domain-env.yaml is only available when there is a deployment map
    if overlay_env in DEPLOYMENT_MAPS:
        files.append(("domain-env.yaml", generate_env))
    # Patch files are available for all environments in ENV_TO_REGISTRY
    if overlay_env in ENV_TO_REGISTRY:
        files.extend(PATCH_GENERATORS)
    return files


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate domain-env.yaml from tenant registry"
    )
    parser.add_argument("--env", choices=ALL_ENVS,
                        help="Generate for a specific environment")
    parser.add_argument("--check", action="store_true",
                        help="Verify generated output matches committed files")
    args = parser.parse_args()

    registry = load_registry()
    envs = [args.env] if args.env else ALL_ENVS

    if args.check:
        ok = True
        for env in envs:
            for filename, gen_fn in _get_generated_files(env):
                out_path = OUTPUT_DIR / env / filename
                content = gen_fn(env, registry)
                if not out_path.exists():
                    print(f"FAIL: {out_path} does not exist", file=sys.stderr)
                    ok = False
                    continue
                existing = out_path.read_text(encoding="utf-8")
                if existing != content:
                    print(f"FAIL: {out_path} is out of date", file=sys.stderr)
                    ok = False
                else:
                    print(f"OK: {out_path}")
        if not ok:
            print(
                "Run: python scripts/domains/generate_domain_env.py",
                file=sys.stderr,
            )
            return 1
        return 0

    for env in envs:
        for filename, gen_fn in _get_generated_files(env):
            content = gen_fn(env, registry)
            out_path = OUTPUT_DIR / env / filename
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(content, encoding="utf-8")
            print(f"Generated {out_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
