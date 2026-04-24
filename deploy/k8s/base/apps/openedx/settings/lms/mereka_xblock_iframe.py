# -*- coding: utf-8 -*-
"""
Tenant-aware iframe header overrides for XBlock unit responses.

Problem:
  The learning MFE hosts unit content on the apps subdomain, but the LMS serves
  the unit iframe from the LMS host. A global X-Frame-Options=SAMEORIGIN policy
  blocks that cross-subdomain embed even when both hosts belong to the same
  tenant surface.

Fix:
  For /xblock/* responses only, remove X-Frame-Options and emit an explicit
  Content-Security-Policy frame-ancestors directive that allows the tenant's
  MFE origin. Leave all other LMS responses unchanged.
"""

from __future__ import annotations

from urllib.parse import urlsplit

from django.conf import settings


def _origin_from_url(raw_url: str) -> str:
    if not raw_url:
        return ""
    parts = urlsplit(raw_url)
    if not parts.scheme or not parts.netloc:
        return ""
    return f"{parts.scheme}://{parts.netloc}"


def _tenant_mfe_base_url_for_host(host: str) -> str:
    try:
        from .mereka_multisite import _mfe_base_url_for_host
    except Exception:
        return ""
    try:
        return (_mfe_base_url_for_host(host) or "").strip().rstrip("/")
    except Exception:
        return ""


def _frame_ancestors_for_request(request) -> tuple[str, ...]:
    ancestors = ["'self'"]

    host = ""
    try:
        host = (request.get_host() or "").strip()
    except Exception:
        host = ""

    candidates = (
        _tenant_mfe_base_url_for_host(host),
        getattr(settings, "MEREKA_MFE_BASE_URL", ""),
    )
    for candidate in candidates:
        origin = _origin_from_url(candidate)
        if origin and origin not in ancestors:
            ancestors.append(origin)
    return tuple(ancestors)


def _replace_frame_ancestors_directive(existing_value: str, ancestors: tuple[str, ...]) -> str:
    directives = [directive.strip() for directive in (existing_value or "").split(";") if directive.strip()]
    filtered = [directive for directive in directives if not directive.lower().startswith("frame-ancestors")]
    filtered.append(f"frame-ancestors {' '.join(ancestors)}")
    return "; ".join(filtered)


class MerekaXBlockIframeMiddleware:
    """
    Permit tenant MFE origins to embed LMS /xblock/* responses.

    This middleware must run before Django's XFrameOptionsMiddleware so that on
    the response path it runs after that middleware and can remove the global
    SAMEORIGIN header for learner iframe responses only.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        path = getattr(request, "path", "") or ""
        if not path.startswith("/xblock/"):
            return response

        if "X-Frame-Options" in response:
            del response["X-Frame-Options"]

        ancestors = _frame_ancestors_for_request(request)
        response["Content-Security-Policy"] = _replace_frame_ancestors_directive(
            response.get("Content-Security-Policy", ""),
            ancestors,
        )
        return response
