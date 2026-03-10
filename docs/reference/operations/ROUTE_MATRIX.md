# Route Matrix — Mereka Academy Platform

_Audience: Platform Engineering + Ops • Last updated: 2026-02-20_
_Authoritative source: `deploy/k8s/base/apps/caddy/Caddyfile`_

Every public-facing surface and its routing contract. Use this as the ground-truth reference
for diagnosing 404s, 502s, auth loops, and branding issues.

---

## Production Surfaces

| Surface | Domain | Caddy target | Auth | Notes |
|---------|--------|-------------|------|-------|
| **LMS (main)** | `academyv2.mereka.io` | `lms:8000` | Open edX session + Authentik OIDC | Main learner site |
| **LMS (Biji-Biji)** | `academy.biji-biji.com` | `lms:8000` | Same pod, SiteConfiguration variant | Mereka multi-site |
| **LMS (Skill Our Future)** | `skillourfuture.academy.mereka.io` | `lms:8000` | Same pod, SiteConfiguration variant | Mereka multi-site |
| **Preview LMS** | `preview.academyv2.mereka.io` | `lms:8000` | Same LMS pod | Studio "Preview" feature (see below) |
| **Studio / CMS** | `studio.academyv2.mereka.io` | `cms:8000` | Studio OAuth2 → LMS → Authentik | Course authoring |
| **Studio (Biji-Biji)** | `studio.academy.biji-biji.com` | `cms:8000` | Same Studio pod | Single Studio, multi-tenant |
| **MFE apps** | `apps.academyv2.mereka.io` | `mfe:8002` | LMS session (cookie) | React MFEs: authn, learning, account, etc. |
| **MFE apps (Biji-Biji)** | `apps.academy.biji-biji.com` | `mfe:8002` | Same MFE pod | |
| **Admin portal** | `admin.academyv2.mereka.io` | `enterprise-admin-portal:8002` | LMS session + enterprise service APIs | Enterprise B2B admin UI |
| **Learner portal** | `learner.academyv2.mereka.io` | `enterprise-learner-portal:8002` | LMS session | Enterprise learner UI |
| **Discovery** | `discovery.academyv2.mereka.io` | `discovery:8000` | LMS session | Course catalog API |
| **Ecommerce** | `ecommerce.academyv2.mereka.io` | `ecommerce:8000` | LMS session | Legacy Oscar ecommerce |
| **Credentials** | `credentials.academyv2.mereka.io` | `credentials:8000` | LMS session | Certificate/badge issuance |
| **Notes** | `notes.academyv2.mereka.io` | `notes:8000` | LMS session | Learner notes service |
| **Admin login** | `academyv2.mereka.io/admin/login/` | `lms:8000` → Authentik OIDC | Redirects to `auth0.mereka.io` | Expected: 302 redirect |

---

## Preview LMS — Behavior Reference (bims)

> **What is `preview.academyv2.mereka.io`?**

`preview.academyv2.mereka.io` is the **Open edX Preview LMS**. It is not a separate service —
it is the same `lms:8000` pod, served under a different subdomain so Studio can render
course units in preview mode without affecting the production learner session.

**Used by**: Studio (CMS) → "Preview" button on a course unit.

**Routing**: The Caddy production block explicitly lists `preview.academyv2.mereka.io` as a
co-host of the main LMS block:

```
http://academyv2.mereka.io, http://preview.academyv2.mereka.io, ... {
    import proxy "lms:8000"
}
```

**Why `/dashboard` redirects to authn**: Preview domain uses the same auth flow as the
main LMS. `/dashboard` requires a logged-in learner session. The redirect to
`apps.academyv2.mereka.io/authn/login` is **correct behavior** — not a bug.

**Operator verification**:
```bash
# Should return 200 (LMS homepage — unauthenticated OK) or 302 (→ authn)
curl -sI https://preview.academyv2.mereka.io/ | head -3

# Should return 302 → authn (expected — requires login)
curl -sI https://preview.academyv2.mereka.io/dashboard | head -3
```

---

## Dashboard Redirect Behavior (Caddy override surfaces)

Some service domains redirect `/dashboard` to the MFE authn shell for UX consistency.
This is **intentional Caddy configuration**, not a bug.

| Domain | `/dashboard` behavior | Reason |
|--------|-----------------------|--------|
| `academyv2.mereka.io/dashboard` | LMS native (requires session) | Main site — learner dashboard |
| `preview.academyv2.mereka.io/dashboard` | 302 → authn (login required) | Preview domain — no persistent session expected |
| `ecommerce.academyv2.mereka.io/dashboard` | Rewritten → `/authn/login` on MFE | Ecommerce service has no learner dashboard |
| `credentials.academyv2.mereka.io/admin/login` | Rewritten → `/authn/login` on MFE | Credentials service uses platform authn |

---

## Favicon Rewrite Rule

Caddy rewrites `/favicon.ico` to `/theming/asset/images/favicon.ico` on LMS and Studio
blocks. This ensures the themed Mereka favicon is served regardless of the exact request path.

**Scope**: `academyv2.mereka.io`, `preview.academyv2.mereka.io`, `studio.academyv2.mereka.io`,
and their dev equivalents.

---

## Forum Routing (Forum v2 / Python)

Forum v2 is **integrated into the LMS process** (not a standalone service). There is no
separate forum Caddy block. Discussion APIs are served at:

| Path | Service | Notes |
|------|---------|-------|
| `/api/discussion/v2/courses/` | `lms:8000` | Forum API (401 = auth required, correct) |
| `/forum_form_discussion/` | `lms:8000` | Legacy inline forum |
| `/courses/.../discussion/` | `lms:8000` | Course discussion tabs |

**`/api/discussion/v1/`** — deprecated; use v2. Returns 404 (not a routing error).

---

## Enterprise Service API Routing (admin portal)

The enterprise admin portal Caddy block proxies API calls by path prefix to internal services:

| Path prefix | Target | Service |
|------------|--------|---------|
| `/api/enterprise-catalog/*` | `enterprise-catalog:8160` | Course catalog B2B |
| `/api/enterprise-access/*` | `enterprise-access:18270` | Access policies |
| `/api/license-manager/*` | `license-manager:18170` | License management |
| `/api/enterprise-subsidy/*` | `enterprise-subsidy:18280` | Financial transactions |
| `/api/mfe_config/v1*` | `lms:8000` | MFE config (proxied with Host header) |
| `/login_refresh*` | `lms:8000` | Session refresh |

---

## Multi-Tenancy Admin Surface (2rcf)

The `mereka_tenancy` Django app adds tenant management to the LMS Django admin:

| URL | Expected | Requires |
|-----|----------|---------|
| `academyv2.mereka.io/admin/mereka_tenancy/` | 302 → admin login (or 200 if logged in) | `mereka_tenancy` in `INSTALLED_APPS` |
| `academyv2.mereka.io/admin/mereka_tenancy/tenantconfig/` | 200 (staff user) | `mereka_tenancy` in `INSTALLED_APPS` + image rebuild |

**Current state**: Source patches correct (`apply-patches.sh` + `mereka_lms.py`).
Live pod returns 404 because current image was built before patches were applied.
**Fix**: `tutor images build openedx` → push → rolling restart (WhiteCliff lane).

**Source verification**:
```bash
./scripts/qa/verify-mereka-tenancy.sh
```

---

## Dev/Staging Equivalents

| Production domain | Dev equivalent | Cluster |
|------------------|---------------|---------|
| `academyv2.mereka.io` | `academyv2.mereka.dev` | RKE2 nonprod / Kind |
| `preview.academyv2.mereka.io` | `preview.academyv2.mereka.dev` | RKE2 nonprod / Kind |
| `studio.academyv2.mereka.io` | `studio.academyv2.mereka.dev` | RKE2 nonprod |
| `apps.academyv2.mereka.io` | `apps.academyv2.mereka.dev` | RKE2 nonprod |

---

## Footer Architecture — Canonical Extension Surfaces

Each application surface uses a different mechanism for footer rendering.
**Do not introduce ad-hoc patch scripts** — use the canonical surfaces below.

| Surface | Canonical source | Mechanism | Tenant behavior |
|---------|-----------------|-----------|-----------------|
| **LMS** (all domains) | `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | Mako template override via Open edX Comprehensive Theming | Single template; multi-site copy via `PLATFORM_NAME` + per-site `SiteConfiguration` |
| **Studio** (CMS) | `infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html` | Mako template override (canonical renderer) | White-label Studio footer; Mereka Academy + LMS link |
| **MFEs** (authn, learning, account…) | `infrastructure/tutor/plugins/mereka_lms.py` → `MerekaFooter` | Tutor MFE plugin + FPF `footer_slot` Replace | `SITE_VARIANTS` map keyed by hostname; 4 domains configured |
| **Enterprise portals** (admin, learner) | Open edX default footer (no `MerekaFooter` wiring) | N/A — enterprise portals unthemed | P4 backlog (WARN in `verify-footer-parity.sh`) |

**Update trigger**: LMS/CMS footer changes require `tutor images build openedx` + rolling restart.
MFE footer changes require `tutor images build mfe` + rolling restart.

**Source verification** (CI-safe, no live network required):
```bash
./scripts/qa/verify-footer-parity.sh --source-only
./scripts/qa/verify-studio-authoring-branding.sh prod --source-only
```

---

## Related Documents

- **Branding per surface**: `docs/guides/branding/BRANDING_OPERATING_MODEL.md`
- **Tenant footer contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
- **Caddy source**: `deploy/k8s/base/apps/caddy/Caddyfile`
- **Multi-tenancy plugin**: `infrastructure/tutor/plugins/multi-tenancy/`
- **Troubleshooting**: `docs/ops/runbooks/TROUBLESHOOTING.md`
