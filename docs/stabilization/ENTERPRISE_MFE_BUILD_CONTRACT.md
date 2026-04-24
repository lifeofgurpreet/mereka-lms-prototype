# Enterprise MFE Build Contract

**Status**: Active
**Created**: 2026-03-11
**Scope**: Enterprise admin-portal and learner-portal MFE image builds

---

## Overview

Enterprise MFE images are derivative images — they take an upstream Open edX MFE image (built elsewhere) and apply Mereka branding, NREUM stripping, and env-var patching. The build pipeline has three separated concerns:

1. **Source truth** — which upstream image to build from
2. **Cache truth** — optional build acceleration
3. **Release truth** — immutable output tags

These three concerns must never be conflated.

## Source Truth

The base image is specified via `SOURCE_TAG` build-arg, which **must** be an explicit, existing tag. The Dockerfiles have no default — omitting `SOURCE_TAG` fails the build immediately with a clear error.

**Valid source tags**: `mereka-branded-6578c105`, `mereka-branded-e388a846`, or any `mereka-branded-*` tag that exists in GHCR.

**Invalid source tags**: `latest` (moving, not guaranteed to exist), empty string, SHA-only tags from other pipelines.

### How source is resolved

The `build-enterprise-mfe.yml` workflow has a `resolve-source` job that runs before the build jobs. It:

1. Checks if `source_tag` was provided via `workflow_dispatch` (manual override)
2. If not, queries the GitHub API for the most recent `mereka-branded-*` tag in GHCR
3. Passes the resolved tag as `SOURCE_TAG` build-arg to the Dockerfile

### Cold-start scenario

On a completely fresh GHCR (no existing images), the resolve step will fail with a clear error:
```
No mereka-branded-* tag found for <package>. Pass source_tag manually via workflow_dispatch.
```

Recovery: manually trigger the upstream Open edX MFE build pipeline first, then re-run this workflow.

## Cache Truth

Build cache uses GHCR registry cache (`type=registry`, per ADR-024). The enterprise
MFE builds are derivative images and operate at L2 (app cache) only — they do not
consume the L0 platform-base caches. This is managed entirely by the reusable
workflow and is transparent to the Dockerfile.

Note: `type=gha` (GitHub Actions cache) is retired for image builds per ADR-024 and
must not be reintroduced. Registry-backed cache is the only authorised form.

**Cache miss behavior**: Build runs without cache — slower but never fails. Cache is optional acceleration, never a hard dependency.

**Cache location**: GHCR registry ref scoped to the repository and branch (L2 app cache).

The Dockerfiles contain zero cache-related directives. Cache is a workflow concern, not a Dockerfile concern.

## Release Truth

Every successful build produces an **immutable** tag:
```
ghcr.io/biji-biji-initiative/mereka-lms/enterprise-{admin,learner}-portal:<SHA>-<TIMESTAMP>
```

Example: `:c3c63151-20260311120000`

Additionally, a `:latest` alias is pushed as a convenience. This alias:
- Is updated on every successful build
- Is **never** used as a required input by any build
- May be used by humans for quick local testing
- Must never appear in Kubernetes deployment manifests (use immutable tags)

## Why `latest` is Non-Authoritative

`:latest` is a moving pointer with no guarantee of:
- Existence (first build, tag deletion, registry migration)
- Content (any successful build overwrites it)
- Availability (private packages may not be readable by all tokens)

The build pipeline **never** depends on `:latest` existing. It resolves the actual source tag from GHCR metadata before building.

## Build Flow Diagram

```
workflow_dispatch (optional source_tag)
        │
        ▼
┌─────────────────┐
│  resolve-source  │ ← Queries GHCR API for latest mereka-branded-* tag
│   (ubuntu-latest)│   OR uses explicit source_tag input
└────────┬────────┘
         │ admin_source_tag, learner_source_tag
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│ admin  │ │learner │ ← reusable-build-push.yml
│ build  │ │ build  │   build_args: SOURCE_TAG=<resolved>
└────────┘ └────────┘
    │         │
    ▼         ▼
  Immutable tags: <SHA>-<TS>
  Convenience alias: :latest
```

## Files

| File | Purpose |
|------|---------|
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal` | Admin portal Dockerfile (no `latest` default) |
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal` | Learner portal Dockerfile (no `latest` default) |
| `.github/workflows/build-enterprise-mfe.yml` | Caller workflow with source resolution |
| `scripts/qa/verify-enterprise-mfe-build-contract.sh` | CI guardrail (12 checks) |

## Verification

```bash
scripts/qa/verify-enterprise-mfe-build-contract.sh
```

Checks:
1. Dockerfiles don't default `SOURCE_TAG` to `latest`
2. Dockerfiles don't hardcode `:latest` in `FROM`
3. `FROM` uses `${SOURCE_TAG}` variable
4. Workflow passes `SOURCE_TAG` via `build_args`
5. Workflow has source tag resolution step
6. Output tags reference SHA-based generation
7. Cache directives are workflow-only (not in Dockerfile)
8. `workflow_dispatch` has `source_tag` input for manual override

## Reusable Workflow

The reusable workflow lives in `bbi-infrastructure`:
- `.github/workflows/reusable-build-push.yml`
- Inputs added: `build_args` (string), `tag_latest` (boolean)
- These are backwards-compatible — existing callers without `build_args` continue to work
