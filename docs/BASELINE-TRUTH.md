# Baseline Truth

Last verified: 2026-03-16T11:10Z

## Estate Map

| Repo | Branch | SHA | Role |
|------|--------|-----|------|
| mereka-lms | main | fb2938f4 | App repo — Django settings, K8s base manifests, Tutor plugin, image builds |
| bbi-infrastructure | main | 0b1f9ba1 | GitOps repo — overlays, image tags, Argo apps, env wiring |

| Environment | Namespace | Argo App | Argo State | Image Source |
|-------------|-----------|----------|------------|-------------|
| Dev | mereka-lms-dev | mereka-lms-dev | Synced/Healthy | profiles/dev |
| Staging | stg-mereka-lms | mereka-lms-staging | OutOfSync/Degraded | overlays/staging |
| Prod (GKE) | mereka-lms | N/A (Argo parked) | Parked (0 replicas) | overlays/prod |

## Live Dev Images

| Component | Image | Tag |
|-----------|-------|-----|
| LMS | ghcr.io/.../openedx | 8a7f2476 |
| CMS | ghcr.io/.../openedx | 8a7f2476 |
| MFE | ghcr.io/.../mfe | e6adf950 |

Image tags match `profiles/dev/kustomization.yaml`. Argo deploys
from `apps/mereka-lms/overlays/profiles/dev`, NOT `overlays/dev`.

## Route Ownership

| Host | Ingress | Serves |
|------|---------|--------|
| academyv2.mereka.dev | openedx-lms | LMS Django (courses, dashboard, API, OAuth) |
| apps.academyv2.mereka.dev | openedx-mfe | MFE Caddy (authn, account, authoring, learning) |
| studio.academyv2.mereka.dev | openedx-studio | CMS Django (Studio backend, OAuth SSO) |
| admin.academyv2.mereka.dev | openedx-lms | LMS (admin alias) |

| MFE Route | Canonical? | Notes |
|-----------|-----------|-------|
| /authoring/home | YES | Studio MFE, config points here |
| /course-authoring/home | STALE | Still serves HTML, config no longer advertises |
| /authn/login | YES | Auth MFE |
| /account | YES | Account MFE |
| /learning/course/... | YES | Learning MFE |

## Settings Authority

| Concern | Canonical Source | Delivery |
|---------|----------------|----------|
| Django app behavior | mereka-lms base production.py | Vendored into infra, mounted as ConfigMap |
| Env-specific values | bbi-infra overlay Python files | ConfigMap (disableNameSuffixHash) |
| Image tags | profiles/dev/kustomization.yaml | Argo sync |
| MFE branding | MFE image (build-time) | Image pull |
| LMS theme | DEFAULT_SITE_THEME in overlay | ConfigMap |

## ConfigMap Delivery (Dev)

PR #1864 (merged 2026-03-16) removed `disableNameSuffixHash: true`.
Settings content changes now auto-trigger pod rollouts via hash-suffixed
CM names — matching the prod pattern. The previous rollout-hash annotation
workaround is redundant (but harmless) and can be removed in a future cleanup.

## Core Surface Health (verified 2026-03-16T09:43Z)

| Surface | Status | Evidence |
|---------|--------|----------|
| /authn/login | 200 | curl |
| /courses | 200 + mereka CSS | curl |
| /authoring/home | 200 | curl |
| course API | 109 courses | curl |
| mfe_config COURSE_AUTHORING | /authoring | curl |
| Argo | Synced/Healthy | kubectl |
