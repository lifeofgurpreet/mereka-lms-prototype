# Admin Surfaces and Entrypoints

> Maps every admin-like surface in the Mereka LMS platform to its purpose,
> owning service, expected user role, and current maturity.
>
> **Goal**: Stop conceptual confusion between "enterprise admin", "platform admin",
> "Django admin", and "admin console".

## Surface Inventory

### 1. LMS Django Admin

| Property | Value |
|----------|-------|
| **URL** | `https://academyv2.mereka.io/admin/` |
| **What it is** | Traditional Django admin interface |
| **What it does** | User management, course enrollment, permission assignment, waffle flags, OAuth2 applications, site configuration |
| **What it is NOT** | A modern admin dashboard. Not tenant-scoped. Not for enterprise catalog management. |
| **Owning service** | LMS pod (Django) |
| **Expected user role** | `is_staff=True` or `is_superuser=True` |
| **Authentication** | Django session (SSO via Authentik OIDC) |
| **Current maturity** | Mature, production. Used daily for platform operations. |
| **Dependencies** | LMS database (MySQL), Django auth |
| **Tenant scoping** | None — shows all data across all tenants |

### 2. Studio (CMS)

| Property | Value |
|----------|-------|
| **URL** | `https://studio.academyv2.mereka.io/` |
| **What it is** | Course authoring and content management |
| **What it does** | Create courses, edit content blocks, manage course teams, configure grading, set enrollment dates |
| **What it is NOT** | An enterprise admin tool. Not for user management or catalog management. |
| **Owning service** | CMS pod (Django) |
| **Expected user role** | Course creators (`CourseCreator` model), course staff/instructors (per-course) |
| **Authentication** | Django session (SSO via Authentik OIDC, with SSO bypass middleware per ADR-013) |
| **Current maturity** | Mature, production |
| **Dependencies** | CMS database (MySQL), MongoDB Atlas (modulestore) |
| **Tenant scoping** | Platform-shared by design (ADR-024). All course creators see all courses regardless of tenant. |

### 3. Admin Console MFE

| Property | Value |
|----------|-------|
| **URL** | `https://apps.academyv2.mereka.io/admin-console/` |
| **What it is** | Modern React MFE for platform RBAC and content library management |
| **What it does** | Assign/revoke org roles (admin, staff, instructor, data researcher), manage Blockstore content libraries v2, create/manage organizations |
| **What it is NOT** | An enterprise admin portal. Not for catalog/license/subsidy management. |
| **Owning service** | MFE pod (React, sub-path `/admin-console/`) |
| **Expected user role** | `is_staff=True` or `is_superuser=True` or `org_admin` role |
| **Authentication** | JWT via LMS OAuth2 |
| **Current maturity** | Shipped with Ulmo (Tutor v21). Functional but lightly used in this deployment. |
| **Dependencies** | LMS API for role management, Blockstore for content libraries |
| **Tenant scoping** | Org-scoped roles, but UI shows all orgs the user has access to |

### 4. Enterprise Admin Portal MFE

| Property | Value |
|----------|-------|
| **URL** | `https://admin.academyv2.mereka.io/` |
| **What it is** | B2B enterprise administration dashboard for a single enterprise customer |
| **What it does** | Manage enterprise course catalog, browse available courses, manage access policies, allocate/revoke licenses, configure subsidies, view enrollment analytics |
| **What it is NOT** | A platform admin tool. Not for managing users across the platform. Not for creating courses. Not for RBAC. Cannot manage multiple enterprise customers simultaneously. |
| **Owning service** | enterprise-admin-portal pod (React/Caddy) |
| **Expected user role** | Enterprise admin (linked via `EnterpriseCustomerUser` with admin role) |
| **Authentication** | JWT via LMS OAuth2 → enterprise customer resolution via slug in URL path |
| **Current maturity** | **Deployed but non-functional**: runtime rendering being fixed by active lane; enterprise data (catalogs, user links) missing |
| **Dependencies** | enterprise-catalog:8160, enterprise-access:18270, license-manager:18170, enterprise-subsidy:18280, LMS (auth) |
| **Tenant scoping** | Fully scoped to one `EnterpriseCustomer.uuid`. URL path includes `/:enterpriseSlug/`. |

**Backend API routing** (via main Caddy):
```
admin.* → /api/enterprise-catalog/* → enterprise-catalog:8160
admin.* → /api/enterprise-access/*  → enterprise-access:18270
admin.* → /api/license-manager/*    → license-manager:18170
admin.* → /api/enterprise-subsidy/* → enterprise-subsidy:18280
admin.* → /api/mfe_config/*        → lms:8000
admin.* → /*                       → enterprise-admin-portal:8002
```

### 5. Enterprise Learner Portal MFE

| Property | Value |
|----------|-------|
| **URL** | `https://learner.academyv2.mereka.io/` |
| **What it is** | Enterprise learner dashboard showing assigned/available courses |
| **What it does** | Browse enterprise catalog, enroll via subsidies/licenses, view assigned courses, track progress |
| **What it is NOT** | An admin surface. Learners cannot manage catalogs, users, or policies. |
| **Owning service** | enterprise-learner-portal pod (React/Caddy) |
| **Expected user role** | Enterprise learner (linked via `EnterpriseCustomerUser`) |
| **Authentication** | JWT via LMS OAuth2 → enterprise customer resolution via slug |
| **Current maturity** | **Deployed but non-functional**: same blockers as admin portal |
| **Dependencies** | Same enterprise services as admin portal, plus LMS enrollment APIs |
| **Tenant scoping** | Fully scoped to one `EnterpriseCustomer.uuid` |

### 6. Purchase Gateway Admin API

| Property | Value |
|----------|-------|
| **URL** | `https://academyv2.mereka.io/payments/api/v1/admin/*` (API only, no UI) |
| **What it is** | REST API for payment/ecommerce administration |
| **What it does** | Manage offerings, entitlements, bulk assignment, orders, refunds |
| **What it is NOT** | A web UI. Not a Django admin. Requires programmatic access. |
| **Owning service** | Purchase Gateway pod (FastAPI) |
| **Expected user role** | API key holder (`MEREKA_ENTERPRISE_ADMIN_TOKEN`) |
| **Authentication** | API key in header |
| **Current maturity** | Activated (ENABLE_GATEWAY_FULFILLMENT=true). Replacing legacy Oscar ecommerce. |
| **Tenant scoping** | Not tenant-scoped (platform-wide) |

### 7. Satellite Service Django Admins

| Service | URL | Purpose | Notes |
|---------|-----|---------|-------|
| Discovery | `discovery.academyv2.mereka.io/admin/` | Catalog configuration | Separate DB, own `is_staff` |
| Credentials | `credentials.academyv2.mereka.io/admin/` | Certificate management | Separate DB, own `is_staff` |
| Ecommerce | `ecommerce.academyv2.mereka.io/admin/` | Legacy Oscar admin | **Deprecated** — being replaced by Purchase Gateway |

All satellite admins redirect `/admin/login` to the shared MFE authn flow.

### 8. Authentik Admin (External)

| Property | Value |
|----------|-------|
| **URL** | `https://auth0.mereka.io/` (Authentik web UI) |
| **What it is** | SSO identity provider administration |
| **What it does** | Manage OIDC/SAML providers, user federation, authentication flows, application registrations |
| **What it is NOT** | Part of the Open edX stack. Not deployed in K8s. |
| **Access** | Restricted to infrastructure operator only |
| **Current maturity** | Production, managed separately |

## Conceptual Map: "Admin" Disambiguation

```
┌─────────────────────────────────────────────────────────────┐
│              PLATFORM OPERATOR SURFACES                      │
│                                                              │
│  LMS Django Admin (/admin/)                                  │
│    → User accounts, permissions, waffle flags, sites         │
│    → Platform-wide, not tenant-scoped                        │
│                                                              │
│  Admin Console MFE (/admin-console/)                         │
│    → RBAC roles, org management, content libraries           │
│    → Platform-wide with org-level scoping                    │
│                                                              │
│  Studio (CMS)                                                │
│    → Course authoring                                        │
│    → Platform-shared (all course creators see all courses)   │
│                                                              │
│  Satellite Django Admins (discovery, credentials)            │
│    → Service-specific configuration                          │
│                                                              │
│  Authentik (external)                                        │
│    → SSO/identity provider configuration                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              ENTERPRISE / TENANT SURFACES                    │
│                                                              │
│  Enterprise Admin Portal (admin.*)                           │
│    → Catalog browsing, license management, subsidy config    │
│    → Scoped to ONE EnterpriseCustomer                        │
│    → NOT platform admin. Cannot manage users, courses, RBAC  │
│                                                              │
│  Enterprise Learner Portal (learner.*)                       │
│    → Course browsing, enrollment via enterprise subsidy      │
│    → Scoped to ONE EnterpriseCustomer                        │
│    → NOT an admin surface at all                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              API-ONLY ADMIN                                  │
│                                                              │
│  Purchase Gateway Admin API                                  │
│    → Payment/offering management                             │
│    → API key auth, no web UI                                 │
└─────────────────────────────────────────────────────────────┘
```

## What is out of scope by design

| Surface concept | Status | Why |
|----------------|--------|-----|
| **Multi-tenant admin dashboard** (manage all tenants at once) | Does not exist | Enterprise admin portal is per-customer by design. Multi-tenant orchestration is an operator function via LMS Django admin + scripts. |
| **Unified admin portal** (merge Django admin + enterprise admin) | Not planned | These are fundamentally different concerns. Platform admin manages the shared stack. Enterprise admin manages one customer's B2B features. |
| **Self-service tenant provisioning UI** | Not planned | Tenant provisioning is an operator workflow via `provision_tenant.py` / `provision-all-tenants.sh`. |
| **Course library in enterprise admin** | Conceptually wrong | Course creation belongs in Studio. Enterprise admin only curates courses into catalogs — it does not create them. |

## Where the "course library" belongs

The term "course library" is ambiguous in Open edX:

1. **Content Libraries v2** (Blockstore-backed): Managed via **Admin Console MFE** (`/admin-console/`). These are reusable content blocks, not full courses.
2. **Course Catalog** (enterprise): Managed via **Enterprise Admin Portal** (`admin.*`). This is a curated set of courses available to an enterprise customer, defined by `CatalogQuery` filters.
3. **Course Authoring**: Done in **Studio** (`studio.*`). This is where courses are created and edited.

An operator confused about "where is the course library" should:
- Go to Studio to **create** courses
- Go to Admin Console to manage **content libraries** (reusable blocks)
- Go to Enterprise Admin Portal to curate courses into **enterprise catalogs**

## How an operator should think about surfaces

| Task | Surface | Why |
|------|---------|-----|
| Create a user account | LMS Django Admin | Platform-wide user management |
| Make someone a course creator | Admin Console MFE or LMS Django Admin | RBAC role assignment |
| Create a course | Studio | Course authoring |
| Add a course to an enterprise catalog | Enterprise Admin Portal | Enterprise catalog curation |
| Assign a license to a learner | Enterprise Admin Portal | License management |
| Create a new tenant | `provision_tenant.py` (CLI) | Operator workflow, not self-service |
| Configure SSO for a tenant | Authentik + LMS Django Admin | OIDC/SAML provider setup |
| Manage payment offerings | Purchase Gateway Admin API | API-only (programmatic) |
| View enterprise enrollment analytics | Enterprise Admin Portal | Per-customer analytics |
