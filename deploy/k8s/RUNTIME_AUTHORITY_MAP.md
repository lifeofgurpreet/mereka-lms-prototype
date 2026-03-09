# Runtime Authority Map — Mereka LMS

> Machine-readable version: [`contract.json`](contract.json) | Deployment contract: [`CONTRACTS.md`](CONTRACTS.md)

This document classifies every surface under `deploy/k8s/` by its runtime authority class.
It defines who owns each surface, what mutations are permitted, and what is frozen or deprecated.

---

## Classification Taxonomy

| Class | Meaning |
|-------|---------|
| `authoritative-package` | Canonical K8s resource definitions. GitOps consumes as-is. This repo is the single source of truth. |
| `authoritative-runtime` | Actively defines runtime behavior (Python Django settings, Caddy routing logic, etc.). Must not be overridden by GitOps. |
| `local-only` | Local Kind/Minikube development only. Never deployed to RKE2, staging, or production. |
| `deprecated` | Superseded by bbi-infrastructure overlays. Retained for reference and history only. File counts are frozen. |
| `platform-debt` | Cluster-scoped resources that should not live in the app repo. Tracked for migration to platform-control-plane. File counts are frozen. |
| `vendor-reference` | Upstream Tutor/Open edX defaults. Not deployed directly; used as a base for customization. |

---

## Core Principle

**The app repo owns the package and runtime behavior. The GitOps repo owns environment realization.**

```
deploy/k8s/base/        → owned by this repo (authoritative-package + authoritative-runtime)
deploy/k8s/overlays/local/ → owned by this repo (local-only)

bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/
                        → owned by bbi-infrastructure (environment realization)
```

ArgoCD deploys Mereka LMS from `bbi-infrastructure`, NOT from this repo's overlay directories.
The non-local overlays here (`rke2-nonprod/`, `staging/`, `production/`) are **deprecated** —
they are not consumed by ArgoCD and must not be modified.

---

## Conflict Resolution Rules

1. If `base/` and an overlay disagree on a Python setting: **base wins**. The setting must be in `production.py`.
2. If `base/` and an overlay disagree on Caddy routing: **base wins**. Overlays may patch hosts/TLS only.
3. If `contract.json` and a deprecated overlay disagree: **contract.json wins**. The overlay is frozen.
4. If `bbi-infrastructure` and `base/` disagree on an image: **bbi-infrastructure wins** (image pinning is a GitOps override).
5. If a new cluster-scoped resource is needed: **it goes to platform-control-plane**, not here.

---

## Base Package Classification

### `deploy/k8s/base/` — `authoritative-package`

The complete, buildable Kustomize application. Running `kubectl kustomize deploy/k8s/base/`
produces all resources required by the LMS. Overlays must reference this as their base.

| Directory | Class | Notes |
|-----------|-------|-------|
| `base/apps/caddy/` | `authoritative-package` + `authoritative-runtime` | Caddyfile defines all app routing. GitOps may patch hosts/TLS only — never replace the Caddyfile. |
| `base/apps/cms/` | `authoritative-package` | CMS Deployment, Service, HPA, health probe definitions. |
| `base/apps/credentials/` | `authoritative-package` | Credentials service definitions. |
| `base/apps/discovery/` | `authoritative-package` | Discovery service definitions. |
| `base/apps/elasticsearch/` | `authoritative-package` | Elasticsearch StatefulSet/Deployment definitions. |
| `base/apps/enterprise/` | `authoritative-package` | Enterprise services (access, catalog, subsidy, license-manager, admin-portal, learner-portal). |
| `base/apps/hubspot-webhook/` | `authoritative-package` | HubSpot webhook receiver definitions. |
| `base/apps/lms/` | `authoritative-package` | LMS Deployment, Service, HPA, health probe definitions. |
| `base/apps/meilisearch/` | `authoritative-package` | Meilisearch Deployment and Service. |
| `base/apps/mfe/` | `authoritative-package` | Micro-frontend Deployment and Service. Image is sentinel (`pin-required`) — overlays MUST pin. |
| `base/apps/mongodb/` | `authoritative-package` | MongoDB StatefulSet/Deployment definitions. |
| `base/apps/multi-tenancy/` | `authoritative-package` | Multi-tenancy ConfigMaps and wiring. |
| `base/apps/mysql/` | `authoritative-package` | MySQL StatefulSet/Deployment definitions. |
| `base/apps/notes/` | `authoritative-package` | Notes service definitions. |
| `base/apps/openedx/` | `authoritative-package` + `authoritative-runtime` | See sub-classification below. |
| `base/apps/preview-redirect/` | `authoritative-package` | Preview redirect Deployment and Service. |
| `base/apps/purchase-gateway/` | `authoritative-package` | Purchase gateway (payments) Deployment, Service, HPA. |
| `base/apps/redis/` | `authoritative-package` | Redis Deployment and Service. |
| `base/apps/smtp/` | `authoritative-package` | SMTP relay Deployment and Service. |
| `base/apps/xqueue/` | `authoritative-package` | XQueue service (disabled by default, replicas: 0). |
| `base/apps/xqueue-graders/` | `authoritative-package` | XQueue graders definitions. |
| `base/jobs/` | `authoritative-package` | One-shot migration Jobs and CronJobs. Applied manually at release time. |
| `base/monitoring/` | `authoritative-package` | ServiceMonitors, PrometheusRules, Grafana dashboards. |
| `base/network-policies/` | `authoritative-package` | NetworkPolicy (or CiliumNetworkPolicy) definitions. |
| `base/operational/` | `authoritative-package` | Operational resources (PodDisruptionBudgets, etc.). |
| `base/patches/` | `authoritative-package` | Strategic merge patches applied within base. |
| `base/plugins/` | `authoritative-package` | Open edX plugin overlays (aspects, credentials, discovery, mfe, notes, xqueue). |
| `base/secrets/` | `authoritative-package` (ExternalSecrets) + `platform-debt` (ClusterSecretStore) | See secrets sub-classification below. |

### `base/apps/openedx/settings/` — `authoritative-runtime`

This directory is the most critical authoritative-runtime surface in the repo.

| Path | Class | Notes |
|------|-------|-------|
| `settings/lms/production.py` | `authoritative-runtime` | Django LMS production config. All env-driven feature flags, INSTALLED_APPS, middleware, and integrations live here. GitOps MUST NOT duplicate or override Python logic — only inject env vars. |
| `settings/cms/production.py` | `authoritative-runtime` | Django CMS production config. Same constraints as LMS. |
| `settings/lms/` (other files) | `authoritative-runtime` | LMS settings variants (development, test, etc.). |
| `settings/cms/` (other files) | `authoritative-runtime` | CMS settings variants. |

**Conflict rule**: If an environment needs a different behavior, add an env var read in `production.py`
and inject the env var from the bbi-infrastructure overlay. Never duplicate Python logic in overlay YAML.

### `base/secrets/` — Mixed Classification

| File | Class | Notes |
|------|-------|-------|
| `secrets/external-secrets.yaml` | `authoritative-package` | ExternalSecret CRs that fetch from ClusterSecretStore. |
| `secrets/openedx-secrets.yaml` | `authoritative-package` | OpenedX secret bundle definition. |
| `secrets/SECRET_CLASSIFICATION.yaml` | `authoritative-package` | Secret inventory and classification manifest. |
| `secrets/cluster-secret-store.yaml` | `platform-debt` | ClusterSecretStore is cluster-scoped. Should live in platform-control-plane. Frozen. |

---

## Platform Debt

These directories contain cluster-scoped or platform-layer resources that should not live in the
app repo. They are tracked for migration. File counts are **frozen** — no new files may be added.

| Directory | Class | Frozen Baseline | Migration Target |
|-----------|-------|-----------------|-----------------|
| `base/arc/` | `platform-debt` | 6 files | bbi-infrastructure platform overlay |
| `base/logging/` | `platform-debt` | 7 files | bbi-infrastructure platform overlay |
| `base/policies/` | `platform-debt` | 6 files | platform-control-plane repo |
| `base/secrets/cluster-secret-store.yaml` | `platform-debt` | 1 file | platform-control-plane repo |

**Rule**: The `verify-runtime-authority-map.sh` guard enforces these baselines.
Any addition to these directories requires updating the baseline in the guard script
AND recording the justification in this document.

---

## Overlays Classification

### `deploy/k8s/overlays/local/` — `local-only`

Reference implementation for local Kind/Minikube development. Demonstrates all required patches
for a consumer overlay. **Actively maintained by this repo.**

- Owner: This repo
- Consumed by: Local `kubectl kustomize` runs, CI smoke tests
- Permitted mutations: All — this overlay is under full app repo control

### `deploy/k8s/overlays/rke2-nonprod/` — `deprecated`

Frozen. Was used during RKE2 non-production cluster bring-up. Superseded by
`bbi-infrastructure/apps/mereka-lms/overlays/dev/`.

- Owner: None (frozen, not consumed)
- Consumed by: Nobody — ArgoCD does NOT reference this path
- **Frozen baseline: 21 files**
- Kustomization contains `# DEPRECATED` marker

### `deploy/k8s/overlays/staging/` — `deprecated`

Frozen. Was used during staging bring-up. Superseded by
`bbi-infrastructure/apps/mereka-lms/overlays/staging/`.

- Owner: None (frozen, not consumed)
- Consumed by: Nobody — ArgoCD does NOT reference this path
- **Frozen baseline: 19 files**
- Kustomization contains `# DEPRECATED` marker

### `deploy/k8s/overlays/production/` — `deprecated`

Frozen. Was used during initial production bring-up. Superseded by
`bbi-infrastructure/apps/mereka-lms/overlays/prod/`.

- Owner: None (frozen, not consumed)
- Consumed by: Nobody — ArgoCD does NOT reference this path
- **Frozen baseline: 11 files**
- Kustomization contains `# DEPRECATED` marker

---

## GitOps Override Boundary

From `contract.json` `allowedGitOpsOverrides` — what bbi-infrastructure overlays MAY mutate:

| Override Type | Example |
|---------------|---------|
| `namespace` | `namespace: mereka-lms-dev` |
| `image_pin` | `newTag: sha-abc123` (must be immutable — no `:latest`, `:main`) |
| `ingress_host` | `host: academyv2.mereka.io` |
| `tls_certificate` | TLS cert issuer per environment |
| `secret_store_ref` | `name: infisical-secret-store-dev` |
| `env_var_injection` | `LMS_ROOT_URL`, `CMS_ROOT_URL`, `MFE_HOST`, `MYSQL_HOST`, `REDIS_HOST`, `MONGODB_HOST`, `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `ENABLE_GATEWAY_FULFILLMENT`, `MEREKA_LMS_DOMAIN`, `MEREKA_CREDENTIALS_DOMAIN` |
| `resource_sizing` | CPU/memory requests and limits |
| `replica_count` | Scale per environment |
| `argocd_application` | ArgoCD Application/ApplicationSet definitions |
| `storage_class` | PVC storageClassName |

From `contract.json` `forbiddenGitOpsMutations` — what bbi-infrastructure overlays MUST NOT do:

| Forbidden Mutation | Fix |
|--------------------|-----|
| Python settings logic in overlay YAML | Add env var read in `production.py`, inject env var from overlay |
| Hardcoded ConfigMap content-hash names | Use strategic merge with name-based matching |
| Full Caddyfile override | App repo owns Caddyfile; overlay patches hosts/TLS only |
| Mutable image tags (`:latest`, `:main`, branch names) | Use SHA-pinned tags from build pipeline |
| Cluster-scoped resources in app overlay | Cluster-scoped resources go in platform-control-plane |
| Positional array patches (`/spec/.../0`) | Use strategic merge or named patch targets |
| Django middleware/auth config in overlay | Middleware belongs in `production.py` |

---

## Quick Reference Table

| Surface | Class | Owner | Mutable? |
|---------|-------|-------|----------|
| `base/apps/*/` (workloads) | authoritative-package | This repo | Yes — via PR |
| `base/apps/openedx/settings/*/production.py` | authoritative-runtime | This repo | Yes — via PR |
| `base/apps/caddy/Caddyfile` | authoritative-runtime | This repo | Yes — via PR |
| `base/monitoring/` | authoritative-package | This repo | Yes — via PR |
| `base/network-policies/` | authoritative-package | This repo | Yes — via PR |
| `base/plugins/` | authoritative-package | This repo | Yes — via PR |
| `base/secrets/external-secrets.yaml` | authoritative-package | This repo | Yes — via PR |
| `base/secrets/cluster-secret-store.yaml` | platform-debt | Platform team | Frozen — migrate to platform-control-plane |
| `base/arc/` | platform-debt | Platform team | Frozen — migrate to bbi-infrastructure |
| `base/logging/` | platform-debt | Platform team | Frozen — migrate to bbi-infrastructure |
| `base/policies/` | platform-debt | Platform team | Frozen — migrate to platform-control-plane |
| `overlays/local/` | local-only | This repo | Yes — local dev only |
| `overlays/rke2-nonprod/` | deprecated | Nobody | Frozen — do not modify |
| `overlays/staging/` | deprecated | Nobody | Frozen — do not modify |
| `overlays/production/` | deprecated | Nobody | Frozen — do not modify |

---

## Guard Script

`scripts/qa/verify-runtime-authority-map.sh` enforces the frozen baselines and structural
invariants documented here. Run it before any PR that touches `deploy/k8s/`.

```bash
bash scripts/qa/verify-runtime-authority-map.sh
```

It is also wired into the `validate-deploy-contract` Makefile target.

---

## Change Log

| Version | Date | Change |
|---------|------|--------|
| 1.3.0 | 2026-03-09 | Initial RUNTIME_AUTHORITY_MAP.md created |
