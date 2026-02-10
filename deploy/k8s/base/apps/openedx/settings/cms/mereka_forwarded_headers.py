# -*- coding: utf-8 -*-
"""
Forwarded header hardening for reverse-proxy deployments.

Problem:
  Some proxy chains (Cloudflare -> Ingress -> Caddy) can produce multi-valued
  X-Forwarded-* headers (e.g. "https,http"). Django's SECURE_PROXY_SSL_HEADER
  requires an exact match ("https"), so requests may be treated as HTTP even
  when the browser is on HTTPS. In Studio this shows up as:
    - Login links containing next=http://studio...
    - OAuth callback failures (AuthStateMissing / "Session value state missing")
      because Secure cookies may not be set/sent consistently.

Fix:
  Normalize the left-most forwarded header value before Django evaluates it.
"""

from __future__ import annotations

import json
from typing import Optional


def _first_csv_value(value: Optional[str]) -> str:
    if not value:
        return ""
    return value.split(",", 1)[0].strip()


class MerekaForwardedHeadersMiddleware:
    """
    Normalize common forwarded headers so Django can reliably detect HTTPS.

    This middleware MUST run early in the chain.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        meta = getattr(request, "META", None)
        if isinstance(meta, dict):
            for key in ("HTTP_X_FORWARDED_PROTO", "HTTP_X_FORWARDED_PORT", "HTTP_X_FORWARDED_HOST"):
                value = meta.get(key)
                if value and "," in value:
                    meta[key] = _first_csv_value(value)

            # Cloudflare may pass the original scheme via CF-Visitor.
            # Example: {"scheme":"https"}
            cf_visitor = meta.get("HTTP_CF_VISITOR")
            if cf_visitor:
                try:
                    parsed = json.loads(cf_visitor)
                except Exception:
                    parsed = None
                if isinstance(parsed, dict):
                    scheme = (parsed.get("scheme") or "").strip().lower()
                    if scheme in {"http", "https"}:
                        # Prefer Cloudflare's view of the client scheme. This
                        # fixes cases where intermediate proxies append/override
                        # X-Forwarded-Proto.
                        meta["HTTP_X_FORWARDED_PROTO"] = scheme

            # Final normalization (even after CF-Visitor override).
            if meta.get("HTTP_X_FORWARDED_PROTO"):
                meta["HTTP_X_FORWARDED_PROTO"] = _first_csv_value(meta["HTTP_X_FORWARDED_PROTO"]).lower()
            if meta.get("HTTP_X_FORWARDED_PORT"):
                meta["HTTP_X_FORWARDED_PORT"] = _first_csv_value(meta["HTTP_X_FORWARDED_PORT"])
            if meta.get("HTTP_X_FORWARDED_HOST"):
                meta["HTTP_X_FORWARDED_HOST"] = _first_csv_value(meta["HTTP_X_FORWARDED_HOST"])

            # Defensive fallback:
            # If proxy chain drops/overwrites X-Forwarded-Proto, force https for
            # known public hosts. In production, ingress enforces TLS and http
            # requests never reach the app; treating these as https is safe and
            # prevents Studio generating `next=http://...` URLs.
            host = (
                (meta.get("HTTP_X_FORWARDED_HOST") or meta.get("HTTP_HOST") or "")
                .split(",", 1)[0]
                .strip()
                .lower()
            )
            if host and (host.endswith(".mereka.io") or host.endswith(".biji-biji.com") or host.endswith(".mereka.dev")):
                if meta.get("HTTP_X_FORWARDED_PROTO") in {"", None, "http"}:
                    meta["HTTP_X_FORWARDED_PROTO"] = "https"

        return self.get_response(request)
