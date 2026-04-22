"""
Runtime URL helpers shared by LMS templates and tenant-aware local builds.

These helpers intentionally live in an installed custom app, not in
``lms.envs.tutor`` or rendered settings modules. Mako templates are compiled at
runtime and must not depend on deployment-only settings files that are absent
from repo-built Tutor images.
"""

from __future__ import annotations

import logging
from typing import Optional
from urllib.parse import urlencode

_log = logging.getLogger(__name__)


def _strip_port(host: str) -> str:
    if not host:
        return host
    return host.split(":", 1)[0]


def candidate_site_domains(host: str) -> list[str]:
    """
    Return candidate django_site.domain values for a request host.

    Tenant Site rows are keyed on LMS domains. Service hosts such as
    ``apps.example`` and ``studio.example`` should map back to the tenant LMS
    domain when a template needs to resolve tenant-local MFE URLs.
    """

    host = _strip_port((host or "").lower())
    candidates = [host]
    service_prefixes = ("apps.", "studio.", "preview.", "admin.")

    for prefix in service_prefixes:
        if host.startswith(prefix):
            candidates.append(host[len(prefix):])
            break
    else:
        for env_prefix in ("staging.", "dev."):
            if not host.startswith(env_prefix):
                continue
            remainder = host[len(env_prefix):]
            for service_prefix in service_prefixes:
                if remainder.startswith(service_prefix):
                    candidates.append(env_prefix + remainder[len(service_prefix):])
                    break
            break

    seen: set[str] = set()
    out: list[str] = []
    for candidate in candidates:
        if candidate and candidate not in seen:
            out.append(candidate)
            seen.add(candidate)
    return out


def mfe_base_url_for_host(host: str) -> Optional[str]:
    """
    Resolve a tenant's MFE base URL from SiteConfiguration.

    Returns the full MFE base URL or ``None`` if no matching SiteConfiguration
    value is available.
    """

    from django.contrib.sites.models import Site

    for candidate in candidate_site_domains(host):
        site = Site.objects.filter(domain__iexact=candidate).first()
        if not site:
            continue
        cfg = getattr(site, "configuration", None)
        values = (getattr(cfg, "site_values", None) or {}) if cfg else {}
        mfe_base = (values.get("MFE_BASE_URL") or "").strip().rstrip("/")
        if mfe_base:
            return mfe_base
    return None


def tenant_mfe_url(host: str, path: str, query: Optional[dict[str, str]] = None) -> Optional[str]:
    """
    Build a tenant-local MFE URL for a request host and path.
    """

    mfe_base = mfe_base_url_for_host(host)
    if not mfe_base:
        return None

    normalized_path = path if path.startswith("/") else f"/{path}"
    url = f"{mfe_base.rstrip('/')}{normalized_path}"
    if query:
        url = f"{url}?{urlencode(query)}"
    return url


def tenant_authn_microfrontend_url_for_host(host: str, default_url: str) -> str:
    """
    Resolve the Authn MFE base URL for an LMS request host.

    Anonymous LMS shell pages render outside the ``/api/mfe_config/v1`` contract.
    Prefer a tenant's configured MFE base URL when one is available, then fall
    back to the caller-provided default URL.
    """

    try:
        tenant_authn_url = tenant_mfe_url(host, "/authn")
    except Exception as exc:
        _log.warning(
            "Falling back to default authn MFE URL for host %s: %s",
            host,
            exc,
        )
        tenant_authn_url = None
    if tenant_authn_url:
        return tenant_authn_url.rstrip("/")
    return (default_url or "").strip().rstrip("/")
