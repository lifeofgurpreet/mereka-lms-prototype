# -*- coding: utf-8 -*-
"""
Multisite hardening helpers for Open edX.

Goals:
- Keep a stable SITE_ID for background tasks, but resolve the "current site"
  from the request host for web requests (apps./studio./preview. should map to
  the tenant's LMS domain).
- Ensure cookies never set an invalid Domain attribute when serving multiple
  root domains (academyv2.mereka.io vs biji-biji.com).
- Rewrite /login redirects to the tenant's MFE authn surface (not the global one).

This module is imported via middleware in production settings.
"""

# @covers AC-004, AC-005, AC-006, AC-007, AC-008
# @spec: platform-middleware-custom-apps_spec.md

from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import os
from typing import Optional
from urllib.parse import urlsplit

_log = logging.getLogger(__name__)


_PATCHED = False
_FALLBACK_MFE_PATH_PREFIXES = (
    "/authn",
    "/account",
    "/authoring",
    "/communications",
    "/discussions",
    "/gradebook",
    "/learner-dashboard",
    "/learner-record",
    "/learning",
    "/ora-grading",
    "/orders",
    "/payment",
    "/u/",
)
_LOGIN_SESSION_PATHS = (
    "/api/user/v1/account/login_session/",
    "/api/user/v2/account/login_session/",
)


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

    Handles environment-prefixed domains:
      staging.apps.academyv2.mereka.io  → staging.academyv2.mereka.io
      staging.studio.academy.biji-biji.com → staging.academy.biji-biji.com
    """
    host = _strip_port(host.lower())
    candidates = [host]
    _service_prefixes = ("apps.", "studio.", "preview.", "admin.")

    # Direct service prefix (e.g. apps.academyv2.mereka.io → academyv2.mereka.io)
    for prefix in _service_prefixes:
        if host.startswith(prefix):
            candidates.append(host[len(prefix):])
            break
    else:
        # Environment prefix + service (e.g. staging.apps.X → staging.X)
        for env_prefix in ("staging.", "dev."):
            if host.startswith(env_prefix):
                remainder = host[len(env_prefix):]
                for svc_prefix in _service_prefixes:
                    if remainder.startswith(svc_prefix):
                        candidates.append(env_prefix + remainder[len(svc_prefix):])
                        break
                break

    # De-dupe while preserving order.
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
    # Support both host values (academyv2.mereka.io) and full URLs.
    if "://" in value:
        value = (urlsplit(value).hostname or "").strip()
    return _strip_port(value.lower())


def _env_site_domain_candidates() -> list[str]:
    raw_candidates = [
        os.environ.get("MEREKA_LMS_DOMAIN", ""),
        os.environ.get("MEREKA_LMS_BASE_URL", ""),
        os.environ.get("LMS_HOST", ""),
        os.environ.get("MEREKA_BIJI_DOMAIN", ""),
        os.environ.get("MEREKA_SKILLOURFUTURE_DOMAIN", ""),
    ]
    domains: list[str] = []
    for raw in raw_candidates:
        domain = _domain_from_env_value(raw)
        if not domain:
            continue
        domains.extend(_candidate_site_domains(domain))

    # De-dupe while preserving order.
    seen = set()
    out: list[str] = []
    for domain in domains:
        if domain in seen:
            continue
        seen.add(domain)
        out.append(domain)
    return out


def _fallback_site_without_request(Site):
    """
    Resolve a safe default Site row when SITE_ID is stale after DB restores.
    """
    for candidate in _env_site_domain_candidates():
        site = Site.objects.filter(domain__iexact=candidate).first()
        if site is not None:
            return site
    return Site.objects.order_by("id").first()


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
        # Fall back to the original behavior (SITE_ID-based). If the configured
        # SITE_ID points to a missing row after restore/migration, use domain-
        # based fallback so endpoints such as /api/mfe_config/v1 stay healthy.
        try:
            return original_get_current(self, None)
        except Exception:
            site = _fallback_site_without_request(Site)
            if site is not None:
                return site
            raise

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
    # - academy.biji-biji.com (+ its subdomains) => .academy.biji-biji.com
    # - skillourfuture.academy.mereka.io => .skillourfuture.academy.mereka.io
    #
    # Staging/dev domain hierarchy fix:
    #   staging.academyv2.mereka.io (LMS) and staging.apps.academyv2.mereka.io (MFE)
    #   do NOT share a parent-child relationship in DNS. The only common ancestor is
    #   .academyv2.mereka.io. We must use the base domain (strip env prefix) as cookie
    #   domain so MFE JS can read cookies set by LMS.
    #
    #   Risk: staging cookies sent to production. Acceptable because:
    #   - Production cookies already leak to staging subdomains (by being scoped to
    #     .academyv2.mereka.io). Session/JWT cookies are validated server-side and
    #     foreign-environment cookies are simply rejected.
    for env_prefix in ("staging.", "dev."):
        if tenant.startswith(env_prefix):
            base = tenant[len(env_prefix):]
            return _CookiePolicy(domain=f".{base}")

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


def _mfe_base_url_for_host(host: str) -> Optional[str]:
    """
    Resolve the tenant's MFE base URL from SiteConfiguration.

    Returns the full MFE_BASE_URL (e.g. https://apps.staging.academy.biji-biji.com)
    or None if no SiteConfiguration override exists.
    """
    from django.contrib.sites.models import Site

    for candidate in _candidate_site_domains(host):
        site = Site.objects.filter(domain__iexact=candidate).first()
        if not site:
            continue
        cfg = getattr(site, "configuration", None)
        values = (getattr(cfg, "site_values", None) or {}) if cfg else {}
        mfe_base = (values.get("MFE_BASE_URL") or "").strip().rstrip("/")
        if mfe_base:
            return mfe_base
    return None


def _mfe_path_prefixes() -> tuple[str, ...]:
    """
    Return the known MFE path prefixes for this deployment.

    Prefer settings-backed values so the redirect contract stays aligned with
    the configured MFE surfaces. Fall back to the canonical Open edX/Mereka
    set if settings are unavailable in isolated tests.
    """
    try:
        from django.conf import settings

        paths: list[str] = []
        config_urls = getattr(settings, "MFE_CONFIG_API_URLS", None)
        if not isinstance(config_urls, dict):
            config_urls = {}

        for url in config_urls.values():
            path = (urlsplit(url).path or "").rstrip("/")
            if not path:
                continue
            if path == "/u":
                path = "/u/"
            paths.append(path)

        if paths:
            return tuple(dict.fromkeys(paths))
    except Exception:
        pass

    return _FALLBACK_MFE_PATH_PREFIXES


def _rewrite_redirect_url_to_tenant_mfe(host: str, redirect_url: str) -> str:
    """
    Normalize deep MFE redirects to the tenant's MFE base URL.

    login_session responses are generated by LMS, so Open edX can return a
    correct path on the wrong host (academyv2.../learning/...). When the path
    points at an MFE-owned surface, rewrite it onto the tenant's MFE origin.
    """
    if not redirect_url:
        return redirect_url

    mfe_base = _mfe_base_url_for_host(host)
    if not mfe_base:
        return redirect_url

    parts = urlsplit(redirect_url)
    path = parts.path or ""
    if not any(path.startswith(prefix) for prefix in _mfe_path_prefixes()):
        return redirect_url

    rewritten = f"{mfe_base}{path}"
    if parts.query:
        rewritten += f"?{parts.query}"
    if parts.fragment:
        rewritten += f"#{parts.fragment}"
    return rewritten


class MerekaLoginRedirectMiddleware:
    """
    Rewrite LMS auth redirects to the tenant's MFE surface.

    Open edX's login view (student.views.login.login_and_registration_form)
    reads settings.AUTHN_MICROFRONTEND_URL which is a global static value.
    For multi-tenant, the redirect must point to the tenant's own MFE app,
    not the primary tenant's.

    This middleware intercepts:
    - 302 responses from /login and rewrites the Location header to use the
      tenant's MFE_BASE_URL from SiteConfiguration.
    - successful login_session JSON responses and rewrites redirect_url when
      Open edX returns an MFE deep route on the LMS host instead of the
      tenant's apps host.
    """

    def __init__(self, get_response):
        patch_sites_framework()
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        path = getattr(request, "path", "") or ""
        host = getattr(request, "get_host", lambda: "")()

        if path in _LOGIN_SESSION_PATHS:
            return self._rewrite_login_session_response(host, response)

        if path != "/login":
            return response

        if getattr(response, "status_code", 0) not in (301, 302, 303, 307, 308):
            return response

        location = response.get("Location") if hasattr(response, "get") else None
        if not location:
            return response

        # Only rewrite redirects that point to an MFE authn path.
        parts = urlsplit(location)
        if "/authn" not in parts.path:
            return response

        new_location = _rewrite_redirect_url_to_tenant_mfe(host, location)

        if new_location != location:
            _log.info("MerekaLoginRedirect: %s -> %s (host=%s)", location, new_location, host)
            response["Location"] = new_location
        return response

    def _rewrite_login_session_response(self, host: str, response):
        if getattr(response, "status_code", 0) != 200:
            return response
        if not hasattr(response, "content"):
            return response

        try:
            payload = json.loads(response.content.decode("utf-8"))
        except Exception:
            return response

        redirect_url = payload.get("redirect_url")
        if not redirect_url:
            return response

        new_redirect = _rewrite_redirect_url_to_tenant_mfe(host, redirect_url)
        if new_redirect == redirect_url:
            return response

        payload["redirect_url"] = new_redirect
        response.content = json.dumps(payload).encode("utf-8")
        if hasattr(response, "__setitem__"):
            response["Content-Length"] = str(len(response.content))
        _log.info("MerekaLoginSessionRedirect: %s -> %s (host=%s)", redirect_url, new_redirect, host)
        return response
