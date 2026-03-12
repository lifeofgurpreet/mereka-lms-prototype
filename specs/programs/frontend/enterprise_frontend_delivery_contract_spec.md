# Enterprise Frontend Delivery Contract Spec

## Purpose

This spec defines the repo-owned contract for enterprise frontend delivery in
`mereka-lms`:

- route owner alignment for enterprise learner/admin surfaces
- build-time versus runtime enterprise MFE config consumption
- deterministic patch ownership in `patch-missing-env.sh`
- learner/admin parity guardrails for enterprise frontend delivery

## Required Invariants

1. Route families must declare a semantic owner, proxy owner, fatality class,
   and concrete repo source files.
2. Enterprise MFE config keys must declare how they are consumed:
   `runtime_env`, `patched_bundle_default`, `build_patch_only`,
   `plugin_runtime_alignment`, or `runtime_window_global`.
3. Every `replace_key` placeholder patched by
   `infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh` must be
   declared in the config contract.
4. Learner-only optional-404 bundle patches must be explicit and role-scoped.
5. Enterprise learner/admin Dockerfiles must both:
   - invoke `patch-missing-env.sh` with an explicit portal role
   - inject `env.config.js`
   - copy the shared theme payload
6. The route and config contracts must be machine-checkable from repo state
   alone.
7. Contract drift must fail CI before runtime/browser proof is required.
