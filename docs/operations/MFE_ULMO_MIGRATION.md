# MFE Ulmo Migration Tracking

**Status**: COMPLETE (as of 2026-02-20, bead mereka-lms-2s47)
**Target release**: `release/ulmo.1` / `open-release/ulmo.1`
**Tutor version**: 21.0.0 (Ulmo)
**Verification script**: `scripts/qa/verify-mfe-ulmo-migration.sh`

---

## MFE Inventory and Migration Status

| MFE | GitHub Repo | Port | Git Ref (target) | Status |
|-----|-------------|------|------------------|--------|
| admin-console | `openedx/frontend-app-admin-console` | 2025 | `release/ulmo` | DONE |
| authn | `openedx/frontend-app-authn` | 1999 | `release/ulmo.1` | DONE |
| authoring | `openedx/frontend-app-authoring` | 2001 | `release/ulmo.1` | DONE |
| account | `openedx/frontend-app-account` | 1997 | `release/ulmo.1` | DONE |
| communications | `openedx/frontend-app-communications` | 1984 | `release/ulmo.1` | DONE |
| discussions | `openedx/frontend-app-discussions` | 2002 | `release/ulmo.1` | DONE |
| gradebook | `openedx/frontend-app-gradebook` | 1994 | `release/ulmo.1` | DONE |
| learner-dashboard | `openedx/frontend-app-learner-dashboard` | 1996 | `release/ulmo.1` | DONE |
| learning | `openedx/frontend-app-learning` | 2000 | `release/ulmo.1` | DONE |
| ora-grading | `openedx/frontend-app-ora-grading` | 1993 | `release/ulmo.1` | DONE |
| profile | `openedx/frontend-app-profile` | 1995 | `release/ulmo.1` | DONE |
| learner-record | `openedx/frontend-app-learner-record` | 1990 | `release/ulmo.1` | DONE |

All 12 MFEs are confirmed on `release/ulmo.1` in `infrastructure/tutor/mfe-build/Dockerfile`.

---

## Version Matrix

| Component | Pre-Ulmo (Redwood) | Target (Ulmo) | Status |
|-----------|-------------------|---------------|--------|
| MFE git refs | `open-release/redwood.3` | `release/ulmo.1` | DONE |
| Atlas translations | `open-release/redwood.3` | `open-release/ulmo.1` | DONE |
| Brand package | `^2.1.1` | `^2.4.3` | DONE |
| Node base image | `node:18-bullseye-slim` | `node:18-bullseye-slim` | unchanged |
| Paragon | v22.x | v23.x | via brand pkg |
| `frontend-plugin-framework` | `^1.8.0` | `^1.8.0` | unchanged |
| `OPENEDX_COMMON_VERSION` | `open-release/redwood.3` | patched to ulmo via `apply-patches.sh` | DONE |

---

## Breaking Changes: Redwood to Ulmo

### 1. MFE plugin slot system (Ulmo)

Ulmo ships the `@openedx/frontend-plugin-framework` slot system as standard.
All MFEs now require `env.config.jsx` to be present at build time.

**Impact**: `env.config.jsx` is COPY'd into each MFE stage by `apply-patches.sh`.
Missing this file causes a webpack build error in authn and learning.

**Fix in place**: `ensure_mfe_plugin_framework_dependency()` in `apply-patches.sh`.

### 2. Brand package version (Paragon v23 tokens)

The Indigo brand package at `^2.1.1` (Paragon v22) misaligns CSS design tokens
with Ulmo MFEs bundling Paragon v23. Symptoms: broken button colors, missing
spacing tokens, wrong font weights in the Mereka theme.

**Fix in place**: `ensure_mfe_brand_ulmo_version()` patches all `npm install` lines
to `@edly-io/indigo-brand-openedx@^2.4.3`.

**Pending**: Migration from `@edly-io/indigo-brand-openedx` to `@openedx/brand-openedx`
Design Tokens (tracked separately in `docs/operations/DEPLOYMENT_ISSUES_AND_ROADMAP.md`).

### 3. Discussions MFE webpack prompt (fixed upstream in Ulmo)

In Redwood, `frontend-app-discussions` triggered an interactive `npx` prompt
during `npm install`, which broke non-TTY Docker builds.

**Workaround was**: `CI=1` environment variable or `--yes` flag injection.

**Ulmo fix**: The prompt was removed upstream. The guard function
`ensure_mfe_discussions_webpack_noninteractive()` remains in `apply-patches.sh`
as a no-op safety net.

### 4. `admin-console` uses `release/ulmo` (not `release/ulmo.1`)

`frontend-app-admin-console` only publishes to `release/ulmo` (no `.1` point release).
All other MFEs use `release/ulmo.1`.

**Impact**: The snapshot Dockerfile uses `release/ulmo` for admin-console. This is
correct — do not change it to `release/ulmo.1`.

### 5. `npm clean-install` retry logic required

Ulmo MFEs have deeper dependency trees and the upstream npm registry can time out
mid-build. The snapshot Dockerfile includes a 3-attempt retry loop for each MFE:

```dockerfile
bash -o pipefail -c 'for attempt in 1 2 3; do npm clean-install ... && exit 0; ...; done; exit 1'
```

Without this, builds fail transiently in CI at 30–40 min when the npm registry
returns 503s.

---

## Build Instructions

### Full MFE image build

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"

# Step 1: ensure patches are current
./infrastructure/tutor/apply-patches.sh

# Step 2: verify snapshot matches expected state
./scripts/qa/verify-mfe-ulmo-migration.sh --offline

# Step 3: build (uv-pip workaround required for Ulmo)
tutor images build mfe -a PIP_COMMAND=pip

# Step 4: push to registry
tutor images push mfe

# Step 5: update snapshot
cp tutor_env/env/plugins/mfe/build/mfe/Dockerfile infrastructure/tutor/mfe-build/Dockerfile
git add infrastructure/tutor/mfe-build/Dockerfile
git commit -m "chore(mfe): snapshot Dockerfile after apply-patches.sh run"
```

### Build a single MFE target

BuildKit allows building individual stages. To build only the `authn` production image:

```bash
docker buildx build \
  --target authn-prod \
  --tag asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:test \
  -f infrastructure/tutor/mfe-build/Dockerfile \
  infrastructure/tutor/mfe-build/
```

### Update production image tag

After a successful build and push, update the tag in kustomization:

```bash
NEW_TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
# Edit deploy/k8s/overlays/production/kustomization.yaml
# Set newTag: $NEW_TAG for both openedx-mfe entries
git add deploy/k8s/overlays/production/kustomization.yaml
git commit -m "chore(k8s): update MFE image tag to $NEW_TAG"
```

---

## Rollback Procedure

### Rollback to previous MFE image tag

1. Find the last known-good tag in `deploy/k8s/overlays/production/kustomization.yaml`
   git history:

   ```bash
   git log --oneline -- deploy/k8s/overlays/production/kustomization.yaml | head -10
   ```

2. Revert the kustomization to the previous tag:

   ```bash
   git show HEAD~1:deploy/k8s/overlays/production/kustomization.yaml \
     | grep -A3 "openedx-mfe" | grep "newTag:"
   # Edit kustomization.yaml with the old tag
   git add deploy/k8s/overlays/production/kustomization.yaml
   git commit -m "revert(k8s): rollback MFE image tag to <old-tag>"
   ```

3. ArgoCD will reconcile within 3 minutes. Verify:

   ```bash
   kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe -w
   ```

### Rollback MFE source refs in Dockerfile snapshot

If a new ulmo point release breaks builds, revert to the previous snapshot:

```bash
git revert HEAD  # if the last commit was the snapshot update
# OR
git checkout HEAD~1 -- infrastructure/tutor/mfe-build/Dockerfile
git commit -m "revert(mfe): rollback Dockerfile snapshot to previous ulmo ref"
```

Then rebuild with `tutor images build mfe -a PIP_COMMAND=pip`.

---

## Verification

Run the offline verification to confirm migration state:

```bash
./scripts/qa/verify-mfe-ulmo-migration.sh --offline
```

Expected output when migration is complete:

```
MFE Ulmo Migration Verification (offline)
...
PASS: ensure_mfe_ulmo_source_refs() present in apply-patches.sh
PASS: apply-patches.sh patches ADD refs to release/ulmo.1
PASS: Snapshot Dockerfile: no stale release refs
PASS: All MFE apps use release/ulmo.1 (12 refs found, expected >=11)
PASS: MFE base image uses Node 18+: FROM docker.io/node:18-bullseye-slim AS base
PASS: All atlas pulls use open-release/ulmo.1 (12 found)
PASS: Brand upgraded to ulmo-compatible version (12 installs, expected >=11)
PASS: Production MFE image tag is pinned: 1c66529-20260220023917
...
MFE Ulmo Migration (offline): N PASS / 0 FAIL / N SKIP
```

Run online checks against the live cluster (requires cluster access):

```bash
NAMESPACE=mereka-lms \
MFE_HOST=apps.academyv2.mereka.io \
  ./scripts/qa/verify-mfe-ulmo-migration.sh --online
```

---

## Pending Work

| Item | Priority | Notes |
|------|----------|-------|
| Brand migration: `indigo-brand-openedx` -> `@openedx/brand-openedx` Design Tokens | P2 | Tracked in `DEPLOYMENT_ISSUES_AND_ROADMAP.md`. Requires `--legacy-peer-deps` removal. |
| Remove `--legacy-peer-deps` after brand migration | P2 | Blocked on brand migration above. |
| Evaluate Ulmo.2 point release tags when published | P3 | Check https://github.com/openedx/frontend-app-learning/tags |
