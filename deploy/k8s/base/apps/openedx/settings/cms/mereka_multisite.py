# -*- coding: utf-8 -*-
"""
CMS-side multisite hardening helpers.

This mirrors `lms.envs.tutor.mereka_multisite` but lives in the CMS settings
package so it can be referenced from CMS middleware paths.
"""

from __future__ import annotations

from dataclasses import dataclass
import os
from typing import Optional
from urllib.parse import urlsplit


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


def _domain_from_env_value(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return ""
    if "://" in value:
        value = (urlsplit(value).hostname or "").strip()
    return _strip_port(value.lower())


def _env_site_domain_candidates() -> list[str]:
    raw_candidates = [
        os.environ.get("MEREKA_LMS_DOMAIN", ""),
        os.environ.get("MEREKA_LMS_BASE_URL", ""),
        os.environ.get("LMS_HOST", ""),
        os.environ.get("MEREKA_BIJI_DOMAIN", ""),
    ]
    domains: list[str] = []
    for raw in raw_candidates:
        domain = _domain_from_env_value(raw)
        if not domain:
            continue
        domains.extend(_candidate_site_domains(domain))

    seen = set()
    out: list[str] = []
    for domain in domains:
        if domain in seen:
            continue
        seen.add(domain)
        out.append(domain)
    return out


def _fallback_site_without_request(Site):
    for candidate in _env_site_domain_candidates():
        site = Site.objects.filter(domain__iexact=candidate).first()
        if site is not None:
            return site
    return Site.objects.order_by("id").first()


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
        try:
            return original_get_current(self, None)
        except Exception:
            site = _fallback_site_without_request(Site)
            if site is not None:
                return site
            raise

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


def _lms_root_url_for_host(host: str) -> Optional[str]:
    """
    Resolve LMS_ROOT_URL for a request host.

    Studio's `/signin` redirect uses a static `FRONTEND_LOGIN_URL` setting which
    isn't multisite-aware. We derive the tenant's LMS root from Sites +
    SiteConfiguration instead.
    """
    from django.contrib.sites.models import Site

    for candidate in _candidate_site_domains(host):
        site = Site.objects.filter(domain__iexact=candidate).first()
        if not site:
            continue
        cfg = getattr(site, "configuration", None)
        values = (getattr(cfg, "site_values", None) or {}) if cfg else {}
        lms_root = (values.get("LMS_ROOT_URL") or "").strip()
        if lms_root:
            return lms_root.rstrip("/")
        # Fallback: if we have a Site row but no SiteConfiguration override.
        return f"https://{candidate}".rstrip("/")
    return None


class MerekaStudioSigninRedirectMiddleware:
    """
    Rewrite Studio `/signin` redirects to the correct tenant LMS domain.

    This is a pragmatic backstop because CMS uses a static `FRONTEND_LOGIN_URL`
    which is not computed per-request.
    """

    def __init__(self, get_response):
        patch_sites_framework()
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Only needed for Studio's legacy redirect endpoints.
        path = getattr(request, "path", "") or ""
        if path not in ("/signin", "/signin_redirect_to_lms"):
            return response

        if getattr(response, "status_code", 0) not in (301, 302, 303, 307, 308):
            return response

        location = response.get("Location") if hasattr(response, "get") else None
        if not location or not (location.startswith("http://") or location.startswith("https://")):
            return response

        lms_root = _lms_root_url_for_host(getattr(request, "get_host", lambda: "")())
        if not lms_root:
            return response

        parts = urlsplit(location)
        # Only rewrite redirects to /login or /register endpoints.
        if parts.path not in ("/login", "/register"):
            return response

        response["Location"] = f"{lms_root}{parts.path}" + (f"?{parts.query}" if parts.query else "")
        return response
