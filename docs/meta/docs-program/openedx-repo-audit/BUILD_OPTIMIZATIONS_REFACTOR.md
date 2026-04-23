# Build Optimizations Refactor Audit

**Status**: Superseded audit note
**Last reviewed**: 2026-04-23
**Current authority**:

- `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
- `infrastructure/tutor/patch-manifest.yml`
- `infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml`
- `scripts/qa/verify-build-optimizations-render-delta-contract.sh`
- `scripts/qa/verify-tutor-patch-manifest-contract.sh`

This document used to describe a 686-line, multi-target
`build-optimizations.sh` refactor plan. That is no longer current. The active
script is 230 lines, targets the rendered Open edX Dockerfile only, and is
bounded by the machine-readable allowed-delta ledger.

Do not use this file as implementation authority for new build work. Use it only
as historical context for why the current inventory and allowed-delta contract
exist.

## Current State

The active `build-optimizations.sh` surface is a controlled compatibility layer.
It is not a general post-render generator and must not grow without an explicit
authority classification.

Current `build-optimizations.sh` delta ids live in
`infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml`:

- `base-assets-no-build-isolation`
- `uwsgi-plain-pip-fallback`
- `production-build-profile-arg`
- `translation-settings-preflight`
- `advanced-xblocks-production-copy`
- `fast-profile-translation-wrappers`

The intended chain is:

```text
raw Tutor render -> explicit allowed delta -> artifact
```

Any render delta outside that allowed set is a failure unless a PR updates the
ledger, manifest, inventory, tests, and verifier together.

## What Changed Since The Original Audit

The original plan proposed splitting one large mixed patch script into several
`build-opt-*` modules. That plan was overtaken by the J-exit/build-authority
work:

- settings, runtime helper, MFE source hooks, theme behavior, and tenant URL
  authority moved into Tutor plugin/source-owned surfaces
- `build-optimizations.sh` shrank to residual Open edX Dockerfile build
  compatibility and build-profile semantics
- the remaining allowed deltas were moved into
  `build-optimizations.allowed-delta.yaml`
- render preflight can export raw-vs-patched render-delta artifacts
- `verify-tutor-patch-manifest-contract.sh` now ties together the manifest,
  `apply-patches.sh`, sourced modules, the inventory, and the allowed-delta YAML

The old module names below are intentionally not current:

- `build-opt-dockerfile.sh`
- `build-opt-settings.sh`
- `build-opt-routing.sh`
- `build-opt-theme-sync.sh`
- `verify-patch-modularity.sh`

If any future PR revives one of those names, it must first explain why the
current manifest/allowed-delta model is insufficient.

## Current Review Rule

Every verifier or patch change in this lane must be classified before merge:

| Class | Meaning |
|---|---|
| authority correction | The verifier or patch was wrong about the declared source of truth. |
| obsolete expectation removal | A previous expectation described retired behavior and the current docs/spec already say so. |
| temporary compatibility layer | The behavior cannot yet be expressed through Tutor hooks, Bake/HCL, or source-owned files; the exception needs an owner, retirement trigger, and guard. |
| intentional architecture change | The desired architecture changed and docs/specs/tests changed with it. |

If a change cannot be classified, stop and re-evaluate the authority boundary.

## Current Open Debt

The active debt is not "split `build-optimizations.sh` into more bash." The
active debt is reducing or retiring the remaining allowed deltas when Tutor,
Bake/HCL, or upstream source hooks can express them cleanly.

Track that work through the build-authority beads under `mereka-lms-0z5g`, not
through this historical audit note.
