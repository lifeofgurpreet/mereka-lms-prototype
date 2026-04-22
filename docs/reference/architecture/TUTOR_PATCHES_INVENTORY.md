# Tutor Patches Inventory

This document classifies the active Tutor post-render compatibility layer.
It is an authority ledger, not a permission slip to keep growing bash rewrites.

**Maintained as of**: 2026-04-23

## Classification Key

| Label | Meaning |
|---|---|
| `SOURCE_OWNED` | The durable behavior lives in a Tutor plugin hook, config default, source file, or bake/HCL contract. |
| `FILESYSTEM_SYNC` | The patch copies repo-owned files into a rendered Tutor build context. Tutor hooks cannot create those files. |
| `TEMPORARY_COMPATIBILITY_LAYER` | The patch changes exact rendered output because Tutor 21/tutormfe does not expose a source hook for the needed line or file. Every item needs a guard and retirement trigger. |
| `AUTHORITY_CORRECTION` | The patch removes or corrects a rendered line whose upstream assumption is now false for our supported source refs. |
| `MIGRATION_GUARD` | The patch strips stale upstream/old-render residue so retired behavior does not become live again. |
| `REMOVED` | Historical patch authority is gone from the active patch chain. |

## Active Patch Chain

`infrastructure/tutor/apply-patches.sh` is the only active front door for these modules.
Operator-facing build prep should use:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target <openedx|mfe|all>
```

The active chain is:

| Module | LOC | Target | Classification | Why It Still Exists | Guard / Proof |
|---|---:|---|---|---|---|
| `_common.sh` | 107 | harness | N/A | Discovers Tutor/tutormfe template paths for patch modules. | sourced by `apply-patches.sh` |
| `mysql-root-host.sh` | 37 | local compose | `TEMPORARY_COMPATIBILITY_LAYER` | Local Tutor MySQL needs `MYSQL_ROOT_HOST: "%"`, and Tutor config does not expose the exact rendered local compose insertion. | `verify-cold-start-onboarding-contract.sh`, local bootstrap proof |
| `webpack-memory.sh` | 101 | Open edX | `MIGRATION_GUARD` + bounded compatibility | Fresh memory/runtime settings are source-owned by plugin hooks; bash only deduplicates stale renders and keeps legacy webpack normalization. | `verify-tutor-config.sh`, render proof |
| `dependency-image-mirrors.sh` | 89 | Open edX + MFE | `TEMPORARY_COMPATIBILITY_LAYER` | Tutor 21/tutormfe emit hardcoded Docker Hub dependency refs before source hooks can own them. The patch only changes acquisition registry, not artifact semantics. | fixture tests, render-delta contract, preflight MFE/OpenEdX checks |
| `openedx-obsolete-activation-key-patch-removal.sh` | 45 | Open edX | `AUTHORITY_CORRECTION` | Tutor 21 still emits the activation_key `git am` layer even though upstream `release/ulmo` already contains commit `21cead238466ca398ba368518f1d3288431d68f4`. The patch removes only that obsolete replay line. | fixture tests, preflight raw-vs-patched delta, cold-start proof |
| `build-optimizations.sh` | 230 | Open edX | `TEMPORARY_COMPATIBILITY_LAYER` + intentional build semantics | Residual cold-build compatibility and translation preflight/wrapper surgery. It must stay bounded by the mutation ledger below. | `verify-build-optimizations-render-delta-contract.sh`, fixture tests, benchmark proof |
| `brand-package.sh` | 35 | MFE | `FILESYSTEM_SYNC` | Copies repo-owned OEP-48 `brand-mereka` package and compiled theme CSS into the rendered MFE build context. | `verify-oep48-brand-package.sh`, MFE build prereq checks |
| `sync-footer-assets.sh` | 41 | MFE | `FILESYSTEM_SYNC` | Copies repo-owned theme SCSS/fonts into `mereka/theme-source`; JSX and slot wiring are source-owned by the plugin. | `verify-footer-parity.sh`, `verify-brand-parity.sh` |
| `mfe-slot-ownership.sh` | 15 | MFE | `MIGRATION_GUARD` | Strips stale Tutor Indigo slot ownership from generated `env.config.jsx` so retired external ownership cannot become active. | `verify-mfe-build-prereqs.sh`, footer slot contracts |
| `mfe-prune-deprecated-shells.sh` | 17 | MFE | `MIGRATION_GUARD` | Removes generated legacy MFE shell/Caddy residue outside the active estate. | `test-mfe-prune-deprecated-shells.sh` |
| `mfe-npm-install-resilience.sh` | 71 | MFE | `TEMPORARY_COMPATIBILITY_LAYER` | Wraps the exact rendered npm install layer with retry/fallback behavior until tutormfe exposes this line as source-owned config. | golden/idempotence/fail-loud fixture tests |
| `apply-patches.sh` inline `wrap_mfe_pull_translations_retry` | inline | MFE | `TEMPORARY_COMPATIBILITY_LAYER` | Rewrites rendered Atlas translation pull lines with retry loops to avoid late cold-build failure on transient GitHub/DNS errors. | preflight, Build Tutor Images proof |

`enterprise-template-guard.sh` exists in `patches/` but is not sourced by
`apply-patches.sh`; it is not active authority until a future PR wires it with
docs, tests, and a retirement trigger.

## Source-Owned Areas

These behaviors must not migrate back into bash:

| Source-Owned Surface | Owner |
|---|---|
| LMS/CMS production settings, hosts, CSRF, CSP, metrics app wiring | `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` and related plugin modules |
| Discovery local init partner/API URL convergence | `infrastructure/tutor/plugins/_mereka_lms/discovery_init.py`; source/render guard: `scripts/qa/test-discovery-init-task-contract.sh` |
| LMS runtime theme templates, Mako fallback behavior, and template-safe tenant URL helpers | `infrastructure/tutor/themes/mereka/lms/templates/**`, `infrastructure/tutor/custom-apps/openedx_tenant_cache/runtime_urls.py`, plus `scripts/qa/verify-mako-template-syntax.sh` |
| Open edX Dockerfile additive hooks for repo dependencies and runtime sentinels | `infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py` |
| MFE Dockerfile source hooks, local brand package references, runtime theme copy, authn route handling | `infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py` |
| MFE runtime theme/footer/slot config | `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py` and `mereka_lms_mfe_slots.py` |
| Bake cache semantics, fast/proof build profiles, image labels | `docker-bake.hcl` and `scripts/infra/build-*.sh` helpers |
| Production deployment realization | GitHub Build Tutor Images workflow plus GitOps promotion scripts |

## Remaining `build-optimizations.sh` Mutation Ledger

This file is a controlled compatibility layer, not a second generator.
The intended J-exit chain is:

```text
raw Tutor render -> explicit allowed delta -> artifact
```

Do not add another post-render mutation unless the change is classified as
`authority correction`, `obsolete expectation removal`, `temporary compatibility layer`,
or `intentional architecture change`, and this ledger plus
`infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml` are updated in
the same PR.

| Mutation | Authority Class | Why It Remains Post-Render | Retirement Trigger | Guard |
|---|---|---|---|---|
| `base-assets-no-build-isolation` | temporary compatibility layer | Tutor 21 emits the base/assets install line before a local hook can replace it. | Tutor/upstream exposes a source hook or bake-owned dependency install stage. | render-delta contract |
| `uwsgi-plain-pip-fallback` | temporary compatibility layer | The rendered `uv pip` path still fails this dependency under cold-build conditions. | Dependency install semantics move to a source hook, upstream image, or bake stage with equivalent proof. | render-delta contract |
| `production-build-profile-arg` | intentional architecture change | Repo-owned proof/fast build profile behavior is needed in the production translation stage. | Bake/HCL owns the profile contract directly and render no longer needs Dockerfile arg injection. | cold-start contract, benchmark proof |
| `translation-settings-preflight` | intentional architecture change | Translation discovery fails late without preflight validation of repo-owned settings. | Translation preflight becomes source-owned through a Tutor hook or upstream-supported build step. | cold-start contract, benchmark proof |
| `advanced-xblocks-production-copy` | intentional architecture change | Translation discovery needs the advanced XBlock source tree before rendered production translation commands. | XBlock source placement becomes bake/source-hook owned before translation discovery. | cold-start contract, benchmark proof |
| `fast-profile-translation-wrappers` | temporary compatibility layer | The wrapper replaces existing rendered translation command behavior; current Tutor hooks cannot replace those lines cleanly. | Bake/HCL or a source hook owns fast/proof translation semantics without command-line text rewrites. | render-delta contract, benchmark proof |

Owner: platform build authority lane. Review date: 2026-04-27 or before any PR
that changes `build-optimizations.sh`.

## Remaining `dependency-image-mirrors.sh` Mutation Ledger

Allowed render-delta id: `dependency-image-mirror-normalization`.

| Mutation | Authority Class | Why It Remains Post-Render | Retirement Trigger | Guard |
|---|---|---|---|---|
| Dockerfile frontend mirror: `# syntax=mirror.gcr.io/docker/dockerfile:1` | temporary compatibility layer | The syntax directive is emitted by upstream templates and resolved before normal build stages. | Tutor/tutormfe exposes a source setting for Dockerfile frontend image, or authenticated Docker Hub acquisition is proven for local/CI cold starts. | fixture tests, preflight |
| Open edX Ubuntu base mirror | temporary compatibility layer | Tutor 21 emits `FROM docker.io/ubuntu:22.04 AS minimal`; no config key owns this base ref. | Tutor exposes a base-image config/hook or upstream switches to non-rate-limited acquisition. | same |
| Open edX dockerize helper mirror | temporary compatibility layer | Tutor 21 emits `COPY --from=docker.io/powerman/dockerize:0.19.0`; no config key owns this helper ref. | Tutor exposes helper-image config/hook or upstream switches to non-rate-limited acquisition. | same |
| MFE Node base mirror | temporary compatibility layer | tutormfe 21 emits `FROM docker.io/node:24.11.0-bullseye-slim AS base`; no hook exists before the base stage. | tutormfe exposes a base-image setting/hook or upstream switches to non-rate-limited acquisition. | same |
| MFE Caddy production base mirror | temporary compatibility layer | tutormfe 21 emits `FROM docker.io/caddy:2.7.4 AS production`; no hook owns this runtime base selector. | tutormfe exposes a Caddy runtime image setting/hook or upstream switches to non-rate-limited acquisition. | same |

## Removed Or Historical Patch Authority

These files are not active patch authority:

| Historical Patch | Current State |
|---|---|
| `mysql-auth.sh` | Removed. Relevant local compose residual is now `mysql-root-host.sh`; app settings moved to source hooks. |
| `mfe-node.sh` | Removed. Durable MFE Dockerfile behavior lives in plugin hooks plus named MFE compatibility modules. |
| `domain-names.sh` | Removed. Domains are source-owned by plugin settings/Caddy/nginx hooks and GitOps overlays. |
| `csrf-origins.sh` | Removed. CSRF origins are source-owned in LMS settings hooks. |
| `footer-component.sh` | Removed/renamed. Active asset sync is `sync-footer-assets.sh`; footer JSX and slots are plugin-owned. |
| `prometheus-metrics.sh` | Removed. Metrics wiring is source-owned by plugin settings/nginx hooks and K8s monitors. |
| `mongodb-atlas.sh` | Removed. Atlas support is source-owned in plugin Dockerfile/settings surfaces. |
| `security-hardening.sh` | Removed. Django settings live in source hooks; Caddy hardening lives in K8s Caddy config. |

## Dead Or Retired Hook Names

Do not re-register these as live source-owned hooks unless a fresh `tutor config save`
proves the rendered template consumes them:

| Dead Patch Name | Why Dead |
|---|---|
| `openedx-lms-assets-settings`, `openedx-cms-assets-settings` | Tutor 21 ignores them; live hook is `openedx-common-assets-settings`. |
| `openedx-dockerfile-npm-install-cmd` | Builds fall back to upstream `npm ci`; do not claim this hook owns npm behavior. |
| `mfe-dockerfile-npm-install` | Tutor 21 MFE templates do not consume it; npm resilience is currently the named `mfe-npm-install-resilience.sh` compatibility layer. |

## Review Rule

Every verifier or patch change in this lane must be classified before merge:

| Class | Meaning |
|---|---|
| authority correction | The verifier was wrong about the declared source of truth. |
| obsolete expectation removal | A previous expectation described retired behavior and the docs/spec already say so. |
| temporary compatibility layer | The system is not fully source-owned yet; the exception must stay ledgered with owner, retirement trigger, and proof guard. |
| intentional architecture change | The desired architecture changed and docs/specs/tests were updated together. |

If a change cannot be classified, stop and re-evaluate the authority boundary.
