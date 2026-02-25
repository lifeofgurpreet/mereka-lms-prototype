# Admin Console Setup (Ulmo RBAC)

Ulmo (Tutor v21 / Open edX 2024) ships `frontend-app-admin-console` as a first-class MFE.
It provides a unified React interface for platform-wide RBAC, content library management,
and organisation administration — replacing the patchwork of Django admin pages for
common operator tasks.

## What the Admin Console Provides

### Role-Based Access Control (RBAC)
- Assign and revoke **organisation roles** (admin, staff, instructor, data researcher)
- Assign roles at the **course-run** or **organisation** level
- Audit role assignments per user or per organisation
- Replace ad-hoc Django admin user/group editing for instructors

### Content Library Management
- Create and manage **Blockstore-backed content libraries** (v2 libraries)
- Add library team members and set per-library roles (read, author, admin)
- Browse library blocks and push them to courses

### Organisation Administration
- Create and manage Open edX organisations (`orgs`)
- Link organisations to course catalogs (used by Enterprise)

### Admin Audit
- View a log of recent permission changes (who changed what, when)

## URL and Access

The Admin Console MFE is served as a sub-path of the MFE host:

| Environment | URL |
|-------------|-----|
| Production  | `https://apps.academyv2.mereka.io/admin-console/` |
| Dev (kind)  | `https://apps.academyv2.mereka.dev/admin-console/` |
| Local       | `http://apps.localhost/admin-console/` |

No separate subdomain is required. The existing `mfe:8002` Caddy route in
`deploy/k8s/base/apps/caddy/Caddyfile` serves all MFE sub-paths, including `/admin-console/`.

### Access Requirements

A user must satisfy **all** of the following:

1. **Authenticated** — logged in via Authentik OIDC (the platform SSO)
2. **Staff flag set** — `is_staff=True` on the Django user record, OR
3. **Superuser flag set** — `is_superuser=True`, OR
4. **Organisation admin role** — assigned an `organisation_admin` role via the RBAC API

To grant staff access from the Django admin or shell:

```bash
# Via kubectl exec (production)
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms shell -c "
from django.contrib.auth import get_user_model
u = get_user_model().objects.get(username='<username>')
u.is_staff = True
u.save()
"
```

```bash
# Via tutor (local)
tutor local run lms python manage.py lms changepassword <username>
# or
tutor local run lms python manage.py lms shell
```

## Ulmo RBAC Model

Ulmo introduces two complementary RBAC layers:

### 1. Course-Level Roles (legacy, still active)
These are stored in `CourseAccessRole` (MySQL) and assigned via Studio or Django admin:
- `instructor` — full course access
- `staff` — course staff (limited)
- `beta_testers` — beta access
- `finance_admin`, `sales_admin` — ecommerce

### 2. Organisation-Level Roles (new in Ulmo)
Stored in `OrganizationRole` (MySQL via `organizations` app):
- `organization_admin` — manage all courses and users within an org
- `organization_course_admin` — manage courses within an org
- `organization_data_researcher` — analytics access

### 3. Platform-Level Flags
Set on the Django `User` model:
- `is_staff` — access to Django admin, Admin Console, and operator endpoints
- `is_superuser` — unrestricted access to all platform resources

### Role Hierarchy

```
is_superuser
  └── is_staff
        └── organization_admin
              └── organization_course_admin
                    └── course instructor
                          └── course staff
```

## Configuration Required

### Feature Flags

The Admin Console reads configuration from the MFE Config API (`/api/mfe_config/v1`).
No additional Django feature flags are required to enable the console UI in Ulmo — it
ships enabled by default.

However, the following LMS settings must be present for the underlying APIs to function:

```python
# Required in LMS production settings (already set via mereka_lms plugin)
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = True

# Content libraries v2 (already added via mereka_lms plugin)
INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
```

No changes to `infrastructure/tutor/apply-patches.sh` are needed — the required apps
are already present via `infrastructure/tutor/plugins/mereka_lms.py`.

### Caddyfile Routing

No Caddyfile changes are required. The Admin Console MFE is served at the `/admin-console/`
sub-path through the existing `mfe:8002` proxy block:

```
# apps.academyv2.mereka.io already handles this:
http://apps.academyv2.mereka.io, ... {
    import proxy "mfe:8002"
}
```

The MFE Caddy image (built from `infrastructure/tutor/mfe-build/Dockerfile`) copies
the built admin-console assets to `/openedx/dist/admin-console` and serves them.

### CSRF and Session Cookies

Admin Console makes API calls to `academyv2.mereka.io` from `apps.academyv2.mereka.io`.
These are cross-origin, covered by the existing settings:

```python
SESSION_COOKIE_DOMAIN = ".academyv2.mereka.io"
CSRF_COOKIE_DOMAIN = ".academyv2.mereka.io"
CSRF_TRUSTED_ORIGINS = ["https://apps.academyv2.mereka.io", ...]
```

These are already set via `mereka_lms.py`. No additional CSRF configuration is needed.

## Library Team Management

Content libraries are accessible at `/admin-console/libraries/`.

### Create a Library

1. Navigate to `https://apps.academyv2.mereka.io/admin-console/libraries/`
2. Click **New Library**
3. Set a display name and org key (must match an existing org in Open edX)
4. Library is created via the Blockstore API (`/api/libraries/v2/`)

### Add Library Team Members

1. Open the library detail page
2. Go to the **Team** tab
3. Enter a username and select a role:
   - **Read** — view blocks, cannot edit
   - **Author** — create and edit blocks
   - **Admin** — manage team + full edit access

Library roles are stored per-library in the `ContentLibraryPermission` table.

### Library GCS Storage

Libraries use GCS for block assets. Setup is documented in
`docs/operations/LIBRARIES_GCS_SETUP.md`.

## Integration with Authentik SSO

The Admin Console authenticates via the standard Open edX session. The login flow is:

```
User visits /admin-console/
  → MFE checks for valid LMS session cookie
  → If missing: redirect to /authn/login (Authn MFE)
  → Authn MFE redirects to Authentik OIDC
  → User authenticates with Authentik
  → Session cookie set on .academyv2.mereka.io
  → Admin Console re-checks staff/superuser status
  → Access granted or 403 shown
```

No additional Authentik configuration is needed. The Admin Console relies on the same
OIDC client already configured for the LMS (`LMS_OIDC_KEY`).

### Admin Console and Authentik Groups

If you use Authentik group-based role sync (via `SOCIAL_AUTH_EDX_OAUTH2_*` claims),
ensure the `is_staff` claim is forwarded. See `docs/operations/AUTH_AND_PERMISSIONS.md`
for the Authentik property mapping setup.

## Verification

Run the automated check:

```bash
./scripts/qa/verify-admin-console.sh
```

Expected output:
```
[PASS] admin-console MFE present in Dockerfile
[PASS] admin-console production stage present in Dockerfile
[PASS] admin-console assets COPY step present in Dockerfile
[PASS] MFE route (apps subdomain) present in Caddyfile
[PASS] Content libraries app listed in plugin settings
[PASS] CSRF trusted origins include apps subdomain
[INFO] Admin Console URL: https://apps.academyv2.mereka.io/admin-console/
All checks passed (6/6)
```

## Troubleshooting

### 403 on /admin-console/

The user is authenticated but not staff. Grant `is_staff=True` via Django admin or
the shell command above.

### Blank page / JS error

Check that the MFE image was built with the `admin-console` stage. Run:
```bash
./scripts/qa/verify-admin-console.sh
```

If the Dockerfile check fails, the image needs to be rebuilt:
```bash
tutor images build mfe
```

### CSRF error when saving roles

Verify `SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` are both set to `.academyv2.mereka.io`.
Run `./scripts/qa/verify-csrf-multisite.sh` to check.

### Organisation not found when assigning roles

Organisations must exist in the Open edX `organizations_organization` table before
roles can be assigned. Create them via:
```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms shell -c "
from organizations.models import Organization
Organization.objects.get_or_create(short_name='MEREKA', defaults={'name': 'Mereka Academy'})
"
```
