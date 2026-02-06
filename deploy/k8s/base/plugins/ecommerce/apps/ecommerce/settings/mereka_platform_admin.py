import os
from urllib.parse import urlencode

from django.http import HttpResponseRedirect


def _platform_admin_emails() -> set[str]:
    raw = os.environ.get("MEREKA_PLATFORM_ADMIN_EMAILS", "")
    emails = {e.strip().lower() for e in raw.split(",") if e.strip()}
    return emails


def _should_redirect_admin_login(path: str) -> bool:
    return path.rstrip("/") == "/admin/login"


class MerekaPlatformAdminMiddleware:
    """
    Hardening middleware:
    1) Redirect /admin/login -> /login (SSO entrypoint) for consistent UX.
    2) If an authenticated user is in MEREKA_PLATFORM_ADMIN_EMAILS, ensure staff/superuser.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method in ("GET", "HEAD") and _should_redirect_admin_login(request.path):
            next_path = request.GET.get("next", "/admin/")
            return HttpResponseRedirect("/login/?" + urlencode({"next": next_path}))

        user = getattr(request, "user", None)
        if user and getattr(user, "is_authenticated", False):
            email = (getattr(user, "email", "") or "").strip().lower()
            if email and email in _platform_admin_emails():
                changed = (
                    (not getattr(user, "is_active", True))
                    or (not getattr(user, "is_staff", False))
                    or (not getattr(user, "is_superuser", False))
                )
                if changed:
                    user.is_active = True
                    user.is_staff = True
                    user.is_superuser = True
                    user.save(update_fields=["is_active", "is_staff", "is_superuser"])

        return self.get_response(request)
