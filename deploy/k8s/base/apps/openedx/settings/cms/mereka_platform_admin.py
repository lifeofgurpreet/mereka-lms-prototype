import os


def _platform_admin_emails() -> set[str]:
    raw = os.environ.get("MEREKA_PLATFORM_ADMIN_EMAILS", "")
    emails = {e.strip().lower() for e in raw.split(",") if e.strip()}
    return emails


class MerekaPlatformAdminMiddleware:
    """
    Ensures platform admins remain staff/superuser in CMS and can create courses.
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

                # Ensure Studio "New Course" works (CourseCreator).
                try:
                    from cms.djangoapps.course_creators.models import CourseCreator
                except Exception:
                    CourseCreator = None
                if CourseCreator:
                    cc = CourseCreator.objects.filter(user=user).first()
                    if not cc:
                        CourseCreator.objects.create(
                            user=user,
                            state=CourseCreator.GRANTED,
                            all_organizations=True,
                        )
                    else:
                        fields = []
                        if cc.state != CourseCreator.GRANTED:
                            cc.state = CourseCreator.GRANTED
                            fields.append("state")
                        if not cc.all_organizations:
                            cc.all_organizations = True
                            fields.append("all_organizations")
                        if fields:
                            cc.save(update_fields=fields)

        return self.get_response(request)

