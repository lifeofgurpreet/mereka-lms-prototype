# Tutor Configuration Safety Guide

<!-- Last verified: 2026-04-14 -->

This guide defines the safe operator path for Tutor config changes.

## Problem Statement

When you run `tutor config save`, Tutor regenerates the rendered environment from
current source hooks. That part is expected. The risk is the layer after that:
the remaining patch-only filesystem sync and tracked rendered build-context
surfaces still need a governed refresh.

If that refresh step is skipped, you can still end up with:

1. rendered Open edX and MFE build context drifting from current source truth
2. stale custom-app or theme-asset mirrors under `tutor_env/`
3. tracked rendered MFE Dockerfile snapshot drift
4. verification failures that look like config regressions but are really
   missing post-render refresh

Common failure modes:

- site instability after a config change
- rendered build contracts falling behind Tutor plugin source
- stale theme or custom-app files lingering after source deletions
- verification failures after a manual `tutor config save`

## Canonical Safety System

### Layer 1: Safe Wrapper

Preferred path:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

What it does:

1. backs up `config.yml`
2. runs `tutor config save`
3. runs `./scripts/infra/prepare-tutor-build-context.sh --target all`
4. verifies the rendered environment
5. restores the backup on failure

This is the default operator front door.

### Layer 2: Verification

Verification command:

```bash
./scripts/infra/verify-tutor-config.sh
```

What it proves:

- multi-site host and CSRF configuration
- MySQL authentication contract
- rendered MFE Node 24 toolchain contract
- MFE cookie domain config
- exactly one rendered `DEFAULT_SITE_THEME = "mereka"` assignment
- custom-app mirror correctness
- theme asset mirror correctness
- absence of rejected `build-optimizations.sh` residue, including stale Tutor Dockerfile-template and docker-compose/settings/assets/nginx/Caddy target scans, the dead MySQL auth compatibility rewrite, stale i18n and pip-bootstrap rewrites, dead compilejsi18n/cherry-pick compatibility rewrites, escaped Google Fonts rewrites, and raw pyenv clone fallbacks
- health endpoints and selected feature flags

Exit codes:

- `0`: verification passed
- `1`: one or more required checks failed

### Layer 3: Pre-Commit Guard

The git hook activates when you stage `tutor_env/` files.

Setup:

```bash
git config --local include.path ../.gitconfig
```

What it does:

1. detects staged Tutor-generated files
2. warns if `config.yml` is staged
3. asks whether you reran the governed Tutor refresh path
4. optionally runs verification
5. blocks the commit if verification fails

The hook now points operators at the real recovery command:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
```

## Workflows

### Recommended Workflow

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
git add tutor_env/
git commit -m "feat: update config"
```

### Manual Workflow

Use this only when you intentionally need the lower-level sequence:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/verify-tutor-config.sh
tutor local restart
git add tutor_env/
git commit -m "feat: update config"
```

### Emergency Recovery

```bash
./scripts/infra/verify-tutor-config.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/verify-tutor-config.sh
tutor local restart
```

## Refresh Responsibilities

The governed refresh path covers:

- rendered Open edX and MFE build-context refresh
- tracked rendered MFE Dockerfile snapshot refresh
- theme and custom-app mirror sync
- remaining patch-only filesystem transforms

The low-level helper:

- `infrastructure/tutor/apply-patches.sh`

still implements part of that refresh, but it is not the default operator front
door. Use it directly only when debugging the patch layer itself.

## Files Realized Or Refreshed

Typical refreshed surfaces include:

- `tutor_env/env/plugins/mfe/build/mfe/Dockerfile`
- `tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx`
- `tutor_env/env/build/openedx/Dockerfile`
- `tutor_env/env/apps/caddy/Caddyfile`
- `tutor_env/env/apps/nginx/lms.conf`
- `tutor_env/env/apps/openedx/settings/lms/production.py`
- `tutor_env/env/build/openedx/themes/mereka/`
- `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`

## Troubleshooting

### Verification Failed

```bash
./scripts/infra/verify-tutor-config.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/verify-tutor-config.sh
```

If it still fails, inspect Tutor/plugin source drift before changing docs or
generated outputs.

### Site Down After Config Change

```bash
./scripts/infra/verify-tutor-config.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
tutor local restart
tutor local logs --tail=100 lms
```

### Git Hook Not Running

```bash
git config --local core.hooksPath
git config --local include.path ../.gitconfig
ls -l .githooks/pre-tutor-config
```

## Related Documentation

- `docs/README.md`
- `docs/meta/standing-orders/README.md`
- `docs/ops/runbooks/TROUBLESHOOTING.md`
- `scripts/infra/tutor-config-save.sh`
- `scripts/infra/prepare-tutor-build-context.sh`
- `scripts/infra/verify-tutor-config.sh`
- `infrastructure/tutor/apply-patches.sh`
- `.githooks/pre-tutor-config`

## Quick Reference

Safe config change:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

Manual verification:

```bash
./scripts/infra/verify-tutor-config.sh
```

Emergency refresh:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
```

Hook setup:

```bash
git config --local include.path ../.gitconfig
```
