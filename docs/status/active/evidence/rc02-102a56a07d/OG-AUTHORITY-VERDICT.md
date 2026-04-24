# Authority Verdict: `overlays/dev` vs `overlays/profiles/dev`

**Date:** 2026-04-18
**Scope:** `apps/mereka-lms/overlays/dev/kustomization.yaml` in `bbi-infrastructure`.

## Verdict: HARMLESS STALE DEBT

The stale image pin (`newTag: dfbe7ef31806` / `digest: sha256:87c04e6d…`) in
`apps/mereka-lms/overlays/dev/kustomization.yaml` is **shadowed** by
`apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` (which pins the current
live digest `d17ae77f…` for commit `102a56a07d`). The stale parent pin is dead
configuration, not an active authority on the release path.

## Evidence Chain

### 1. ArgoCD Consumer
- Live cluster is served by Application `mereka-lms-dev`, watching
  `source.path: apps/mereka-lms/overlays/profiles/dev`.
- No Application or ApplicationSet resolves to `apps/mereka-lms/overlays/dev`
  directly.

### 2. Kustomize Composition
- `overlays/profiles/dev/kustomization.yaml` declares
  `resources: [../../dev]` — includes the stale parent overlay.
- `profiles/dev` then **overrides** the openedx image `newTag` / `digest` to the
  current artifact (`102a56a07d…` / `sha256:d17ae77f…`).
- Kustomize precedence: child patches override parent pins. Rendered manifest
  ships `102a56a07d…`, not `dfbe7ef31806`.

### 3. Runtime Truth
- Deployment spec digest: `sha256:d17ae77f…` (matches `profiles/dev` override).
- Live pod `imageID`: `sha256:d17ae77f…` (matches deployment spec).
- Digest chain agrees end-to-end. Stale parent pin never reaches the cluster.

## Non-Action This Cycle

Do **not** edit `overlays/dev/kustomization.yaml` as part of this charter. A
future cleanup PR should sync the parent pin with current values for readability
and to eliminate the "when did this last ship?" confusion a future operator will
have. It is not a release-correctness issue.

## Recommended Follow-On

Small, non-blocking cleanup PR (future cycle):
- `sed`-sync `overlays/dev/kustomization.yaml` image block from whatever
  `overlays/profiles/dev/kustomization.yaml` currently pins, OR
- Remove the `images:` block from `overlays/dev` entirely and let
  `profiles/dev`/`profiles/staging`/`profiles/production` be the sole authority
  on image pins.

Either approach eliminates the duplicate authority surface. Prefer the second
because it removes the opportunity for future drift.

## Credit

Explorer agent a7c1167c5b8af5ae8 produced the consumer trace and the kustomize
precedence analysis that underpins this verdict.
