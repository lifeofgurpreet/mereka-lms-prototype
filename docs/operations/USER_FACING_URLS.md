# User-Facing URLs - Complete Registry
_Audience: Operations + Support + Multi-Tenancy Admins • Owner: Platform Team • Last updated: 2026-02-12_

## 🎯 Purpose

This document lists ALL user-facing URLs in the Mereka LMS platform, organized by tenant and service type. Use this for:
- Multi-tenancy verification
- Support ticket routing
- Smoke testing
- SSL certificate planning

---

## 📊 Summary

**Total User-Facing URLs**: 17 unique domains across 3 tenants

### Production (GKE - *.mereka.io)

| Tenant | LMS | Studio | MFE | Discovery | Other | Total |
|--------|-----|--------|-----|-----------|-------|-------|
| **Main (academyv2)** | 2 | 1 | 1 | 1 | 6 | **11** |
| **SkillOurFuture** | 1 | shared | shared | shared | shared | **1** |
| **Biji-Biji** | 1 | 1 | 1 | shared | shared | **3** |
| **Shared Services** | - | - | - | 1 | 6 | **7** |

**Infrastructure URLs**: 1 (Authentik SSO)
**Internal-Only APIs**: 2 (Notes, XQueue - not user-facing)

---

## 🌐 Production URLs (GKE - *.mereka.io)

### Main Tenant (academyv2.mereka.io)

**Primary Learner/Instructor URLs** (3):
1. **LMS** - https://academyv2.mereka.io
   - Purpose: Main learning platform, course catalog, dashboards
   - Admin: https://academyv2.mereka.io/admin
   - Key paths: `/`, `/dashboard`, `/courses`, `/account/settings`

2. **Preview LMS** - https://preview.academyv2.mereka.io
   - Purpose: Same LMS stack, alternate hostname for testing
   - Admin: https://preview.academyv2.mereka.io/admin
   - Use: Preview mode testing, A/B testing

3. **MFE Hub** - https://apps.academyv2.mereka.io
   - Purpose: Modern React-based learner experience
   - Key apps: `/authn/login`, `/learner-dashboard`, `/learning`, `/account`, `/profile`
   - Total MFE apps: 11 (login, account, profile, dashboard, learning, authoring, gradebook, discussions, communications, orders, payment, ORA grading)

**Instructor/Admin URLs** (1):
4. **Studio** - https://studio.academyv2.mereka.io
   - Purpose: Course authoring tool (CMS)
   - Key paths: `/`, `/home`, `/course/<course_id>`
   - Admin: https://studio.academyv2.mereka.io/admin

**Shared Services** (7 - multi-tenant):
5. **Discovery** - https://discovery.academyv2.mereka.io
   - Purpose: Course catalog search/browse API
   - Admin: https://discovery.academyv2.mereka.io/admin
   - Health: https://discovery.academyv2.mereka.io/health

6. **Ecommerce** - https://ecommerce.academyv2.mereka.io
   - Purpose: Course purchases, checkout, payment processing
   - Key paths: `/`, `/dashboard`, `/basket`, `/checkout`
   - Admin: https://ecommerce.academyv2.mereka.io/admin

7. **Credentials** - https://credentials.academyv2.mereka.io
   - Purpose: Digital certificates and badges
   - Admin: https://credentials.academyv2.mereka.io/admin
   - API: https://credentials.academyv2.mereka.io/api/v2
   - Health: https://credentials.academyv2.mereka.io/health

8. **Forum** - https://forum.academyv2.mereka.io
   - Purpose: Standalone forum access (also embedded in LMS courses)
   - Health: https://forum.academyv2.mereka.io/heartbeat
   - Note: Python-based (openedx-forum v0.3.8), integrated into LMS process

9. **Notes API** - https://notes.academyv2.mereka.io
   - Purpose: Student annotations/highlighting API
   - Type: API-only (no UI)
   - Internal use

10. **XQueue** - (Internal only - no public URL)
    - Purpose: External grader queue
    - Type: Internal service only

11. **Authentik SSO** - https://auth0.mereka.io/application/o/mereka-lms/
    - Purpose: Centralized OIDC authentication
    - Type: Platform-wide infrastructure
    - Note: Shared across multiple BBI projects

### SkillOurFuture Tenant (MCT Migration Target)

**Learner/Instructor URLs** (1):
12. **LMS** - https://skillourfuture.academy.mereka.io
    - Purpose: MCT migration target, skill development courses
    - Admin: https://skillourfuture.academy.mereka.io/admin
    - Stats (as of 2025-12-29): 68,565 users, 449,615 enrollments, 30 courses
    - Organization: "SKILLOURFUTURE" in Open edX

**Shared Services**:
- Studio: https://studio.academyv2.mereka.io (shared with main tenant)
- Discovery/Ecommerce/Credentials/Forum: Shared services (same URLs as main)
- MFE: Not separately deployed (uses main MFE hub with tenant branding)

### Biji-Biji Academy Tenant (Production Microsite)

**Learner/Instructor URLs** (3):
13. **LMS** - https://academy.biji-biji.com ✅ LIVE
    - Purpose: Branded learning platform for Biji-Biji community
    - Admin: https://academy.biji-biji.com/admin
    - Custom branding: Logo, colors, footer

14. **Studio** - https://studio.academy.biji-biji.com
    - Purpose: Course authoring for Biji-Biji courses
    - Separate from main Studio (tenant-isolated)

15. **MFE Hub** - https://apps.academy.biji-biji.com
    - Purpose: Branded MFE experience for Biji-Biji learners
    - Tenant-specific branding applied

**Shared Services**:
- Discovery/Ecommerce/Credentials/Forum: Shared services (same URLs as main)

---

## 🔧 Development URLs (VPS Kind - *.mereka.dev)

### Main Tenant (academyv2.mereka.dev)

**Learner/Instructor URLs** (4):
1. **LMS** - https://academyv2.mereka.dev
2. **Preview LMS** - https://preview.academyv2.mereka.dev
3. **Studio** - https://studio.academyv2.mereka.dev
4. **MFE Hub** - https://apps.academyv2.mereka.dev

**Shared Services** (6):
5. **Discovery** - https://discovery.academyv2.mereka.dev
6. **Ecommerce** - https://ecommerce.academyv2.mereka.dev
7. **Credentials** - https://credentials.academyv2.mereka.dev
8. **Forum** - https://forum.academyv2.mereka.dev
9. **Notes API** - https://notes.academyv2.mereka.dev
10. **XQueue** - (Internal only)

---

## 🏠 Local Development (*.localhost)

### Main Tenant (localhost)

**Learner/Instructor URLs** (4):
1. **LMS** - http://localhost
2. **Preview LMS** - http://preview.localhost
3. **Studio** - http://studio.localhost
4. **MFE Hub** - http://apps.localhost

**Shared Services** (5):
5. **Discovery** - http://discovery.localhost
6. **Ecommerce** - http://ecommerce.localhost
7. **Forum** - Embedded in LMS (no separate URL)
8. **Notes API** - http://notes.localhost
9. **XQueue** - http://xqueue.localhost

---

## 🎯 Multi-Tenancy URL Patterns

### Tenant Isolation Model

**Isolated per Tenant**:
- LMS domain (e.g., `academyv2.mereka.io` vs `academy.biji-biji.com`)
- Studio domain (main uses `studio.academyv2.mereka.io`, Biji-Biji uses `studio.academy.biji-biji.com`)
- MFE domain (main uses `apps.academyv2.mereka.io`, Biji-Biji uses `apps.academy.biji-biji.com`)
- Branding (logo, colors, footer, email templates)
- User base (no cross-tenant login)

**Shared Across Tenants**:
- Discovery service (single catalog, filtered by organization)
- Ecommerce service (single checkout, tenant-aware)
- Credentials service (single certificate issuer, tenant-branded)
- Forum service (single API, course-scoped)
- Authentik SSO (single OIDC provider, tenant-aware)

### Admin URLs per Tenant

**Main Tenant Admins**:
- LMS: https://academyv2.mereka.io/admin
- Studio: https://studio.academyv2.mereka.io/admin
- Discovery: https://discovery.academyv2.mereka.io/admin
- Ecommerce: https://ecommerce.academyv2.mereka.io/admin
- Credentials: https://credentials.academyv2.mereka.io/admin

**SkillOurFuture Admins**:
- LMS: https://skillourfuture.academy.mereka.io/admin
- Studio: https://studio.academyv2.mereka.io/admin (shared, uses organization filtering)

**Biji-Biji Admins**:
- LMS: https://academy.biji-biji.com/admin
- Studio: https://studio.academy.biji-biji.com/admin
- Shared services: Same URLs as main (organization filtering)

---

## 🔍 Verification

**Smoke Test All URLs**:
```bash
# Production (GKE)
./scripts/qa/public-health-check.sh prod

# Development (VPS Kind)
./scripts/qa/public-health-check.sh dev

# With branding + cert checks
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
```

**Multi-Tenancy Verification**:
```bash
# Verify tenant isolation
./scripts/qa/verify-tenant-isolation-patterns.sh

# Verify Studio isolation (CMS not on LMS domains)
./scripts/qa/verify-studio-isolation.sh

# Verify multi-site configuration
./scripts/qa/verify-multisite-config.sh
```

---

## 📋 URL Checklist for New Tenants

When adding a new tenant, ensure these URLs are configured:

- [ ] LMS domain (e.g., `tenant.mereka.io`)
- [ ] Studio domain (e.g., `studio.tenant.mereka.io`)
- [ ] MFE domain (e.g., `apps.tenant.mereka.io`)
- [ ] DNS records in Cloudflare
- [ ] TLS certificates (Let's Encrypt via cert-manager)
- [ ] Caddy routing rules
- [ ] Tutor multi-site configuration
- [ ] Tenant ConfigMap in K8s
- [ ] Organization in Open edX
- [ ] Branding assets (logo, colors, footer)
- [ ] Smoke tests passing

**Guide**: `docs/operations/runbooks/MULTI_TENANCY_RUNBOOK.md`

---

## 🚨 Important Notes

**Forum URL Behavior**:
- Forum is **embedded** in LMS courses (no separate login)
- Standalone URL (https://forum.academyv2.mereka.io) exists but rarely used
- Uses openedx-forum v0.3.8 (Python), integrated into LMS process
- No separate Ruby container (legacy forum removed)

**Preview Domain**:
- `preview.academyv2.mereka.io` is same LMS stack, different hostname
- Used for testing features before main domain
- NOT a separate environment (shares same database, courses, users)

**Admin Panel Access**:
- All `/admin` URLs require superuser privileges
- SSO-protected (redirects to Authentik, then back to admin panel)
- Platform admins: gurpreet@biji-biji.com, malasari@mereka.my
- Enforcement: `./scripts/infra/ensure-platform-admins.sh`

**Shared Service Multi-Tenancy**:
- Discovery/Ecommerce/Credentials use **organization filtering**
- Single instance serves all tenants
- Tenant isolation via Open edX organization model
- Not separate deployments

---

## 📚 Related Documentation

- **Access URLs**: `docs/operations/ACCESS_URLS.md` (detailed version with credentials)
- **Hostname Registry**: `docs/operations/OPENEDX_HOSTNAMES.md` (canonical list)
- **Multi-Tenancy**: `docs/operations/runbooks/MULTI_TENANCY_RUNBOOK.md`
- **Studio Isolation**: Security verified by `scripts/qa/verify-studio-isolation.sh`
- **Health Checks**: `scripts/qa/public-health-check.sh`

---

**Last Updated**: 2026-02-12
**Maintained By**: Platform Team
**Review Cadence**: Quarterly or when adding new tenants
