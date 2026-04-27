# Compiled Design Documentation: Mereka LMS Prototype

**Compiled by**: Miranda Prima Alifiana
**Date**: 2026-04-27
**Source repo**: `Biji-Biji-Initiative/mereka-lms-prototype`
**Purpose**: Compiled from Faiz's Claude design documentation for Gurpreet's review and agent execution.

---

## What This Is

This repository contains Faiz's comprehensive design documentation for the Mereka Academy LMS platform, generated and structured using Claude. It covers the full architecture of a multi-tenant Open edX deployment including authentication, SSO, platform middleware, Kubernetes deployment, branding, ecommerce, and more.

The documentation is organized across **41 normative specifications** with **1,158 acceptance criteria**, supported by architecture decision records (ADRs), implementation plans, operational runbooks, and machine-readable agent knowledge artifacts.

---

## Compiled Documents

| Document | Description |
|----------|-------------|
| [01-platform-changes.md](01-platform-changes.md) | All platform changes mapped from specs and ADRs, organized by domain |
| [02-mfa-requirements.md](02-mfa-requirements.md) | MFA requirements, current state, and implementation steps |
| [03-target-files-mapping.md](03-target-files-mapping.md) | Cross-reference of requirements to target files and implementation steps |
| [04-gap-analysis.md](04-gap-analysis.md) | **Gap analysis**: design spec vs production repo (`mereka-lms`) -- what's built vs what's missing |

---

## Source Documentation Map

### Specifications (`specs/`)

The core design lives in normative spec files. Key specs by domain:

**Authentication & Identity**
- `specs/auth-sso-enterprise_spec.md` -- Enterprise SSO, SAML/OIDC federation, MFA, session management
- `specs/auth-sso-enterprise_plan.md` (in `specs/plans/`) -- Phased implementation plan (10-14 weeks)

**Platform Infrastructure**
- `specs/platform-middleware-custom-apps_spec.md` -- Custom middleware stack and Django apps
- `specs/multi-tenancy-architecture_spec.md` -- Tenant model, isolation boundaries, provisioning
- `specs/k8s-deployment_spec.md` -- Kubernetes deployment contract (17+ workloads)
- `specs/tutor-configuration_spec.md` -- Tutor build pipeline and configuration lifecycle
- `specs/multi-site-domains_spec.md` -- Multi-domain routing

**Frontend & Branding**
- `specs/mfe-plugin-slots_spec.md` -- Frontend Plugin Framework slot activation roadmap
- `specs/studio-customization_spec.md` -- Studio branding and authoring experience
- `specs/branding-system_spec.md` -- Design tokens, logos, typography, themes
- `specs/design-tokens-system_spec.md` -- Token generation pipeline
- `specs/oep48-brand-package_spec.md` -- Open edX brand package integration

**Enterprise Services**
- `specs/enterprise-microservices_spec.md` -- 5 enterprise services (catalog, license, access, subsidy, channels)
- `specs/ecommerce-purchase-gateway_spec.md` -- Stripe-based purchase gateway replacing Oscar

**Operations & Security**
- `specs/secrets-management_spec.md` -- Infisical/GCP Secret Manager pipeline
- `specs/ci-cd-pipeline_spec.md` -- Build, test, promotion pipeline
- `specs/observability-stack_spec.md` -- Prometheus, Loki, Tempo
- `specs/disaster-recovery-business-continuity_spec.md` -- DR and backup strategy
- `specs/data-privacy-gdpr-compliance_spec.md` -- GDPR/PII compliance (93 ACs)

**Data & Content**
- `specs/content-libraries-v2_spec.md` -- Content libraries
- `specs/video-pipeline-delivery_spec.md` -- Video delivery
- `specs/data-migrations-kajabi-mct_spec.md` -- Data migration from legacy systems
- `specs/analytics-pipeline_spec.md` -- Aspects/ClickHouse/Superset

### Architecture Decision Records (`docs/adr/`)

14 active ADRs + 12 proposed RFCs covering identity, session management, settings authority, deployment contracts, and more. Key ones for this compilation:

- **ADR-013**: Studio SSO Bypass Middleware (temporary)
- **ADR-022**: Session Cookie SameSite Policy (temporary)
- **ADR-024**: True Multi-Tenancy for Subsites
- **ADR-029**: Identity, Session, Domain-Boundary Strategy
- **ADR-041** (RFC): Authorization and Role-Boundary Model
- **ADR-042** (RFC): Django production.py Writer Authority

### Operational Documentation

- `docs/policies/operations/AUTH_HARDENING_SPEC.md` -- Current auth hardening policy
- `docs/reference/operations/AUTH_AND_PERMISSIONS.md` -- Auth operational reference
- `docs/ops/runbooks/AUTH_SSO_RUNBOOK.md` -- SSO troubleshooting runbook

### Agent Knowledge Artifacts (`generated/`)

Machine-readable artifacts for agent consumption:
- `generated/knowledge/agent-entrypoints.json` -- 11 domain entrypoints
- `generated/knowledge/skill-index.json` -- Task type registry
- `generated/knowledge/change-manifest.json` -- Change classification rules
- `generated/knowledge/task-bundles/` -- 10 operational task bundles
- `generated/platform/team-topology-reference.json` -- Tenant/service topology

---

## Technology Stack

- **LMS Platform**: Open edX (Tutor 21.0.0 / Ulmo)
- **Identity Provider**: Authentik (platform-level OIDC)
- **Orchestration**: Kubernetes (GKE), ArgoCD
- **Reverse Proxy**: Caddy (behind Cloudflare)
- **Secrets**: Infisical -> GCP Secret Manager -> ExternalSecrets
- **Monitoring**: Prometheus, Grafana, Loki
- **Database**: MySQL (LMS), MongoDB Atlas (modulestore), Redis
- **CI/CD**: GitHub Actions
- **Enterprise Services**: catalog, license-manager, access, subsidy, integrated-channels

## Active Tenants

| Tenant | LMS Domain | MFE Domain |
|--------|-----------|------------|
| Mereka Academy | `academyv2.mereka.io` | `apps.academyv2.mereka.io` |
| Biji-Biji Initiative | `academy.biji-biji.com` | `apps.academy.biji-biji.com` |
| SkillOurFuture | `skillourfuture.academy.mereka.io` | (shared) |

## Platform Admins

- `gurpreet@biji-biji.com` (Platform + Authentik admin)
- `malasari@mereka.my` (Platform admin)
