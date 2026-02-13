# Repo Boundaries: `mereka-lms` vs `BBI-K8` (`infrastructure`)

<!-- Last verified: 2026-02-13 -->

This document defines ownership boundaries to prevent drift, duplication, and regression.

## Current Environment Reality

- Active runtime environments: `dev/local` and `prod`.
- No dedicated `staging` cluster is active right now.
- Keep staging overlays as future-ready only; default operational path is `dev/local -> prod`.

## Ownership Matrix

| Concern | Canonical Repo | Why |
|---|---|---|
| Open edX app code, Tutor themes, build scripts, QA scripts | `mereka-lms` | Source for what gets built and validated |
| Base K8s manifests for Open edX (`deploy/k8s/base`) | `mereka-lms` | App-level runtime contract owned with app code |
| ArgoCD Applications/ApplicationSets, env overlays, pinned refs, image tag overrides | `BBI-K8` (`/home/gurpreet/projects/k8s/infrastructure`) | GitOps desired state for clusters |
| Cross-app platform services (Authentik, Grafana, n8n, listmonk, etc.) | `BBI-K8` | Platform scope beyond Open edX |
| Secrets values | Infisical | Single source of truth (not Git) |

## Critical Detail: Prod Uses Patched Settings from GitOps

In production, the GitOps repo generates and mounts *patched* Django settings ConfigMaps.

That means:
- Changing `deploy/k8s/base/apps/openedx/settings/**/production.py` in `mereka-lms` is necessary for correctness,
  but it may not affect **live prod** until the corresponding GitOps patch file is also updated.

Current canonical prod patch files live in the GitOps repo:
- `apps/mereka-lms/overlays/prod/patches/production-prod.py` (LMS settings)
- `apps/mereka-lms/overlays/prod/patches/production-cms-prod.py` (CMS settings, if present)

So the minimal “prod release” for auth changes is:
1. Merge `mereka-lms` changes.
2. Bump the pinned base ref in GitOps:
   `apps/mereka-lms/base/kustomization.yaml` (`ref=<new sha>`).
3. Update any GitOps settings patch files that override the changed behavior.

Guardrail:
- `./scripts/qa/verify-gitops-mereka-lms-pin.sh` (this repo) detects “pinned ref not bumped”.

## Golden Rules

1. Do not duplicate the same runtime intent in both repos.
2. `mereka-lms` defines app/base behavior; `BBI-K8` selects version + environment.
3. Production rollout is not complete until both are updated:
   - `mereka-lms` commit containing desired base
   - `BBI-K8` pinned `?ref=<sha>` + prod image overrides
4. No direct manual cluster edits for steady state. Emergency runtime hotfixes must be backported to repo.

## Auth-Specific Split

- `mereka-lms` owns:
  - Open edX auth settings defaults, scripts, and verification (`scripts/qa/*auth*`).
  - Multisite bootstrap behavior (`scripts/shared/multisite_bootstrap_django.py`).
- `BBI-K8` owns:
  - Production overlay patches applied to LMS/CMS settings.
  - Runtime wiring and ArgoCD rollout mechanics.

## Standard Change Flow (No Staging Cluster)

1. Validate in `dev/local` from `mereka-lms`.
2. Merge `mereka-lms` changes.
3. In `BBI-K8`, bump pinned ref to new `mereka-lms` SHA and set prod image tags.
4. Let ArgoCD sync and verify runtime gates.

## Enforcement Checks

- In `mereka-lms`:
  - `./scripts/qa/verify-auth-surfaces.sh prod`
  - `./scripts/qa/verify-oidc-provider-configs.sh --env prod`
  - `./scripts/qa/verify-gitops-image-overrides.sh --check-infra`
- In `BBI-K8`:
  - Ensure prod overlay uses expected image tags and latest pinned `?ref`.
