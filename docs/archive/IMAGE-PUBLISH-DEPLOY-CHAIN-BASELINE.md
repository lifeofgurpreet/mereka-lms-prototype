# Image Build / Publish / Deploy Chain Baseline

> Lane D2 artifact. Snapshot: 2026-03-13.

## Chain Architecture

```
mereka-lms main (source)
  → push to main touching infrastructure/tutor/** or assets/branding/**
    → build-tutor-images.yml (GitHub Actions on mereka-k8s-heavy-builders)
      → tutor images build openedx → GHCR ghcr.io/.../openedx:<sha>
      → tutor images build mfe    → GHCR ghcr.io/.../mfe:<sha>
        → (optional) Update GitOps step → PR to bbi-infrastructure
          → ArgoCD auto-sync to rke2-nonprod
```

## Build Trigger (CRITICAL FINDING)

The `build-tutor-images.yml` workflow only triggers on push to main with paths:
- `infrastructure/tutor/**`
- `assets/branding/**`
- `.github/workflows/build-tutor-images.yml`

**Changes to `deploy/k8s/`, `scripts/`, `services/`, or any other path do NOT trigger image builds.**
This is by design (runtime code changes don't affect the Docker image), but it means:
- PR #898 (multisite settings in `deploy/k8s/base/apps/openedx/settings/`) will never trigger a build
- Only changes to Tutor patches, plugins, themes, or branding trigger builds
- Manual `workflow_dispatch` is available for on-demand builds

## Current State

| Image | Live Tag | GHCR Latest | Main SHA | Status |
|-------|----------|-------------|----------|--------|
| openedx | `3b79796f` | `3b79796f` (2026-03-11) | `d24010e0` (6 ahead) | **STALE** — no new image since PR #844 |
| mfe | `6233c55b` | `6233c55b` (2026-03-13) | `b1d055e1` (4 ahead, not on main) | **AHEAD** — from non-main branch |
| enterprise-admin-portal | `c5e9454b-20260311` | matches | `c5e9454b` | CURRENT |
| enterprise-learner-portal | `c5e9454b-20260311` | matches | `c5e9454b` | CURRENT |

## Blocker: OpenEdX Image Build Broken Since 2026-03-12

### Symptom
3 consecutive openedx build failures:
- `6233c55b` (2026-03-13T02:41) — SASS compile failure
- `b4544215` (2026-03-12T21:50) — SASS compile failure
- `3b79796f` (2026-03-11T02:37) — Build succeeded, GitOps update failed

### Root Cause
PR #892 (`b4544215`, merged 2026-03-12) changed `_tokens.scss` to use CSS4 `rgb(var() / alpha)` syntax.
libsass (Open edX SASS compiler) does not support CSS4 color syntax — it interprets `rgb()` as a
SASS function requiring `$red, $green, $blue` parameters.

Error: `required parameter $green is missing in call to Function rgb` at line 71 of `_tokens.scss`.

### Fix
PR #901 (`fix/sass-libsass-compat`) reverts 5 lines from `rgb(var() / a)` back to `rgba(r, g, b, a)`.
Since the change is in `infrastructure/tutor/**`, merging to main will auto-trigger a new build.

### Chain After Fix
1. Merge PR #901 → triggers `build-tutor-images.yml`
2. OpenEdX image builds with current main code (including PR #898 multisite fix)
3. Image published to GHCR with new SHA tag
4. Human promotes tag in `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
5. ArgoCD syncs new image to rke2-nonprod

## Secondary Issue: PR #898 Multisite Fix Deployment Path

PR #898 merged code to `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py`.
This file is mounted via ConfigMap, NOT baked into the Docker image. Therefore:
- The openedx image rebuild is necessary for other changes, but PR #898's code specifically
  needs the ConfigMap in bbi-infrastructure to reference the new settings file
- The fix requires both: new image (for any Tutor patch changes) AND ConfigMap update

## Promotion is Manual

There is no automated pipeline from GHCR → bbi-infrastructure. Promotion requires:
1. Human edits `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
2. Updates `newTag:` under the `images:` section
3. Merges to bbi-infrastructure main
4. ArgoCD auto-syncs within 3 minutes

The `Update GitOps` step in the build workflow can automate this but it failed on the last
successful build (`3b79796f`) and requires `update_gitops: true` for manual dispatches.
