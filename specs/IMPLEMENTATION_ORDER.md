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
| ✅ | COMPLETED (all ACs verified) |
| 🟢 | LARGELY DONE (>60% ACs passing, infra exists) |
| 🟡 | IN PROGRESS (partial implementation, 20-60%) |
| 📝 | SPEC ONLY (spec written, <20% implemented) |
| ⏸️ | DEFERRED (not scheduled) |

## Overall Completion Estimate

| Tier | Completion | Notes |
|------|-----------|-------|
| Tier 0 — Foundations | ~70% | Repo structure ✅, secrets/tutor partially verified |
| Tier 1 — Core Infra | ~55% | K8s deployed, Atlas connected, domains configured |
| Tier 2 — Operational | ~40% | Prometheus/Loki running, CI partial, analytics not started |
| Tier 3 — Data & Migrations | ~35% | Forum done, DR scripts exist, Kajabi/video not started |
| Tier 4 — Enterprise Foundation | ~10% | Auth/SSO via Authentik exists; no multi-tenancy or enterprise services |
| Tier 5 — Enterprise Features | ~3% | Spec-only; ecommerce has basic Tutor plugin |
| Tier 6 — Deferred | ~2% | Spec-only |
| **Weighted Overall** | **~25-30%** | Most infra exists but enterprise features are aspirational |

---

## Tier 0 — Foundations

**Everything depends on these. Implement first.**

| Spec | Status | Completion | Blocks |
|------|--------|-----------|--------|
| `repository-structure_spec.md` | ✅ DONE | 12/12 ACs auto-verified | All other specs (defines where code lives) |
| `secrets-management_spec.md` | ✅ DONE | 51 secrets documented, enterprise secrets added | All specs consume secrets |
| `tutor-configuration_spec.md` | 🟢 LARGELY DONE | 10/10 ACs auto-verified | All specs that modify Tutor config |
| `cross-cutting-requirements_spec.md` | 🟢 LARGELY DONE | Referenced by all specs | All specs inherit cross-cutting requirements |

**Rationale**: Repository structure defines where everything
goes. Secrets management defines how every service accesses c
redentials. Tutor configuration defines how the platform is b
uilt and deployed. Cross-cutting requirements define the cont
ract every spec must honor.

---

## Tier 1 — Core Infrastructure

**Depends on**: Tier 0

| Spec | Status | Completion | Blocks | Notes |
|------|--------|-----------|--------|-------|
| `k8s-deployment_spec.md` | 🟡 IN PROGRESS | 3/32 ACs verified (manifests exist, verification scripts being added) | Tier 2+: all K8s services | GKE cluster running, manifests deployed |
| `mongodb-atlas-integration_spec.md` | 🟢 LARGELY DONE | 4/9 ACs auto, 2 manual | Forum, analytics, any MongoDB consumer | Atlas connected, SRV working |
| `multi-site-domains_spec.md` | 🟡 IN PROGRESS | 4/9 ACs auto | Branding, MFEs, enterprise portals | DNS/Caddy configured, some checks pending |
| `branding-system_spec.md` | 🟢 LARGELY DONE | 10/10 ACs auto-verified | Multi-tenancy (branding) | Themes, logos, MFE customization working |

**Rationale**: K8s deployment defines the runtime environment
. MongoDB Atlas provides document storage. Multi-site domains
enables per-tenant URLs. Branding system provides per-tenant
visual identity.

---

## Tier 2 — Operational Visibility

**Depends on**: Tier 0 + Tier 1

| Spec | Status | Completion | Blocks | Notes |
|------|--------|-----------|--------|-------|
| `observability-stack_spec.md` | 🟢 LARGELY DONE | 8/8 ACs auto-verified, enterprise monitoring added | SLO/SLA, all monitoring | Prometheus, Loki deployed; 3 enterprise ServiceMonitors + 12 alerts configured |
| `ci-cd-pipeline_spec.md` | 🟡 IN PROGRESS | 6/28 ACs verified | All automated deployments | GitHub Actions exist, ArgoCD not deployed |
| `analytics-pipeline_spec.md` | 📝 SPEC ONLY | 0/8 ACs verified | Enterprise reporting, privacy | Aspects/ClickHouse not deployed |
| `slo-sla-service-level-management_spec.md` | 🟢 LARGELY DONE | 19/23 ACs auto, 4 manual | Enterprise SLA contracts | SLO definitions exist, alert rules configured |

**Rationale**: Observability must be in place before deployin
g enterprise services (you can't operate what you can't obser
ve). CI/CD enables automated deployment. Analytics provides t
he data pipeline. SLO/SLA defines service level contracts.

---

## Tier 3 — Data & Migrations

**Depends on**: Tier 0 + Tier 1

| Spec | Status | Completion | Blocks | Notes |
|------|--------|-----------|--------|-------|
| `data-migrations-kajabi-mct_spec.md` | 🟡 IN PROGRESS | 2/38 ACs auto, 5 manual | — | Migration scripts exist, verification partial |
| `video-pipeline-delivery_spec.md` | 📝 SPEC ONLY | 0/25 ACs verified | Content libraries (video in courses) | S3/GCS, transcoding, CDN not started |
| `disaster-recovery-business-continuity_spec.md` | 🟢 LARGELY DONE | 16/22 ACs auto, 6 manual | Production readiness | Velero scripts exist, backup verification automated |
| `forum-service-migration_spec.md` | ✅ DONE | 0/22 ACs auto-verified (verification scripts needed) | — | Python forum v2 with Meilisearch operational |

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

| Order | Spec | Status | Completion | Blocks | Notes |
|-------|------|--------|-----------|--------|-------|
| 4.1 | `multi-tenancy-architecture_spec.md` | 📝 SPEC ONLY | 0/28 ACs verified | auth-sso, enterprise-microservices, all Tier 5 | EnterpriseCustomer model not implemented |
| 4.2 | `auth-sso-enterprise_spec.md` | 🟡 IN PROGRESS | 6/45 ACs auto | enterprise-microservices, all Tier 5 | Authentik SSO working; enterprise SAML/OIDC per-tenant not started |
| 4.3 | `enterprise-microservices_spec.md` | 🟢 LARGELY DONE | 7/8 services deployed, monitoring configured | All Tier 5 enterprise features | 7 deployments running (catalog, access, subsidy, admin-portal, learner-portal, 2 workers); license-manager deferred |

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

| Spec | Status | Completion | Monorepo Location | Notes |
|------|--------|-----------|-------------------|-------|
| `ecommerce-purchase-gateway_spec.md` | 📝 SPEC ONLY | 1/33 ACs auto | `services/purchase-gateway/` | FastAPI + PostgreSQL not started; basic Tutor ecommerce plugin exists |
| `email-notifications-pipeline_spec.md` | 📝 SPEC ONLY | 0/45 ACs verified | LMS config + K8s manifests | ACE + SES + FCM/APNs not started |
| `badges-credentials-enterprise_spec.md` | 📝 SPEC ONLY | 0/32 ACs verified | `services/badgr-server/` | Badgr Server not deployed |
| `content-libraries-v2_spec.md` | 📝 SPEC ONLY | 0/33 ACs verified | LMS config + K8s manifests | Content Libraries v2 + Blockstore not started |
| `advanced-assessment-xqueue_spec.md` | 📝 SPEC ONLY | 0/39 ACs verified | `services/xqueue-graders/` | XQueue exists in manifests; graders not built |
| `data-privacy-gdpr-compliance_spec.md` | 📝 SPEC ONLY | 0/30 ACs verified | `services/privacy-tools/` | GDPR/PDPA compliance (implement LAST in tier) |

⚠️ **data-privacy-gdpr-compliance** should be implemented las
t in this tier because it audits all the services above.

---

## Tier 6 — Deferred

**Not currently scheduled. Implement when business need arise
s.**

| Spec | Status | Completion | Notes |
|------|--------|-----------|-------|
| `mobile-apps-enterprise_spec.md` | 📝 SPEC ONLY | 0/37 ACs verified | CI + LMS config here; app source in upstream repos |
| `proctoring-integration_spec.md` | ⏸️ DEFERRED | 0/38 ACs | Deferred until 2027; depends on enterprise assessment needs |

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

5. **Proctoring is deferred**: `proctoring-integration_spec.md` is explicitly deferred until 2027 based on enterprise client demand assessment.

6. **Phantom scripts**: Many testmaps reference verification scripts that don't yet exist on disk. These are tracked as "Planned" in the coverage report. Creating these scripts is ongoing work.

7. **Spec compliance runner**: `python3 scripts/qa/spec-tools/run_spec_compliance.py --mode all` executes all automated testmap commands and reports actual pass/fail rates.

---

## Audit Trail

| Date | Event | Notes |
|------|-------|-------|
| 2026-02-10 | Initial creation | Tier structure and dependency graph |
| 2026-02-10 | Deep audit pass | Updated statuses with actual implementation percentages. 670 ACs across 26 specs; 222 with automated test files, 1004 planned (phantom scripts), 43 manual. Weighted overall: ~25-30% implemented. |
