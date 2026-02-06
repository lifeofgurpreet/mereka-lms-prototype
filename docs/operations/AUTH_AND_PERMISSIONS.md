# Authentication and Permissions (Open edX + Authentik)
_Last updated: 2026-02-06_

This document explains how authentication (login) and authorization (permissions) work in the Mereka Open edX ecosystem.

## Summary

- **Authentik (OIDC)** answers: "Who are you?"
- **Open edX (LMS/CMS)** and **other Django services** (Discovery, Credentials, Ecommerce) answer: "What can you do?"

By default, **permissions do not sync from Authentik into Open edX**. Logging in via OIDC will create/link a user account, but **staff/superuser** and **CourseCreator** are controlled in each service database.

## Required Platform Admins

These humans must have full permissions in production and dev:
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Enforce (idempotent):
```bash
./scripts/infra/ensure-platform-admins.sh
```

## Open edX (LMS/CMS) Permission Levels

Global flags (site-wide):
- `is_active`: user can log in
- `is_staff`: enables staff UI features and can be granted Django admin access
- `is_superuser`: full Django admin (effectively "super admin" for LMS/CMS)

Studio course creation:
- `CourseCreator(state=granted)`: required for "New Course" to work in Studio

Per-course roles:
- Assigned in Studio (Course Team) and apply to a single course.

## How Login Works

### LMS/CMS

Two flows exist and should continue to work:
- **Native Open edX login**: `/login`
- **Authentik OIDC (SSO)**: `/auth/login/oidc/` then callback to `/auth/complete/oidc`

### Discovery/Credentials/Ecommerce Admin Access

These services have Django Admin sites (`/admin/`), but their `/admin/login/` pages are username/password only.

To access admin as a platform admin:
1. Log in via SSO first:
   - `https://discovery.academyv2.mereka.io/login/`
   - `https://credentials.academyv2.mereka.io/login/`
   - `https://ecommerce.academyv2.mereka.io/login/`
2. Then open `/admin/`

If you get a 403 after SSO, you are missing `is_staff` in that service; run:
```bash
./scripts/infra/ensure-platform-admins.sh
```

## Verification (Recommended)

These checks confirm that SSO entrypoints exist across the ecosystem.

### Public redirect checks (from your machine)

```bash
# LMS OIDC entrypoint (should 302 to Authentik)
curl -sS -I https://academyv2.mereka.io/auth/login/oidc/ | sed -n '1,8p'

# Services that use LMS OAuth (should 302 to /login/edx-oauth2/)
for svc in discovery credentials ecommerce; do
  echo "== $svc =="
  curl -sS -I "https://${svc}.academyv2.mereka.io/login/" | sed -n '1,8p'
done
```

### Cluster permission verification (prod + dev)

```bash
./scripts/infra/ensure-platform-admins.sh --verify
```

## What Does Not Sync (By Default)

- Authentik groups do not automatically map to Open edX `is_staff`/`is_superuser`.
- Open edX permissions do not flow back into Authentik.

If you want true role sync, the typical approach is:
- Add a stable claim (e.g., `groups`) in Authentik for "platform-admin"
- Add a custom social-auth pipeline step in each service to grant permissions based on that claim

This is not implemented today; we use an idempotent enforcement script instead.
