# Ulmo Dev Parity Gap Analysis

**Last updated**: 2026-02-25
**Status**: Superseded — production is now on **rke2-prod**, not GKE

> **CORRECTION (2026-04-06)**: This document was written when production was on GKE.
> Production has since migrated to **rke2-prod** (Contabo VPS). GKE is decommissioned.
> References to "production GKE" and "GKE scaled to 0" below are historical context only.
> The canonical production substrate is `rke2-prod`, namespace `mereka-lms`.
> See `deploy/k8s/tenancy/tenant-registry.yaml` for current production truth.

---

## Context (historical — see correction above)

Tutor v21 (Open edX Ulmo, repo-owned Mereka theme/plugin path) is the current release on production ~~GKE~~
rke2-prod (`academyv2.mereka.io`). ~~The cluster is scaled to 0 replicas to reduce
costs but the images and config are fully deployed and validated.~~

The rke2-nonprod cluster (`academyv2.mereka.dev`) runs identically structured
Kubernetes manifests via the `deploy/k8s/overlays/rke2-nonprod` Kustomize overlay.
~~The goal of this document is to enumerate every gap that must be closed before
rke2-nonprod can serve as a reliable dev environment for production-equivalent
Ulmo testing. Dev is validated first, then production GKE is scaled back up.~~

**GitOps source of truth**: `bbi-infrastructure`
(`apps/mereka-lms/overlays/{dev,staging,prod}/`). This document tracks what
`mereka-lms` contributes: app-owned base manifests, Tutor/plugin logic,
verification scripts, and reference overlays retained in this repo.

> Repo-boundary truth note:
> `mereka-lms` can prove app-owned contracts and reference overlay intent.
> It cannot, by itself, prove final `dev`/`staging` lane parity for non-local
> overlays or runtime-only state such as `SiteConfiguration.site_values["MFE_CONFIG"]`.

---

## Current State

### Production (GKE, `academyv2.mereka.io`)

| Item | Status |
|------|--------|
| Platform | Tutor v21 / Open edX Ulmo / Mereka theme and plugin path |
| LMS | Lane-realized GHCR pin is GitOps-owned in `bbi-infrastructure` |
| MFE | Lane-realized GHCR pin is GitOps-owned in `bbi-infrastructure` |
| Enterprise Admin MFE | `…/enterprise-admin-portal:nreum-clean-202602200416` |
| Enterprise Learner MFE | `…/enterprise-learner-portal:nreum-clean-202602200416` |
| Secret store | `gcp-secret-manager` ClusterSecretStore (Workload Identity, GCP project `bbi-k8`) |
| Domain config | All URLs hardcoded to `academyv2.mereka.io` in `lms.env.yml` / `cms.env.yml` |
| Replica count | Prelaunch cost mode: keep runtime replicas at 0 unless explicitly needed |
| Cluster | GKE today, planned move to dedicated prod RKE2 cluster in May |

### rke2-nonprod (`academyv2.mereka.dev`)

| Item | Status |
|------|--------|
| Platform | App repo ships Ulmo-era base manifests; final lane realization is GitOps-owned |
| LMS | Base deployment uses `docker.io/overhangio/openedx:21.0.0`; base kustomization redirects to GHCR with `pin-required` sentinel |
| MFE | Base deployment uses `docker.io/overhangio/openedx-mfe:21.0.0`; reference overlay carries explicit GHCR pins |
| Enterprise MFEs | Reference overlay carries explicit GHCR tags; live dev/staging parity is infra-owned |
| Secret store | `infisical-secret-store-dev` ClusterSecretStore (patched via `patches/externalsecrets-infisical.yaml`) |
| Domain env | `patches/domain-env.yaml` overrides `MEREKA_LMS_DOMAIN`, `LMS_BASE_URL`, `MFE_BASE_URL` for LMS/CMS/workers/discovery/notes |
| `lms.env.yml` / `cms.env.yml` | rke2-nonprod overlay merges nonprod-specific config files for `.dev` runtime values |
| Image pull | Requires `ghcr-registry` imagePullSecret (manual prerequisite) |
| Replica count | 1 per service defined in kustomization; enterprise services set to 1 (images may be absent) |
| Kustomize version annotation | `app.kubernetes.io/version: 21.0.0` in base kustomization |

---

## Image Tag Inventory

### Base (`deploy/k8s/base/` + `deploy/k8s/base/kustomization.yaml`)

The split base deployment manifests retain upstream Ulmo-era images. The base
kustomization then redirects the core Open edX images to GHCR with a
`pin-required` sentinel so every environment overlay must supply a real tag.

| Service | Base image in split deployment manifests | Override in `base/kustomization.yaml` |
|---------|---------------------------------|---------------------------------------|
| `lms` / `cms` / workers | `docker.io/overhangio/openedx:21.0.0` | `ghcr.io/biji-biji-initiative/mereka-lms/openedx:pin-required` |
| `mfe` | `docker.io/overhangio/openedx-mfe:21.0.0` | `ghcr.io/biji-biji-initiative/mereka-lms/mfe:pin-required` |
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
| `openedx` (lms/cms/workers) | lane-realized GHCR pin in `bbi-infrastructure` |
| `openedx-mfe` | lane-realized GHCR pin in `bbi-infrastructure` |
| `enterprise-admin-portal` | `nreum-clean-202602200416` |
| `enterprise-learner-portal` | `nreum-clean-202602200416` |

### rke2-nonprod overlay truth

The repo-local `rke2-nonprod` overlay is reference-only and no longer the
authoritative live dev overlay. It does still matter as app-owned intent:

1. it carries an explicit `images:` block
2. it pins both canonical and transformed MFE image names to concrete tags
3. it pins enterprise admin and learner portal GHCR tags explicitly

Final live `dev` / `staging` image parity must be proved from
`bbi-infrastructure`, not from this reference overlay alone.

## Enterprise Frontend Truth Boundary

Enterprise admin and learner portals are not fully described by image parity
alone. Their runtime truth is split across:

1. lane-realized `enterprise-mfe-env.js`
2. LMS global `MFE_CONFIG`
3. live `SiteConfiguration.site_values["MFE_CONFIG"]`

For `dev` and `staging`, the authoritative lane overlays are infra-owned in
`bbi-infrastructure`. For branded/runtime portal values, the final truth exists
only live. As a result:

- repo-only parity conclusions for enterprise portals are incomplete
- base/default env config checks are necessary but insufficient
- runtime `/api/mfe_config/v1` evidence is required before claiming
  enterprise frontend parity

---

## Tutor v21 Config Requirements

The `infrastructure/tutor/` directory manages Tutor configuration locally. Key points:

### Current Tutor build authorities

| Authority | Purpose | Required for Ulmo |
|-------|---------|-------------------|
| Tutor 21 render + `mysql-root-host.sh` | MySQL native-password mode (`--mysql-native-password=ON`) plus local `MYSQL_ROOT_HOST: "%"` compatibility | Yes |
| `_mereka_lms/mfe_dockerfile.py` + MFE build-context sync | Node 24 toolchain, Ulmo MFE source refs, local brand package `@edx/brand@file:./brand-mereka` | Yes |
| `_mereka_lms/lms_settings.py` | Extra hostnames, CSRF trusted origins, session/cookie settings, discussions, enterprise | Yes |
| `_mereka_lms/mfe_runtime.py` + `sync-footer-assets.sh` | Custom Mereka MFE runtime, theme source, and footer assets | Yes |
| `_mereka_lms/openedx_dockerfile.py` | Repo custom apps and Open edX build dependencies | Yes |
| `dependency-image-mirrors.sh` | Anonymous dependency image acquisition normalization for cold/local builds | Yes |
| `build-optimizations.sh` | Manifest-bounded residual cold-build compatibility and translation wrappers | Build time only |
| `patch-manifest.yml` | Active post-render authority ledger and retirement triggers | Yes |
| `security-hardening.sh` | Container security context hardening | Yes |

### `config.example.yml` observations

The example config now references `OPENEDX_COMMON_VERSION: open-release/ulmo.1`, which
matches the Ulmo baseline used by parity verifiers.

The MFE Dockerfile at `infrastructure/tutor/mfe-build/Dockerfile` is the canonical
Ulmo MFE build definition. It uses `release/ulmo.2` for all 12 MFE app source refs
and `release/ulmo.2` for Atlas translation pulls — this is correct.

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

**Problem (historical)**: The repo-local reference overlay previously lacked an
explicit MFE pin, so it could drift away from the intended nonprod app-owned
baseline.

**Effect**: rke2-nonprod tests an older MFE build. NREUM-clean and
`env.config.js` wiring applied in `nreum-clean-202602200416` will not be present in
the rke2-nonprod MFE.

**Fix implemented**: `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml` now pins
both canonical and transformed MFE image names to a concrete GHCR tag. Final
live dev/staging parity is still infra-owned.

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
1. `infisical-secret-store-dev` ClusterSecretStore
2. `ghcr-registry` Secret
3. Default ServiceAccount `imagePullSecrets` or per-Deployment override

If `ghcr-registry` is absent, all pods fail to pull images from GHCR with
`ImagePullBackOff`.

**Fix implemented**: `scripts/qa/verify-ulmo-parity.sh --online` verifies both
`infisical-secret-store-dev` and `ghcr-registry` on the target context/namespace.

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

- [ ] Confirm `infisical-secret-store-dev` ClusterSecretStore is `Valid/Ready` on rke2-nonprod
- [ ] Confirm `ghcr-registry` Secret exists in `mereka-lms` namespace
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
