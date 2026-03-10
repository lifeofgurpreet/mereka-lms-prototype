---
id: ADR-012
title: Eliminate Runtime CSS ConfigMap Overlay
decision_status: accepted
decision_type: migration
rollout_state: historical
owner: platform-team
created: '2026-02-10'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next: []
governs: []
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
historical_reason: Completed migration decision retained as historical context.
---

# ADR-012: Eliminate Runtime CSS ConfigMap Overlay

**Status**: Accepted
**Date**: 2026-02-10
**Deciders**: Platform Team
**Related**: [ADR-003: Image Build Pipeline](003-image-build-pipeline.md), [BRANDING_GUARDRAILS.md](../guides/branding/BRANDING_GUARDRAILS.md)

<!-- Last verified: 2026-02-13 -->

## Context

### The Runtime CSS Overlay Pattern

To enable rapid CSS hotfixes without rebuilding the OpenEdX Docker image (~30 min), we introduced a **runtime CSS ConfigMap overlay** in `infrastructure`:

1. A ConfigMap (`openedx-overrides-runtime-css`) containing the full `mereka-overrides.css` content
2. A Kustomize strategic merge patch mounting the ConfigMap at the exact **content-hashed** path inside the container (e.g., `/openedx/staticfiles/mereka/css/mereka-overrides.3ce8308bd75d.css`)
3. The hash in the mount path must match the hash Django's `collectstatic` generated during image build

This pattern had a fatal flaw: **tight cross-repo coupling via a content hash**.

### The Incident (2026-02-10)

A routine OpenEdX image rebuild changed the collectstatic hash from `859d9914b5fe` to `3ce8308bd75d`. The `infrastructure` ConfigMap overlay was not updated and continued mounting CSS at the old hashed path. Result:

- The container served the new (empty-looking) in-image CSS at `3ce8308bd75d`
- The ConfigMap mount at `859d9914b5fe` was silently ignored (no matching request)
- **All Mereka branding disappeared from production** — no pod crashes, no log errors, no alerts
- Dashboard returned 500 (unrelated migration issue compounded diagnosis)
- Manual investigation required to identify the hash mismatch

### Why No Guardrail Caught This

| Guardrail | Catches This? | Why Not |
|-----------|:---:|---------|
| `verify-branding-health.sh` | Partially | Checks source repo CSS, not live hash match |
| `verify-public-branding.sh` | After deploy | Reactive, not preventive |
| `release-openedx-gitops.sh` | No | Updates image tags only, zero CSS awareness |
| `build-tutor-images.yml` CI | No | No post-build hash extraction step |
| `run-branding-gates.sh` | After deploy | Post-deploy check only |
| Pre-commit hooks | No | Different repos, no cross-repo validation |
| ArgoCD sync | No | ConfigMap was valid YAML, just wrong path |
| `BRANDING_GUARDRAILS.md` | Not documented | 10 failure modes, none for cross-repo hash drift |
| `RELEASE_CHECKLIST.md` | No | Branding checks listed as optional |

**Zero automation existed to sync the collectstatic hash between image builds and the infrastructure ConfigMap.**

## Decision

**Eliminate the runtime CSS ConfigMap overlay pattern entirely.** CSS lives in the Docker image, period.

### What Changes

1. **Remove from infrastructure**:
   - Delete `patches/mereka-overrides-runtime.css`
   - Delete `patches/lms-overrides-runtime-mount.yaml`
   - Remove `openedx-overrides-runtime-css` ConfigMapGenerator entry from `kustomization.yaml`
   - Remove the `lms-overrides-runtime-mount.yaml` patch reference from `kustomization.yaml`

2. **Branding changes require image rebuild**:
   - Edit CSS in `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css`
   - Rebuild the `openedx` image (includes `collectstatic` which generates hashed copies)
   - Deploy via `release-openedx-gitops.sh` (updates image tags in both repos)

3. **Mitigate rebuild time with build optimizations** (ADR-013 to follow):
   - BuildKit layer caching with Artifact Registry
   - Separate `collectstatic` layer for CSS-only change fast path
   - Target: CSS-only rebuild from ~30 min to ~10 min

## Consequences

### Positive

- **Eliminates an entire class of silent regressions**: No more cross-repo hash coupling
- **Single source of truth**: CSS lives in one place (theme directory), delivered one way (Docker image)
- **Existing release tooling works unchanged**: `release-openedx-gitops.sh` already handles image tag updates
- **No special knowledge required**: New team members don't need to learn the overlay pattern
- **ArgoCD model simplified**: Fewer ConfigMaps, fewer volume mounts, fewer moving parts
- **Industry standard**: Every major Django/Rails/Next.js deployment bakes static assets into the image

### Negative

- **CSS-only hotfixes require image rebuild**: No more sub-minute CSS patches via ConfigMap
  - Mitigation: Build optimizations (layer caching) reduce CSS-only rebuilds to ~10 min
  - Mitigation: For true emergencies, Caddy can serve an inline `<style>` block via `head-extra.html` ConfigMap (already wired)
- **Slightly longer time-to-fix for branding bugs**: Minutes instead of seconds
  - Acceptable because: branding bugs are cosmetic, not availability-impacting

### Risk Assessment

| Risk | Before (Overlay) | After (Image-only) |
|------|:-:|:-:|
| Silent branding regression | HIGH (happened) | NONE |
| CSS hotfix speed | ~1 min | ~10 min (with caching) |
| Cross-repo coupling | 3 files in 2 repos | 0 |
| Release tooling complexity | Custom hash sync needed | Standard image tag flow |

## Alternatives Considered

### A. Automate Hash Sync

- Extract hash from `collectstatic` during build
- Automatically update infrastructure ConfigMap references
- **Rejected because**: Adds complexity to maintain a pattern that shouldn't exist. Still fragile (what if extraction fails silently?). Treats the symptom, not the disease.

### B. Use Unhashed Path for ConfigMap Mount

- Mount at `/openedx/staticfiles/mereka/css/mereka-overrides.css` (unhashed)
- Browsers would still request hashed path, so this wouldn't work
- **Rejected because**: Django's `ManifestStaticFilesStorage` resolves `static.url()` to the hashed filename. The browser never requests the unhashed path.

### C. Disable Content Hashing

- Switch from `ManifestStaticFilesStorage` to `StaticFilesStorage`
- Mount ConfigMap at unhashed path
- **Rejected because**: Breaks cache busting for all static assets platform-wide. Major regression for production performance.

## References

- [ADR-003: Image Build Pipeline](003-image-build-pipeline.md)
- [BRANDING_GUARDRAILS.md](../guides/branding/BRANDING_GUARDRAILS.md)
- [RELEASE_CHECKLIST.md](../operations/RELEASE_CHECKLIST.md)
- [Django ManifestStaticFilesStorage](https://docs.djangoproject.com/en/4.2/ref/contrib/staticfiles/#manifeststaticfilesstorage)
- Incident: 2026-02-10 production branding regression (commit `6193b75` in infrastructure)
