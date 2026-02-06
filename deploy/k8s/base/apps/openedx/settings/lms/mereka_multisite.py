# -*- coding: utf-8 -*-
"""
Multisite hardening helpers for Open edX.

Goals:
- Keep a stable SITE_ID for background tasks, but resolve the "current site"
  from the request host for web requests (apps./studio./preview. should map to
  the tenant's LMS domain).
- Ensure cookies never set an invalid Domain attribute when serving multiple
  root domains (academyv2.mereka.io vs biji-biji.com).

This module is imported via middleware in production settings.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


_PATCHED = False


def _strip_port(host: str) -> str:
    if not host:
        return host
    # request.get_host() may include ":port"
    return host.split(":", 1)[0]


def _candidate_site_domains(host: str) -> list[str]:
    """
    Return candidate django_site.domain values for a request host.

    We keep Sites keyed on the tenant's LMS domain (e.g. academyv2.mereka.io,
    academy.biji-biji.com, skillourfuture.academy.mereka.io). Subdomains that
    are part of the same tenant should map back to that tenant domain.
    """
    host = _strip_port(host.lower())
    candidates = [host]
    for prefix in ("apps.", "studio.", "preview."):
        if host.startswith(prefix):
            candidates.append(host[len(prefix) :])
            break
    # De-dupe while preserving order.
    seen = set()
    out: list[str] = []
    for c in candidates:
        if c and c not in seen:
            out.append(c)
            seen.add(c)
    return out


def patch_sites_framework() -> None:
    """
    Make Site.objects.get_current(request) prefer host-based site resolution
    when a request is provided, while keeping settings.SITE_ID for non-request
    code paths (Celery, management commands, etc).
    """
    global _PATCHED
    if _PATCHED:
        return

    from django.contrib.sites.models import Site, SiteManager

    original_get_current = SiteManager.get_current

    def get_current(self: SiteManager, request=None):  # type: ignore[override]
        if request is not None:
            for candidate in _candidate_site_domains(request.get_host() or ""):
                site = Site.objects.filter(domain__iexact=candidate).first()
                if site is not None:
                    return site
        # Fall back to the original behavior (SITE_ID-based).
        return original_get_current(self, None)

    # Idempotent patching guard.
    get_current._mereka_patched = True  # type: ignore[attr-defined]
    SiteManager.get_current = get_current  # type: ignore[assignment]

    _PATCHED = True


@dataclass(frozen=True)
class _CookiePolicy:
    domain: Optional[str]


def _cookie_policy_for_host(host: str) -> _CookiePolicy:
    host = _strip_port((host or "").lower())
    if not host:
        return _CookiePolicy(domain=None)

    # Local dev / unknown hosts: keep host-only cookies.
    if host == "localhost" or host.endswith(".localhost"):
        return _CookiePolicy(domain=None)

    # Determine tenant root for cookie scoping.
    tenant = _candidate_site_domains(host)[-1]  # last candidate is stripped one (if any)
    if not tenant:
        return _CookiePolicy(domain=None)

    # Multi-root handling:
    # - academyv2.mereka.io (+ its subdomains) => .academyv2.mereka.io
    # - academy.biji-biji.com (+ its subdomains) => .biji-biji.com
    # - skillourfuture.academy.mereka.io => .skillourfuture.academy.mereka.io
    if tenant.endswith("biji-biji.com"):
        return _CookiePolicy(domain=".biji-biji.com")

    return _CookiePolicy(domain=f".{tenant}")


class MerekaCookieDomainMiddleware:
    """
    Rewrite cookie domains per-request so we never emit invalid Domain= values
    when serving multiple root domains from the same Django settings module.
    """

    def __init__(self, get_response):
        patch_sites_framework()
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        policy = _cookie_policy_for_host(getattr(request, "get_host", lambda: "")())
        if not policy.domain:
            # Host-only cookies.
            for name in ("sessionid", "csrftoken", "edx-jwt-cookie-header-payload", "user-info"):
                if name in response.cookies and "domain" in response.cookies[name]:
                    del response.cookies[name]["domain"]
            return response

        for name in ("sessionid", "csrftoken", "edx-jwt-cookie-header-payload", "user-info"):
            if name in response.cookies:
                response.cookies[name]["domain"] = policy.domain

        return response

