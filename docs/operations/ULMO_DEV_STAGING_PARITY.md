# Ulmo Dev Parity Gap Analysis

**Last updated**: 2026-02-25
**Status**: Active gap analysis

---

## Context

Tutor v21 (Open edX Ulmo / Indigo) is the current release on production GKE
(`academyv2.mereka.io`). The cluster is scaled to 0 replicas to reduce costs but the
images and config are fully deployed and validated.

The rke2-nonprod cluster (`academyv2.mereka.dev`) runs identically structured
Kubernetes manifests via the `deploy/k8s/overlays/rke2-nonprod` Kustomize overlay.
The goal of this document is to enumerate every gap that must be closed before
rke2-nonprod can serve as a reliable dev environment for production-equivalent
Ulmo testing. Dev is validated first, then production GKE is scaled back up.

**GitOps source of truth**: `infrastructure` repo
(`apps/mereka-lms/overlays/profiles/dev`). This document tracks what
`mereka-lms` must contribute: images, Tutor config, secrets, and theme assets.

---

## Current State

### Production (GKE, `academyv2.mereka.io`)

| Item | Status |
|------|--------|
| Platform | Tutor v21 / Open edX Ulmo / Indigo theme |
| LMS | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand-hotfix-full-v3` |
| MFE | `ghcr.io/biji-biji-initiative/mereka-lms/mfe:1c66529-20260220023917` |
| Enterprise Admin MFE | `…/enterprise-admin-portal:nreum-clean-202602200416` |
| Enterprise Learner MFE | `…/enterprise-learner-portal:nreum-clean-202602200416` |
| Secret store | `gcp-secret-manager` ClusterSecretStore (Workload Identity, GCP project `bbi-k8`) |
| Domain config | All URLs hardcoded to `academyv2.mereka.io` in `lms.env.yml` / `cms.env.yml` |
| Replica count | LMS×2, lms-worker×2, CMS×1, cms-worker×1; all others scaled to 0 |
| Cluster | GKE, scaled to 0 (cost saving) |

### rke2-nonprod (`academyv2.mereka.dev`)

| Item | Status |
|------|--------|
| Platform | Deploys base images from `deploy/k8s/base/kustomization.yaml` (Ulmo versions `21.0.0-indigo`) |
| LMS | `overhangio/openedx:21.0.0-indigo` (base, no custom Mereka build) |
| MFE | `overhangio/openedx-mfe:21.0.0-indigo` (base, no custom Mereka build) |
| Enterprise MFEs | No image override; inherits base image tags |
| Secret store | `infisical-secret-store` ClusterSecretStore (patched via `patches/externalsecrets-infisical.yaml`) |
| Domain env | `patches/domain-env.yaml` overrides `MEREKA_LMS_DOMAIN`, `LMS_BASE_URL`, `MFE_BASE_URL` for LMS/CMS/workers/discovery/notes |
| `lms.env.yml` / `cms.env.yml` | NOT patched — still hardcoded to `academyv2.mereka.io` |
| Image pull | Requires `artifact-registry-key` imagePullSecret (manual prerequisite) |
| Replica count | 1 per service defined in kustomization; enterprise services set to 1 (images may be absent) |
| Kustomize version annotation | `app.kubernetes.io/version: 18.2.2` (stale — base never updated) |

---

## Image Tag Inventory

### Base (`deploy/k8s/base/kustomization.yaml`)

The base layer sets upstream image tags and overrides the main OpenedX image to the
Mereka-branded build at `mereka-brand-hotfix-full-v3`. Downstream overlays re-pin
the MFE tag.

| Service | Base image in `deployments.yml` | Override in `base/kustomization.yaml` |
|---------|---------------------------------|---------------------------------------|
| `lms` / `cms` / workers | `docker.io/overhangio/openedx:21.0.0-indigo` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand-hotfix-full-v3` |
| `mfe` | `docker.io/overhangio/openedx-mfe:21.0.0-indigo` | `ghcr.io/biji-biji-initiative/mereka-lms/mfe:b732a7d-20260210161437` |
| `discovery` | `docker.io/overhangio/openedx-discovery:21.0.1` | (none) |
| `ecommerce` | `docker.io/overhangio/openedx-ecommerce:19.0.0` | (none) |
| `credentials` | `docker.io/overhangio/openedx-credentials:21.0.0` | (none) |
| `notes` | `docker.io/overhangio/openedx-notes:21.0.0` | (none) |
| `xqueue` | `docker.io/overhangio/openedx-xqueue:21.0.0` | (none) |
| `caddy` | `docker.io/caddy:2.7.4` | (none) |
| `redis` | `docker.io/redis:7.2.4` | (none) |
| `mysql` | `docker.io/mysql:8.4.0` | (none) |
| `meilisearch` | `docker.io/getmeili/meilisearch:v1.8.4` | (none) |

### Production overlay additional overrides (`deploy/k8s/overlays/production/kustomization.yaml`)

| Service | Production tag |
|---------|----------------|
| `openedx` (lms/cms/workers) | `mereka-brand-hotfix-full-v3` (same as base) |
| `openedx-mfe` | `1c66529-20260220023917` (more recent than base) |
| `enterprise-admin-portal` | `nreum-clean-202602200416` |
| `enterprise-learner-portal` | `nreum-clean-202602200416` |

### rke2-nonprod overlay gaps

The `rke2-nonprod` overlay has **no `images:` block**. It inherits whatever the
base sets. This means:

1. The LMS image is the Mereka-branded build (`mereka-brand-hotfix-full-v3`) — correct.
2. The MFE image is `b732a7d-20260210161437` (base) instead of `1c66529-20260220023917`
   (production) — **10-day lag**.
3. Enterprise MFE images (`enterprise-admin-portal`, `enterprise-learner-portal`) are
   not pinned — they will fall back to whatever is in the enterprise deployment
   ConfigMap/Deployment, likely upstream defaults — **untested on rke2-nonprod**.

---

## Tutor v21 Config Requirements

The `infrastructure/tutor/` directory manages Tutor configuration locally. Key points:

### Patch modules (`infrastructure/tutor/patches/`)

| Patch | Purpose | Required for Ulmo |
|-------|---------|-------------------|
| `mysql-auth.sh` | `mysql_native_password` plugin fix | Yes (MySQL 8) |
| `mfe-node.sh` | Node 24 toolchain, ulmo.1 MFE source refs, brand pkg `^2.4.x` | Yes |
| `domain-names.sh` | Extra hostnames (biji-biji.com, skillourfuture) | Yes |
| `webpack-memory.sh` | `NODE_OPTIONS=--max-old-space-size=6144` | Yes (build only) |
| `csrf-origins.sh` | CSRF trusted origins for both mereka.io and mereka.dev | Yes |
| `footer-component.sh` | Custom Mereka footer for MFEs | Yes |
| `prometheus-metrics.sh` | Prometheus scrape annotation injection | Recommended |
| `build-optimizations.sh` | Build retry logic, cache opts | Build time only |
| `mongodb-atlas.sh` | `pymongo[srv]` for Atlas SRV | Yes |
| `security-hardening.sh` | Container security context hardening | Yes |

### `config.example.yml` observations

The example config now references `OPENEDX_COMMON_VERSION: open-release/ulmo.1`, which
matches the Ulmo baseline used by parity verifiers.

The MFE Dockerfile at `infrastructure/tutor/mfe-build/Dockerfile` is the canonical
Ulmo MFE build definition. It uses `release/ulmo.1` for all 11+ MFE app source refs
and `release/ulmo` for Atlas translation pulls — this is correct.

---

## Known Gaps

### Gap 1 (RESOLVED 2026-02-28): `openedx-config` nonprod domain override

**File**: `deploy/k8s/base/apps/openedx/config/lms.env.yml`,
`deploy/k8s/base/apps/openedx/config/cms.env.yml`

**Problem**: `SITE_NAME`, `LMS_ROOT_URL`, `CMS_ROOT_URL`, `OAUTH_OIDC_ISSUER`,
`SESSION_COOKIE_DOMAIN`, and `PREVIEW_LMS_BASE` all reference `academyv2.mereka.io`.
These are baked into the `openedx-config` ConfigMap at `kustomize build` time.

The `domain-env.yaml` patch in rke2-nonprod only overrides env vars on the
Deployment (`MEREKA_LMS_DOMAIN`, `LMS_BASE_URL`, `MFE_BASE_URL`). It does not
patch the ConfigMap-backed `lms.env.yml` / `cms.env.yml` values.

**Effect**: Django settings read `SITE_NAME`, `LMS_ROOT_URL`, `SESSION_COOKIE_DOMAIN`
from the env YAML at startup. On rke2-nonprod these will be production values.
Authentication, session cookies, and OIDC redirects will point to
`academyv2.mereka.io` even when the pod is running on `academyv2.mereka.dev`.

**Fix implemented**: `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml` now merges
`openedx-config` with overlay-specific files:
- `deploy/k8s/overlays/rke2-nonprod/config/lms.env.yml`
- `deploy/k8s/overlays/rke2-nonprod/config/cms.env.yml`

These files set `academyv2.mereka.dev` roots, `.academyv2.mereka.dev` cookie domain,
and `.dev` OIDC issuer values for nonprod runtime.

---

### Gap 2 (RESOLVED 2026-02-28): MFE image tag parity in rke2-nonprod

**Problem (historical)**: Base kustomization pinned MFE to
`b732a7d-20260210161437`; production overlay re-pinned to
`1c66529-20260220023917` (newer). rke2-nonprod previously lacked an explicit MFE
override and inherited the stale base tag.

**Effect**: rke2-nonprod tests an older MFE build. NREUM-clean and
`env.config.js` wiring applied in `nreum-clean-202602200416` will not be present in
the rke2-nonprod MFE.

**Fix implemented**: `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml` now pins
both canonical and transformed MFE image names to `1c66529-20260220023917`.

---

### Gap 3 (RESOLVED 2026-02-28): Enterprise MFE image parity in rke2-nonprod

**Problem (historical)**: `enterprise-admin-portal` and
`enterprise-learner-portal` image tags (`nreum-clean-202602200416`) were only set in
the production overlay. rke2-nonprod had no overrides.

**Effect**: Enterprise MFE pods on rke2-nonprod will run un-patched upstream images
without NREUM removal or `env.config.js` wiring. These will crash or serve broken UI.

**Fix implemented**: rke2-nonprod now pins both enterprise MFE images to
`nreum-clean-202602200416`, matching production.

---

### Gap 4 (RESOLVED 2026-02-28): `app.kubernetes.io/version` annotation parity

**Problem (historical)**: `deploy/k8s/base/kustomization.yaml` had stale
`app.kubernetes.io/version` metadata.

**Effect**: Observability dashboards and ArgoCD may show incorrect version metadata.
Not a runtime breakage but misleading.

**Fix implemented**: base annotation is `app.kubernetes.io/version: 21.0.0`, and
`scripts/qa/verify-ulmo-parity.sh` now enforces this value.

---

### Gap 5 (RESOLVED 2026-02-28): Design Tokens CI drift gate

**Background**: `assets/branding/tokens.css` is the canonical design token source.
`infrastructure/tutor/themes/mereka/scss/_tokens.scss` is generated from it via
`generate-tokens-from-canonical.sh`. Both files are present and current.

**Problem (historical)**: The token pipeline had manual steps and needed CI
enforcement for drift.

**Effect**: Color / typography drift in LMS and Studio on rke2-nonprod.

**Fix implemented**: CI includes `design-token-validation` and enforces
`generate-tokens-from-canonical.sh --check`; `verify-ulmo-parity.sh` now checks this
contract.

---

### Gap 6 (RESOLVED 2026-02-28): Image pull prerequisite enforcement

**Problem**: The rke2-nonprod `kustomization.yaml` documents three manual prerequisites:
1. `infisical-secret-store` ClusterSecretStore
2. `artifact-registry-key` Secret
3. Default ServiceAccount `imagePullSecrets` or per-Deployment override

If `artifact-registry-key` is absent, all pods fail to pull images from GCP Artifact
Registry with `ImagePullBackOff`.

**Fix implemented**: `scripts/qa/verify-ulmo-parity.sh --online` verifies both
`infisical-secret-store` and `artifact-registry-key` on the target context/namespace.

---

### Gap 7 (RESOLVED 2026-02-28): `config.example.yml` Ulmo baseline

**Problem (historical)**: `infrastructure/tutor/config.example.yml` previously used a
pre-Ulmo value that could mislead operators.

**Fix implemented**: `OPENEDX_COMMON_VERSION` is set to `open-release/ulmo.1`, and
`verify-ulmo-parity.sh` enforces it.

---

### Gap 8 (LOW): Forum routes missing from Caddyfile for `mereka.dev`

**Problem**: The Caddyfile has `http://academyv2.mereka.dev` routes for LMS, Studio,
discovery, ecommerce, notes, credentials — but forum v2 is integrated into the LMS
process and does not need a separate Caddy block. The rke2-nonprod ingress includes
`forum.academyv2.mereka.dev` in TLS hosts. This is routed via Caddy to the LMS
backend. The Caddy config includes `http://academyv2.mereka.dev` which handles the
forum in-process. This gap is informational — no fix needed unless forum path routing
diverges.

---

## Parity Checklist

Items to complete before rke2-nonprod is production-equivalent for Ulmo testing.

### Infrastructure (infrastructure repo)

- [ ] Confirm `infisical-secret-store` ClusterSecretStore is `Valid/Ready` on rke2-nonprod
- [ ] Confirm `artifact-registry-key` Secret exists in `mereka-lms` namespace
- [ ] Confirm `cert-manager` and `letsencrypt-prod` ClusterIssuer are active

### mereka-lms repo

- [x] **Gap 1**: Added `configMapGenerator` merge for `openedx-config` in rke2-nonprod
  using `overlays/rke2-nonprod/config/{lms,cms}.env.yml` (`.dev` roots, cookie domain,
  OIDC issuer, preview base)
- [x] **Gap 2**: Added canonical + transformed `openedx-mfe` image pin entries in
  `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml` to
  `1c66529-20260220023917` (matches production)
- [x] **Gap 3**: Added `enterprise-admin-portal` and `enterprise-learner-portal`
  image pins in rke2-nonprod overlay matching production
  (`nreum-clean-202602200416`)
- [x] **Gap 4**: `commonAnnotations.app.kubernetes.io/version` set to `21.0.0`
  and enforced by `verify-ulmo-parity.sh`
- [x] **Gap 5**: CI drift gate (`design-token-validation` +
  `generate-tokens-from-canonical.sh --check`) is active and enforced by
  `verify-ulmo-parity.sh`
- [x] **Gap 7**: `config.example.yml` `OPENEDX_COMMON_VERSION` updated to
  `open-release/ulmo.1` and enforced by `verify-ulmo-parity.sh`

### Verification

- [x] Run `scripts/qa/verify-ulmo-parity.sh` — all checks PASS or SKIP (offline)
- [ ] Run `scripts/qa/verify-rke2-dev-readiness.sh --offline` — PASS
- [ ] Smoke test: `https://academyv2.mereka.dev/` returns HTTP 200 with Mereka theme
- [ ] Smoke test: `https://apps.academyv2.mereka.dev/authn/login` returns HTTP 200
- [ ] Smoke test: `https://studio.academyv2.mereka.dev/` returns HTTP 200

---

## Notes on infrastructure repo

The actual ArgoCD Application and workload profile live in `infrastructure`. The
profile for rke2-nonprod dev at
`apps/mereka-lms/overlays/profiles/dev/workload-profile.yaml` sets many services to 0
replicas for cost control. When running Ulmo parity tests, the relevant services
(LMS, CMS, MFE, lms-worker, cms-worker, discovery) must be scaled to at least 1.

The `infrastructure` repo must also apply any domain-specific ConfigMap patches
for `lms.env.yml` / `cms.env.yml` if those are managed there rather than in this
repo's overlay. Coordinate with the platform team before making changes to either
side of this boundary.
