# -*- coding: utf-8 -*-
"""
Forwarded header hardening for reverse-proxy deployments.

Problem:
  Some proxy chains (Cloudflare -> Ingress -> Caddy) can produce multi-valued
  X-Forwarded-* headers (e.g. "https,http"). Django's SECURE_PROXY_SSL_HEADER
  requires an exact match ("https"), so requests may be treated as HTTP even
  when the browser is on HTTPS. This can cause URL generation drift and
  authentication callback failures.

Fix:
  Normalize the left-most forwarded header value before Django evaluates it.
"""

# @spec platform-middleware-custom-apps AC-MPC-009: Normalize X-Forwarded-Proto/Port/Host by taking left-most value
# @spec platform-middleware-custom-apps AC-MPC-010: Parse CF-Visitor JSON to extract scheme for X-Forwarded-Proto
# @spec platform-middleware-custom-apps AC-MPC-011: Rewrite HTTP_HOST for /metrics requests from pod IPs
# @spec platform-middleware-custom-apps AC-MPC-012: Force HTTPS for mereka.io/biji-biji.com/mereka.dev hosts

from __future__ import annotations

import json
import os
import re
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
            # Prometheus scrapes pod IPs directly (Host: <pod-ip>:<port>), which Django rejects
            # as DisallowedHost before it can serve /metrics. Rewrite that host to the
            # public LMS domain for the metrics endpoint only.
            try:
                path = getattr(request, "path", "") or ""
            except Exception:
                path = ""
            if path == "/metrics":
                raw_host = (meta.get("HTTP_HOST") or "").split(",", 1)[0].strip().lower()
                if re.match(r"^\\d{1,3}(?:\\.\\d{1,3}){3}(?::\\d+)?$", raw_host or ""):
                    meta["HTTP_HOST"] = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")

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
                        meta["HTTP_X_FORWARDED_PROTO"] = scheme

            if meta.get("HTTP_X_FORWARDED_PROTO"):
                meta["HTTP_X_FORWARDED_PROTO"] = _first_csv_value(meta["HTTP_X_FORWARDED_PROTO"]).lower()
            if meta.get("HTTP_X_FORWARDED_PORT"):
                meta["HTTP_X_FORWARDED_PORT"] = _first_csv_value(meta["HTTP_X_FORWARDED_PORT"])
            if meta.get("HTTP_X_FORWARDED_HOST"):
                meta["HTTP_X_FORWARDED_HOST"] = _first_csv_value(meta["HTTP_X_FORWARDED_HOST"])

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
