# Domain Matrix
_Audience: Operators and contributors • Owner: Platform Team • Last verified: 2026-03-20 • Status: canonical-reference_

> Canonical tenant/domain source: `deploy/k8s/tenancy/tenant-registry.yaml`
> Derived shell defaults: `scripts/shared/config.sh`
> Static guard: `scripts/qa/verify-domain-url-invariants.sh`

This file is a reference projection of the current domain surface. Runtime statements in this file are limited to the DEV checks reverified on 2026-03-20 unless a row is explicitly marked derivative.

## Core MEREKA Service Domains

| Service | Production | Dev | Staging |
|---|---|---|---|
| LMS | `academyv2.mereka.io` | `academyv2.mereka.dev` | `staging.academyv2.mereka.io` |
| Studio | `studio.academyv2.mereka.io` | `studio.academyv2.mereka.dev` | `studio.staging.academyv2.mereka.io` |
| MFE | `apps.academyv2.mereka.io` | `apps.academyv2.mereka.dev` | `apps.staging.academyv2.mereka.io` |
| Auth | `auth0.mereka.io` | `auth0.mereka.dev` | `staging.auth0.mereka.io` |
| Preview | `preview.academyv2.mereka.io` | `preview.academyv2.mereka.dev` | `preview.staging.academyv2.mereka.io` |
| Discovery | `discovery.academyv2.mereka.io` | `discovery.academyv2.mereka.dev` | `discovery.staging.academyv2.mereka.io` |
| Notes | `notes.academyv2.mereka.io` | `notes.academyv2.mereka.dev` | `notes.staging.academyv2.mereka.io` |
| Credentials | `credentials.academyv2.mereka.io` | `credentials.academyv2.mereka.dev` | `credentials.staging.academyv2.mereka.io` |
| Forum | `forum.academyv2.mereka.io` | `forum.academyv2.mereka.dev` | `forum.staging.academyv2.mereka.io` |
| Enterprise Admin | `admin.academyv2.mereka.io` | `admin.academyv2.mereka.dev` | `admin.staging.academyv2.mereka.io` |
| Enterprise Learner | `learner.academyv2.mereka.io` | `learner.academyv2.mereka.dev` | `learner.staging.academyv2.mereka.io` |
| Legacy Ecommerce | `ecommerce.academyv2.mereka.io` | `ecommerce.academyv2.mereka.dev` | `ecommerce.staging.academyv2.mereka.io` |
| Payments Gateway (path-routed) | `academyv2.mereka.io/payments/*` | `academyv2.mereka.dev/payments/*` | `staging.academyv2.mereka.io/payments/*` |

## DEV Tenant-Pattern Domains

These are the tenant-pattern LMS/Studio/MFE triplets verified on the live DEV ingress and represented in the app-owned tenant registry.

| Tenant | LMS | Studio | MFE |
|---|---|---|---|
| MEREKA | `academyv2.mereka.dev` | `studio.academyv2.mereka.dev` | `apps.academyv2.mereka.dev` |
| Biji-Biji | `biji-biji.academyv2.mereka.dev` | `studio.biji-biji.academyv2.mereka.dev` | `apps.biji-biji.academyv2.mereka.dev` |
| SkillOurFuture | `skillourfuture.academyv2.mereka.dev` | `studio.skillourfuture.academyv2.mereka.dev` | `apps.skillourfuture.academyv2.mereka.dev` |

## DEV Runtime Snapshot

Verified against `argocd/mereka-lms-dev`, `kubectl` on namespace `mereka-lms-dev`, and direct HTTPS probes on 2026-03-20.

| Surface | Verified state | Classification |
|---|---|---|
| ArgoCD app | `mereka-lms-dev` is `Synced` / `Healthy` | VERIFIED FACT |
| Live ingress hosts | 15 app hosts exposed: 9 tenant-pattern + `admin`, `learner`, `preview`, `discovery`, `notes`, `credentials` | VERIFIED FACT |
| 9 tenant-pattern hosts | All 9 return `200` with HTML content | VERIFIED FACT |
| Enterprise portals | `admin.academyv2.mereka.dev` and `learner.academyv2.mereka.dev` return `200` HTML | VERIFIED FACT |
| Shared service hosts | `preview`, `discovery`, and `credentials` return `200` HTML | VERIFIED FACT |
| Notes host | `notes.academyv2.mereka.dev` returns `400` | VERIFIED FACT |
| Enterprise backends | `enterprise-access`, `enterprise-catalog`, `enterprise-subsidy`, and `license-manager` deployments are `1/1` available | VERIFIED FACT |

## Current Drift

- DEV tenant-pattern domains for Biji-Biji and SkillOurFuture were live on ingress but missing from `deploy/k8s/tenancy/tenant-registry.yaml` before the 2026-03-20 convergence batch.
- The live DEV namespace mounts staging-named and patched ConfigMaps (`caddy-config-staging`, `openedx-config-staging`, `openedx-settings-*-patched`, `enterprise-*-config-*`). Those names are runtime debt, not canonical truth.
- `notes.academyv2.mereka.dev` remains non-green with an HTTP `400` response and is not explained away in this reference.
- Production and staging runtime posture were not reverified in this DEV-only lane and should be treated as derivative unless rechecked.

## Ownership Map

| Surface | Owner | Canonical artifact |
|---|---|---|
| Tenant/domain registry | app repo | `deploy/k8s/tenancy/tenant-registry.yaml` |
| Derived shell defaults | app repo | `scripts/shared/config.sh` |
| Django Site and SiteConfiguration apply path | app repo | `scripts/tenants/seed-siteconfigs.sh` |
| Runtime/package authority split | app repo | `deploy/k8s/RUNTIME_AUTHORITY_MAP.md` |
| DNS, ingress controller realization, TLS certs, Argo applications | infra repo | environment overlays in `bbi-infrastructure` |

## What This File Is Not

- It is not the canonical authority for tenant/domain ownership. Use `deploy/k8s/tenancy/tenant-registry.yaml`.
- It is not a substitute for live runtime proof. Re-run DEV probes before claiming current runtime behavior.
- It does not certify staging or production readiness.
