# -*- coding: utf-8 -*-
"""
CMS-side multisite hardening helpers.

This mirrors `lms.envs.tutor.mereka_multisite` but lives in the CMS settings
package so it can be referenced from CMS middleware paths.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


_PATCHED = False


def _strip_port(host: str) -> str:
    if not host:
        return host
    return host.split(":", 1)[0]


def _candidate_site_domains(host: str) -> list[str]:
    host = _strip_port(host.lower())
    candidates = [host]
    for prefix in ("apps.", "studio.", "preview."):
        if host.startswith(prefix):
            candidates.append(host[len(prefix) :])
            break
    seen = set()
    out: list[str] = []
    for c in candidates:
        if c and c not in seen:
            out.append(c)
            seen.add(c)
    return out


def patch_sites_framework() -> None:
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
        return original_get_current(self, None)

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
    if host == "localhost" or host.endswith(".localhost"):
        return _CookiePolicy(domain=None)

    tenant = _candidate_site_domains(host)[-1]
    if not tenant:
        return _CookiePolicy(domain=None)
    if tenant.endswith("biji-biji.com"):
        return _CookiePolicy(domain=".biji-biji.com")
    return _CookiePolicy(domain=f".{tenant}")


class MerekaCookieDomainMiddleware:
    def __init__(self, get_response):
        patch_sites_framework()
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        policy = _cookie_policy_for_host(getattr(request, "get_host", lambda: "")())
        if not policy.domain:
            for name in ("sessionid", "csrftoken", "edx-jwt-cookie-header-payload", "user-info"):
                if name in response.cookies and "domain" in response.cookies[name]:
                    del response.cookies[name]["domain"]
            return response

        for name in ("sessionid", "csrftoken", "edx-jwt-cookie-header-payload", "user-info"):
            if name in response.cookies:
                response.cookies[name]["domain"] = policy.domain

        return response

