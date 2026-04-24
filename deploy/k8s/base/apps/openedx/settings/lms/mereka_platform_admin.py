import os

# @covers AC-001, AC-002, AC-003, AC-019
# @spec: platform-middleware-custom-apps_spec.md


def _platform_admin_emails() -> set[str]:
    raw = os.environ.get("MEREKA_PLATFORM_ADMIN_EMAILS", "")
    emails = {e.strip().lower() for e in raw.split(",") if e.strip()}
    return emails


class MerekaPlatformAdminMiddleware:
    """
    Ensures platform admins remain staff/superuser in LMS.

    This is intentionally a small, defensive backstop. The source-of-truth
    enforcement remains `./scripts/infra/ensure-platform-admins.sh`, but this
    prevents permission drift from breaking access between enforcement runs.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
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

