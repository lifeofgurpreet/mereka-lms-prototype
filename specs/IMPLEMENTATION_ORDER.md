# Implementation Dependency Graph

> This document defines the implementation ordering for all M
ereka Academy specs.
> Each tier must be substantially complete before dependent t
iers begin.
> Within a tier, specs can be implemented in parallel unless
noted otherwise.

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✅ | APPROVED / COMPLETED |
| 📝 | DRAFT (ready for implementation after review) |
| ⏸️ | DEFERRED (not scheduled) |

---

## Tier 0 — Foundations

**Everything depends on these. Implement first.**

| Spec | Status | Blocks |
|------|--------|--------|
| `repository-structure_spec.md` | ✅ APPROVED | All other
cs (defines where code lives) |
| `secrets-management_spec.md` | 📝 IN_REVIEW | All specs
consume secrets (all of them) |
| `tutor-configuration_spec.md` | 📝 DRAFT | All specs that
dify Tutor config or deploy services |
| `cross-cutting-requirements_spec.md` | 📝 IN_REVIEW | All
ecs inherit cross-cutting requirements |

**Rationale**: Repository structure defines where everything
goes. Secrets management defines how every service accesses c
redentials. Tutor configuration defines how the platform is b
uilt and deployed. Cross-cutting requirements define the cont
ract every spec must honor.

---

## Tier 1 — Core Infrastructure

**Depends on**: Tier 0

| Spec | Status | Blocks | Notes |
|------|--------|--------|-------|
| `k8s-deployment_spec.md` | 📝 DRAFT | Tier 2+: all K8s-
yed services | GKE cluster, namespaces, networking |
| `mongodb-atlas-integration_spec.md` | 📝 DRAFT | Forum,
ytics, any MongoDB consumer | Atlas connection, monitoring |
| `multi-site-domains_spec.md` | 📝 DRAFT | Branding, MFEs,
terprise portals | DNS, Caddy, SSL certificates |
| `branding-system_spec.md` | 📝 DRAFT | Multi-tenancy
branding) | Themes, logos, MFE customization |

**Rationale**: K8s deployment defines the runtime environment
. MongoDB Atlas provides document storage. Multi-site domains
enables per-tenant URLs. Branding system provides per-tenant
visual identity.

---

## Tier 2 — Operational Visibility

**Depends on**: Tier 0 + Tier 1

| Spec | Status | Blocks | Notes |
|------|--------|--------|-------|
| `observability-stack_spec.md` | 📝 DRAFT | SLO/SLA
t, all monitoring | Prometheus, Loki, Tempo, Grafana |
| `ci-cd-pipeline_spec.md` | 📝 DRAFT | All automated
nts | GitHub Actions, ArgoCD |
| `analytics-pipeline_spec.md` | 📝 DRAFT | Enterprise
ng, privacy compliance | Aspects/ClickHouse |
| `slo-sla-service-level-management_spec.md` | 📝 DRAFT |
rprise client SLA contracts | Depends on observability |

**Rationale**: Observability must be in place before deployin
g enterprise services (you can't operate what you can't obser
ve). CI/CD enables automated deployment. Analytics provides t
he data pipeline. SLO/SLA defines service level contracts.

---

## Tier 3 — Data & Migrations

**Depends on**: Tier 0 + Tier 1

| Spec | Status | Blocks | Notes |
|------|--------|--------|-------|
| `data-migrations-kajabi-mct_spec.md` | 📝 DRAFT | — | Can
n independently once infra is ready |
| `video-pipeline-delivery_spec.md` | 📝 DRAFT | Content
ries (video in courses) | S3/GCS, transcoding, CDN |
| `disaster-recovery-business-continuity_spec.md` | 📝 DRAFT
Production readiness for enterprise | Velero, Atlas backups,
RTO/RPO |
| `forum-service-migration_spec.md` | ✅ COMPLETED | — |
n forum v2 with Meilisearch (done) |

**Rationale**: Data migrations bring legacy content into the
platform. Video pipeline handles media delivery. DR/BC ensure
s production resilience. Forum migration is already completed
.

---

## Tier 4 — Enterprise Foundation (SEQUENTIAL)

**Depends on**: Tier 0 + Tier 1 + Tier 2 (observability requi
red)

⚠️ **These must be implemented in order** — each builds on th
e previous.

```
multi-tenancy-architecture → auth-sso-enterprise → enterprise
-microservices
```

| Order | Spec | Status | Blocks | Notes |
|-------|------|--------|--------|-------|
| 4.1 | `multi-tenancy-architecture_spec.md` | 📝 DRAFT |
-sso, enterprise-microservices, all Tier 5 | EnterpriseCustom
er model, tenant isolation |
| 4.2 | `auth-sso-enterprise_spec.md` | 📝 DRAFT
microservices, all Tier 5 | SAML/OIDC, per-tenant IdP |
| 4.3 | `enterprise-microservices_spec.md` | 📝 DRAFT | All
er 5 enterprise features | 5 enterprise Django services |

**Rationale**: Multi-tenancy defines the tenant model that ev
erything else uses. Auth/SSO provides the authentication laye
r enterprise services require. Enterprise microservices (cata
log, license-manager, etc.) provide the APIs that Tier 5 feat
ures consume.

---

## Tier 5 — Enterprise Features (PARALLELIZABLE)

**Depends on**: Tier 4 complete

All specs in this tier can be implemented in parallel after T
ier 4 is done.

| Spec | Status | Monorepo Location | Notes |
|------|--------|-------------------|-------|
| `ecommerce-purchase-gateway_spec.md` | 📝 DRAFT |
purchase-gateway/` | FastAPI + PostgreSQL + Redis worker |
| `email-notifications-pipeline_spec.md` | 📝 DRAFT | LMS
ig + K8s manifests | ACE + SES + FCM/APNs |
| `badges-credentials-enterprise_spec.md` | 📝 DRAFT |
es/badgr-server/` (or LMS config) | Badgr Server + credential
s service |
| `content-libraries-v2_spec.md` | 📝 DRAFT | LMS config +
manifests | Content Libraries v2 + Blockstore |
| `advanced-assessment-xqueue_spec.md` | 📝 DRAFT |
xqueue-graders/` | XQueue + containerized graders |
| `data-privacy-gdpr-compliance_spec.md` | 📝 DRAFT |
s/privacy-tools/` | GDPR/PDPA compliance (implement LAST in t
ier) |

⚠️ **data-privacy-gdpr-compliance** should be implemented las
t in this tier because it audits all the services above.

---

## Tier 6 — Deferred

**Not currently scheduled. Implement when business need arise
s.**

| Spec | Status | Notes |
|------|--------|-------|
| `mobile-apps-enterprise_spec.md` | 📝 DRAFT | CI + LMS
g here; app source in upstream repos |
| `proctoring-integration_spec.md` | ⏸️ DEFERRED | Deferred u
ntil 2027; depends on enterprise assessment needs |

---

## Dependency Graph (Visual)

```
Tier 0: repository-structure ──┐
        secrets-management ────┤
        tutor-configuration ───┤
        cross-cutting-reqs ────┘
                │
        ┌───────┴───────┐
        ▼               ▼
Tier 1: k8s-deployment    Tier 1: mongodb-atlas
        multi-site-domains        branding-system
                │
        ┌───────┴───────┐
        ▼               ▼
Tier 2: observability     Tier 3: data-migrations
        ci-cd-pipeline           video-pipeline
        analytics-pipeline       disaster-recovery
        slo-sla-management       forum (DONE)
                │
                ▼
Tier 4: multi-tenancy ──→ auth-sso ──→ enterprise-microservic
es
                                              │
                ┌─────────┬───────┬───────┬───┴───┬──────────
┐
                ▼         ▼       ▼       ▼       ▼
▼
Tier 5: purchase    email   badges  content  xqueue   privacy
        gateway    notif.  creds   libs-v2  graders  (LAST)

Tier 6: mobile-apps (deferred)
        proctoring (deferred 2027)
```

---

## Per-Spec Dependency Summary

| Spec | Depends On | Blocks |
|------|-----------|--------|
| repository-structure | — | Everything |
| secrets-management | repository-structure | Everything |
| tutor-configuration | repository-structure | Everything |
| cross-cutting-requirements | — | Everything (by reference)
|
| k8s-deployment | Tier 0 | Tiers 2-5 |
| mongodb-atlas-integration | Tier 0 | forum, analytics |
| multi-site-domains | Tier 0 | branding, multi-tenancy |
| branding-system | Tier 0, multi-site-domains | multi-tenanc
y |
| observability-stack | Tier 0, Tier 1 | slo-sla, Tier 4+ |
| ci-cd-pipeline | Tier 0, Tier 1 | All automated deployments
|
| analytics-pipeline | Tier 0, Tier 1 | slo-sla, privacy |
| slo-sla-service-level-management | observability-stack | En
terprise SLA contracts |
| data-migrations-kajabi-mct | Tier 0, Tier 1 | — |
| video-pipeline-delivery | Tier 0, Tier 1 | content-librarie
s-v2 |
| disaster-recovery-business-continuity | Tier 0, Tier 1 | Pr
oduction readiness |
| forum-service-migration | — | — (COMPLETED) |
| multi-tenancy-architecture | Tier 0, Tier 1, Tier 2 | auth-
sso, enterprise-microservices, all Tier 5 |
| auth-sso-enterprise | multi-tenancy | enterprise-microservi
ces, all Tier 5 |
| enterprise-microservices | multi-tenancy, auth-sso | All Ti
er 5 |
| ecommerce-purchase-gateway | Tier 4 | privacy |
| email-notifications-pipeline | Tier 4 | privacy |
| badges-credentials-enterprise | Tier 4 | privacy |
| content-libraries-v2 | Tier 4, video-pipeline | privacy |
| advanced-assessment-xqueue | Tier 4 | privacy |
| data-privacy-gdpr-compliance | Tier 4, all Tier 5 peers | —
(audits everything) |
| mobile-apps-enterprise | Tier 4 | — (DEFERRED) |
| proctoring-integration | Tier 4, advanced-assessment | — (D
EFERRED 2027) |

---

## Implementation Notes

1. **Monorepo structure**: All code lives in this repository
(`mereka-lms`). Custom services go under `services/`. Mobile
app source is the only exception (upstream repos).

2. **Existing infrastructure**: Many Tier 0 and Tier 1 specs
describe infrastructure that already partially exists. Implem
entation means formalizing, documenting, and adding automated
verification — not building from scratch.

3. **Forum is done**: `forum-service-migration_spec.md` is CO
MPLETED. Python forum v2 with Meilisearch is operational.

4. **Privacy is last**: `data-privacy-gdpr-compliance_spec.md
` should be the last Tier 5 spec implemented because it audit
s every other service's PII handling.

5. **Proctoring is deferred**: `proctoring-integration_spec.m
d` is explicitly deferred until 2027 based on enterprise clie
nt demand assessment.
