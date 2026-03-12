---
id: "SPEC-ENTERPRISE-FRONTEND-DELIVERY"
title: "Enterprise Frontend Delivery Contract"
type: "feature_spec"
status: "approved"
owner: "platform-frontend"
normativity: "normative"
vehicle: "ci-gate"
last_reviewed: "2026-03-12"
depends_on: []
---

# Enterprise Frontend Delivery Contract Spec

## Scope

Repo-owned contract for enterprise frontend delivery in `mereka-lms`:
route owner alignment, build-time vs runtime MFE config consumption,
deterministic patch ownership, and learner/admin parity guardrails.

## Non-goals

- Runtime browser proof of enterprise MFE behaviour (covered by Lane A runtime proofs)
- Upstream Open edX MFE SDK changes
- Enterprise backend service contracts (covered by enterprise-microservices spec)

## Requirements

### Required Invariants

1. Route families MUST declare a semantic owner, proxy owner, fatality class,
   and concrete repo source files.
2. Enterprise MFE config keys MUST declare how they are consumed:
   `runtime_env`, `patched_bundle_default`, `build_patch_only`,
   `plugin_runtime_alignment`, or `runtime_window_global`.
3. Every `replace_key` placeholder patched by
   `infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh` MUST be
   declared in the config contract.
4. Learner-only optional-404 bundle patches MUST be explicit and role-scoped.
5. Enterprise learner/admin Dockerfiles MUST both:
   - invoke `patch-missing-env.sh` with an explicit portal role
   - inject `env.config.js`
   - copy the shared theme payload
6. The route and config contracts MUST be machine-checkable from repo state
   alone.
7. Contract drift MUST fail CI before runtime/browser proof is required.

## Acceptance Criteria

- AC-EFD-001: Route owner YAML declares owner, proxy, fatality class, and source files for each enterprise route family.
- AC-EFD-002: Config consumption YAML declares consumption mode for every enterprise MFE config key.
- AC-EFD-003: Every `replace_key` in `patch-missing-env.sh` is declared in config contract.
- AC-EFD-004: Learner-portal optional-404 patches are role-scoped.
- AC-EFD-005: Both Dockerfiles invoke `patch-missing-env.sh`, inject `env.config.js`, and copy theme payload.
- AC-EFD-006: Route and config contracts are machine-checkable from repo state alone.
- AC-EFD-007: Contract drift fails CI before runtime proof is required.
