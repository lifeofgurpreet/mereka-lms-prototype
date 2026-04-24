"""
Bridge JWT-cookie auth (used by MFEs) into Django session auth for legacy views.

Problem:
- The Authn MFE establishes authentication via JWT cookies.
- Some legacy endpoints (notably LMS OAuth2 provider `/oauth2/authorize`) require a
  Django-authenticated `request.user` (traditionally backed by a Django session).

This middleware attempts to authenticate the incoming request using the existing
JWT-cookie auth machinery and, if successful, ensures `request.user` is set and
persists a Django session login for the request.

Safety:
- Scoped to `/oauth2/` endpoints only. We do not change global auth behavior.
- Uses the platform's JWT auth implementation (including CSRF enforcement where
  applicable).
"""

from __future__ import annotations

from django.conf import settings
from django.contrib.auth import login


class MerekaJwtToSessionBridgeMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        # Import lazily so module import doesn't fail if deps are missing in some contexts.
        from edx_rest_framework_extensions.auth.jwt.authentication import JwtAuthentication

        self._jwt_auth = JwtAuthentication()

    def __call__(self, request):
        path = getattr(request, "path", "") or ""
        if not path.startswith("/oauth2/"):
            return self.get_response(request)

        user = getattr(request, "user", None)
        if user is not None and getattr(user, "is_authenticated", False):
            return self.get_response(request)

        user_and_auth = None
        try:
            user_and_auth = self._jwt_auth.authenticate(request)
        except Exception:
            user_and_auth = None

        if user_and_auth:
            jwt_user = user_and_auth[0]
            request.user = jwt_user
            # Best-effort: persist a Django session so downstream flows that rely on it
            # (and subsequent redirects) remain authenticated.
            try:
                backend = settings.AUTHENTICATION_BACKENDS[0] if settings.AUTHENTICATION_BACKENDS else None
                if backend:
                    login(request, jwt_user, backend=backend)
            except Exception:
                pass

        return self.get_response(request)

