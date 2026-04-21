# Enterprise MFE Dockerfile Maintenance
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

_Last updated: 2026-02-27_

## Overview

Enterprise portals built on Open edX use micro-frontends (MFEs) that require
customizations beyond what upstream Tutor ships. The active contract now lives
primarily in Tutor plugin hooks under
`infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py`, with
`scripts/infra/prepare-tutor-build-context.sh --target mfe` as the canonical
operator entrypoint for the remaining patch-only build-context sync and tracked
rendered snapshot refresh.

This document explains what diverges, why it diverges, and the step-by-step
process to maintain those customizations across Tutor version bumps.

## What Enterprise MFE Customizations Exist

The following categories of customizations are currently applied:

### 1. Node 24 Toolchain Lock

Upstream Tutor templates target different Node major versions depending on the
release track (Node 12 → 18 → 24+). We pin all MFE build stages to
`node:24.11.0-bullseye-slim` and extend the system package list with the full C++
build toolchain required by native Node modules:

```
gcc g++ git libgl1 libxi6 make python3 python3-distutils
```

Without this, native addon compilation fails silently and webpack output is
broken.

### 2. Webpack Memory Limit (NODE_OPTIONS)

The Open edX edx-platform webpack build is memory-intensive. We raise the V8
heap cap to 6 GB:

```
ENV NODE_OPTIONS="--max-old-space-size=6144"
```

Upstream ships `--max-old-space-size=1536`, which causes OOM kills during the
Ulmo asset pipeline on machines with 12 GB Docker RAM.

### 3. Custom Footer Component (Mereka Brand)

The repo-owned `mereka/env.config.jsx` template and rendered MFE Dockerfile now ensure:

- Copy `mereka/theme-source/` theme assets into `/openedx/app/theme-source` at build time
- Copy `mereka/brand-mereka/` into `/openedx/app/brand-mereka` and install it as `@edx/brand`
- Keep `theme-source/mereka.scss` available to the build via the repo-owned config path

The governed prepare path still refreshes the remaining MFE build-context asset
sync, but stale ad hoc production-stage theme-copy surgery has been removed.

### 4. Indigo Brand Package Pin (Ulmo)

The `@edx/brand` alias now installs the local package
`@edx/brand@file:./brand-mereka`, keeping the brand package in the repo-owned
build context instead of pinning an external Indigo npm package.

### 5. NPM Resilience and Fallback Logic

`npm clean-install` calls in the MFE Dockerfile are wrapped in a retry loop
with an `npm install` fallback. This unblocks builds when upstream repos ship
with `package-lock.json` drift that breaks `npm ci`-style commands.

### 6. Course-Authoring Directory Symlink

Tutor MFE plugin expects the build output at `course-authoring/` but the
upstream repo produces `frontend-app-course-authoring/`. A symlink is created
during the Docker build stage to align both paths.

### 7. MFE Discussions Webpack Non-Interactive Fix

`frontend-app-discussions` prompts interactively for webpack installation in
non-TTY Docker builds. The patch forces a non-interactive path.

### 8. Rendered Authority Snapshot And Prereq Guard

The tracked file `infrastructure/tutor/mfe-build/Dockerfile` is now the
reviewable snapshot of the rendered authority path
`tutor_env/env/plugins/mfe/build/mfe/Dockerfile`. The prereq guard
`scripts/qa/verify-mfe-build-prereqs.sh` enforces snapshot parity and confirms
that stale production-stage theme-copy surgery is absent.

### 9. Frontend Plugin Framework Dependency

`@openedx/frontend-plugin-framework@^1.8.0` is installed with
`--legacy-peer-deps` in all MFE stages to satisfy plugin slot wiring without
peer dependency resolution failures.

### 10. Admin Console Redux Dependencies

`react-redux` and `redux` are installed in the `admin-console-common` stage
to satisfy `OptionalReduxProvider` imports from `frontend-platform`.

## Why They Diverge

`tutor config save` regenerates all template files from the installed `tutor`
and `tutormfe` Python packages. Any in-place edits to `tutor_env/` or the
upstream package templates are overwritten.

`tutor config save` regenerates the rendered MFE build context from Tutor hooks.
After that, `scripts/infra/prepare-tutor-build-context.sh --target mfe` is the
canonical sync step:

- verify the rendered Dockerfile is fresh relative to plugin source
- run the remaining patch-only build-context sync
- refresh the tracked rendered Dockerfile snapshot

Treat `infrastructure/tutor/apply-patches.sh` as the low-level helper behind
that workflow, not as the primary MFE authority surface.

## Maintenance Checklist (Run Before Each Tutor Upgrade)

Follow these steps when upgrading Tutor to a new major version (e.g.,
Redwood 18.x → Ulmo 21.x):

### Step 1 — Save the Current Customized Dockerfile

```bash
cp tutor_env/env/plugins/mfe/build/mfe/Dockerfile \
   /tmp/mfe-dockerfile-before.txt
```

Also save the upstream template path for reference:

```bash
python3 - <<'PY'
from pathlib import Path
import tutormfe
print(Path(tutormfe.__file__).parent / "templates" / "mfe" / "build" / "mfe" / "Dockerfile")
PY
```

### Step 2 — Upgrade Tutor and Run Config Save

```bash
pip install "tutor==<new-version>" tutor-mfe==<new-mfe-version>
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save
```

Do NOT run the governed prepare path yet. Capture the raw new upstream output:

```bash
cp tutor_env/env/plugins/mfe/build/mfe/Dockerfile \
   /tmp/mfe-dockerfile-upstream-new.txt
```

### Step 3 — Diff Old Custom vs New Upstream Template

```bash
diff /tmp/mfe-dockerfile-before.txt /tmp/mfe-dockerfile-upstream-new.txt
```

Focus on:

- Base `FROM` image — has the Node major version changed?
- Package install lines — any new system packages added or removed?
- Build stage names — have stage names been renamed (e.g., `authn-common`)?
- `RUN` ordering — have `npm clean-install` lines moved?
- New stages — have any new MFE stages been added?

Also diff the rendered `env.config.jsx` output against the repo-owned runtime source:

```bash
diff <saved-env.config.jsx> infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js
```

### Step 4 — Re-Apply Customizations to New Template

Update the relevant hook or patch sources to accommodate any structural changes
found in Step 3. Common adjustments:

| Change found in diff | Patch function to update |
|---|---|
| Node major version changed | `_mereka_lms/mfe_dockerfile.py` |
| Package list changed | `_mereka_lms/mfe_dockerfile.py` |
| Stage rename or rendered helper-file drift | `_mereka_lms/mfe_dockerfile.py` + rendered snapshot parity verifier |
| `npm clean-install` line changed | `_mereka_lms/mfe_dockerfile.py` |
| `@edx/brand` pin changed | `_mereka_lms/mfe_dockerfile.py` |
| rendered asset mirror drift | `patches/build-optimizations.sh` |

Run the governed refresh against the new rendered template:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target mfe
```

Verify the refreshed contract correctly:

```bash
./scripts/qa/verify-mfe-build-prereqs.sh
```

### Step 5 — Build and Test

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build mfe
tutor local restart
```

For a full build with no cached layers (required for major version bumps):

```bash
tutor images build mfe --no-cache
```

Expected build time: 15–20 minutes on a machine with 12 GB+ Docker RAM.

### Step 6 — Verify Branding, Routes, and Config Endpoints

After `tutor local restart`:

```bash
# MFE config endpoint
curl -s http://apps.localhost/authn/login | grep -i mereka

# Verify footer renders
curl -s http://localhost | grep -i footer

# Confirm SESSION_COOKIE_DOMAIN set in MFE container
docker exec tutor_local_mfe_1 env | grep COOKIE_DOMAIN

# Quick route smoke test
./scripts/qa/smoke-test.sh
```

Check that:
- Mereka footer component is visible on the dashboard MFE
- Login page (`/authn/login`) renders without blank-screen errors
- Course catalog and authn routes resolve correctly
- Browser console has no `NODE_OPTIONS` or webpack memory errors in build logs

## Rollback Procedure

If the new MFE image produces broken behavior:

### 1. Identify the Last Known Good Image Tag

```bash
gcloud artifacts docker images list \
  ghcr.io/biji-biji-initiative/mereka-lms/mfe \
  --include-tags \
  --format="table(tags, createTime)" \
  --sort-by="~createTime" \
  --limit=10
```

### 2. Pin the Previous Tag in K8s Overlay

Edit `deploy/k8s/overlays/production/kustomization.yaml`:

```yaml
images:
  - name: mfe
    newName: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    newTag: <last-known-good-sha>
```

Commit and push — ArgoCD will reconcile automatically within 3 minutes.

### 3. Verify Rollback

```bash
kubectl rollout status deployment/mfe -n mereka-lms
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe
```

### 4. Document in Incident Log

Open a bead or postmortem entry documenting:
- Which Tutor version caused the regression
- Which patch function failed to account for upstream changes
- Fix applied and re-test evidence

## Schedule

Per **ADR-019** (`docs/adr/019-tutor-upgrade-policy.md`), Tutor upgrades are
evaluated quarterly. Run this maintenance checklist:

- Before any Tutor patch release (minor version bump within the same track)
- Mandatory before any major version upgrade (e.g., Redwood → Ulmo)
- After any update to the `tutormfe` Python package

Subscribe to the Open edX forum release announcements thread:
https://discuss.openedx.org/

## Related Files

| File | Purpose |
|---|---|
| `infrastructure/tutor/apply-patches.sh` | Low-level patch-only helper for remaining rendered build-context sync |
| `scripts/qa/verify-mfe-build-prereqs.sh` | Active guard for rendered Dockerfile parity and snapshot truth |
| `scripts/infra/prepare-tutor-build-context.sh` | Canonical operator entrypoint for MFE build-context refresh and snapshot sync |
| `scripts/infra/tutor-config-save.sh` | Safe wrapper that regenerates env and delegates to the canonical prepare step |
| `scripts/infra/verify-tutor-config.sh` | General Tutor config verification |
| `docs/adr/019-tutor-upgrade-policy.md` | Upgrade cadence and EOL decision |
| `infrastructure/tutor/themes/` | Repo-owned Mereka theme assets |
