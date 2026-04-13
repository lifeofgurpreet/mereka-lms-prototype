# MFE Build Snapshot

This directory contains a tracked snapshot of the rendered MFE Dockerfile at
`tutor_env/env/plugins/mfe/build/mfe/Dockerfile`.

## Why this exists

`tutor_env/` is gitignored, so the rendered MFE Dockerfile that drives production
image builds would otherwise have no git history. This snapshot is the reviewable
copy of that rendered authority surface.

## How to update

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save  # regenerates tutor_env/ from Tutor hooks
./scripts/infra/prepare-tutor-build-context.sh --target mfe
git add infrastructure/tutor/mfe-build/Dockerfile
git commit -m "chore(mfe): snapshot Dockerfile after apply-patches.sh run"
```

`prepare-tutor-build-context.sh` is the canonical sync step. It applies the
patch-only build-context mutations and refreshes this snapshot from the rendered
authority path.

## Current state

- MFE apps: all 12 on `release/ulmo.1`
- Atlas translations: `release/ulmo`
- Brand package: local `@edx/brand@file:./brand-mereka`
- Node base image: `docker.io/node:24.11.0-bullseye-slim`
- Rendered-Dockerfile exception: `pull_translations` retry wrapping remains the
  sole documented post-render MFE Dockerfile rewrite in `apply-patches.sh`
  while Atlas/GitHub translation pulls can still fail transiently inside the
  Docker build network.

## Pending migration

- Reduce remaining direct rendered-build-context mutation so the hook layer and
  patch-only sync layer have a cleaner ownership boundary.
- Either replace the `pull_translations` retry wrapper with a hookable/upstream
  surface or retire it once build-path reliability proves it unnecessary.
- Remove `--legacy-peer-deps` once the remaining MFE dependency tree allows it.
