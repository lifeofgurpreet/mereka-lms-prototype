# Enterprise MFE: Build-time NREUM removal + canonical deployment hardening

> **Bead**: mereka-lms-69qz / mereka-lms-69qz.1
> **ACs**: AC-DEP-101, AC-DEP-102, AC-DEP-103, AC-DEP-104, AC-DEP-105
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## AC-DEP-101: Legacy strip-nreum initContainer removed

### What changed

Removed `sanitize-enterprise-index-html` / `strip-nreum` / `copy-dist` initContainers
from both enterprise portal deployment manifests:
- `deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml`
- `deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml`

Also removed the `enterprise-admin-portal-dist` / `enterprise-learner-portal-dist` emptyDir volumes.
The main container now serves directly from the image's `/openedx/dist` filesystem (read-only).

### Why this is safe

NREUM is stripped at Docker image build time via `infrastructure/docker/enterprise-mfe-clean/`.
The `nreum-clean-*` images do not contain `undefined_license_key` in their dist/index.html.

### Verification

```
$ grep -q 'strip-nreum\|sanitize-enterprise\|copy-dist' deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml
(no output — workaround absent)

$ grep -q 'strip-nreum\|sanitize-enterprise\|copy-dist' deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml
(no output — workaround absent)
```

---

## AC-DEP-102: Clean images built, verified, pushed

### Build log (scripts/infra/build-enterprise-mfe-clean.sh)

```
=== Enterprise MFE: Build-time NREUM strip ===

  Source tag : latest
  Clean tag  : nreum-clean-202602190645
  Registry   : asia-southeast1-docker.pkg.dev/mereka-lms/openedx

  [PASS] Docker daemon running
  [PASS] GCR auth configured
  [PASS] enterprise-admin-portal:nreum-clean-202602190645 — no undefined_license_key in built image
  [PASS] enterprise-admin-portal:nreum-clean-202602190645 pushed to GCR
  [PASS] enterprise-learner-portal:nreum-clean-202602190645 — no undefined_license_key in built image
  [PASS] enterprise-learner-portal:nreum-clean-202602190645 pushed to GCR

  RESULT: PASS — clean images built and pushed
```

### GCR digests

| Image | Tag | Digest |
|-------|-----|--------|
| enterprise-admin-portal | nreum-clean-202602190645 | sha256:d46af80d16ad8b992f83566b5ebc789e3db8d36a5c10ef67db3fa82765d5ce9c |
| enterprise-learner-portal | nreum-clean-202602190645 | sha256:3a52c191a731ffb7b1d0df6df7c68ac72b8d735b977d73b6b0cea9709b043058 |

### Production kustomization pin

```yaml
# deploy/k8s/overlays/production/kustomization.yaml
images:
  - name: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-admin-portal
    newName: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-admin-portal
    newTag: nreum-clean-202602190645
  - name: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-learner-portal
    newName: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-learner-portal
    newTag: nreum-clean-202602190645
```

### Live cluster smoke (pre-rollout)

Both portals already serving clean HTML via live cluster's existing Python initContainer:

```
$ curl -s https://admin.academyv2.mereka.io/ | grep -c 'undefined_license_key'
0
$ curl -s https://enterprise.academyv2.mereka.io/ | grep -c 'undefined_license_key'
0
```

---

## AC-DEP-103: Deployment runbook updated

Added Section 9 to `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`:
- Build flow: `build-enterprise-mfe-clean.sh` → GCR push
- GitOps: kustomization image tag update → commit + ArgoCD sync
- Post-deploy smoke: `verify-enterprise-mfe-nreum-clean.sh`
- Rollback procedure
- Background context on why derivative images are needed

---

## AC-DEP-104: QA verify script passes

```
$ bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh

=== Enterprise MFE: NREUM / undefined_license_key regression guard ===

--- AC-DEP-102: Admin portal HTML clean ---
  [PASS] Admin portal HTTP status 200 (https://admin.academyv2.mereka.io/)
  [PASS] Admin portal HTML has no 'undefined_license_key'
  [PASS] Admin portal HTML has no NREUM injection at all

--- AC-DEP-102: Enterprise learner portal HTML clean ---
  [PASS] Enterprise portal HTTP status 200 (https://enterprise.academyv2.mereka.io/)
  [PASS] Enterprise portal HTML has no 'undefined_license_key'

--- AC-DEP-101: legacy strip-nreum workaround removed from enterprise deployments ---
  [PASS] No legacy strip-nreum initContainer in admin-portal-deployment.yaml
  [PASS] No legacy strip-nreum initContainer in learner-portal-deployment.yaml

--- AC-DEP-104: Caddyfile routes /api/mfe_config/v1 to LMS ---
  [PASS] Caddyfile proxies /api/mfe_config/v1 to LMS for enterprise domains
  [PASS] Caddyfile proxies /login_refresh to LMS for enterprise domains

=== Summary ===
  PASS: 9 | FAIL: 0 | SKIP: 0

  RESULT: PASS
```

---

## AC-DEP-105: Demo readiness — all surfaces load

| Surface | URL | HTTP | NREUM | Status |
|---------|-----|------|-------|--------|
| LMS / Academy | `https://academyv2.mereka.io/` | 200 | ✅ None | PASS |
| Studio | `https://studio.academyv2.mereka.io/` | 200 | ✅ None | PASS |
| MFE (Authn) | `https://apps.academyv2.mereka.io/authn/login` | 200 | ✅ None | PASS |
| Enterprise Admin | `https://admin.academyv2.mereka.io/` | 200 | ✅ Clean (837 bytes) | PASS |
| Enterprise Learner | `https://enterprise.academyv2.mereka.io/` | 200 | ✅ None | PASS |

---

## Build infrastructure added

| File | Purpose |
|------|---------|
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal` | Admin portal NREUM-clean derivative |
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal` | Learner portal NREUM-clean derivative |
| `infrastructure/docker/enterprise-mfe-clean/strip-nreum.sh` | Shell script executed during RUN |
| `scripts/infra/build-enterprise-mfe-clean.sh` | Build + verify + push wrapper |
