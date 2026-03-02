# MFE Plugin Slots Runbook

This runbook defines operational verification for `specs/mfe-plugin-slots_spec.md`.

## Canonical Gate Commands

Use the consolidated bundle first (safe defaults):

```bash
./scripts/qa/run-mfe-slot-gates.sh
```

Enable runtime checks when credentials and target environment are ready:

```bash
RUN_SLOT_RUNTIME=1 \
RUN_SLOT_RUNTIME_ALLOW_MUTATION=1 \
LMS_BASE_URL=https://academyv2.mereka.io \
PROFILE_USERNAME=<username> \
API_TOKEN=<token> \
./scripts/qa/run-mfe-slot-gates.sh
```

`RUN_SLOT_RUNTIME_ALLOW_MUTATION=1` is mandatory when runtime mode is enabled.
This prevents accidental mutation of profile fields during routine static checks.

Optional visual regression lane:

```bash
RUN_SLOT_VISUAL_REGRESSION=1 SLOT_VISUAL_ENV=prod \
./scripts/qa/run-mfe-slot-gates.sh
```

## CI Runtime Lane

Use `.github/workflows/mfe-slot-runtime-gates.yml` for scheduled/manual runtime checks.
It runs static slot gates first, then runs runtime checks with explicit mutation acknowledgement.

## Header Branding

Validate desktop/mobile header logo replacement, logo click target, tenant-specific logo variants, and desktop/mobile nav parity on supported hosts.

## Learning Surface

Validate course outline sidebar branding, sequence navigation branding, placeholder rendering, and rendered slot presence for the Learning MFE.

## Account And Profile

Validate additional profile field rendering in Account/Profile, persistence via profile API, and rendered slot presence for Account/Profile MFEs.

## Slot Registration Pattern

Validate `PLUGIN_SLOTS.add_items()` usage pattern, inline JSX definitions in runtime patches, hostname-aware `SITE_VARIANTS` behavior, `"all"` target behavior, and graceful no-op behavior for unsupported slots.

## Test Execution

Run the consolidated slot gate bundle first, then run optional visual regression lane and capture evidence for no default Open edX header logo regressions and reproducible build-failure diagnostics.

## Non-Functional Checks

Measure slot render latency, bundle delta, and responsive behavior across target viewport sizes.
By default these checks run in source-contract mode (non-mutating). Enable runtime mode explicitly when needed.

## Cross-Spec Checks

Validate branding asset path integrity (no logo 404s) and confirm no Google Fonts requests are introduced by slot components.
