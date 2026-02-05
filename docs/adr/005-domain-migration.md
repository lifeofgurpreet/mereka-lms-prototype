# ADR-005: Domain Migration (legacy environment → academyV2)

> **Legacy note:** The old environment name is retired. References to the legacy label are historical only; active environments are production (GKE) and dev (kind).

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

## Context

The original legacy environment used `staging.mereka.io` which was confusing:
- The legacy label implied non-production, but it served real users
- Multiple teams referred to it inconsistently
- Needed a clearer naming convention

## Decision

We renamed the domain to **academyv2.mereka.io** to indicate:
- It's the "v2" of the academy platform (replacing Kajabi)
- Clear branding alignment with Mereka Academy
- Removes the "staging" confusion

The environment variable pattern allows easy domain changes:
- `MEREKA_LMS_DOMAIN`, `MEREKA_STUDIO_DOMAIN`, etc.

## Consequences

### Positive
- Clear naming that reflects purpose
- Easy to change domains via environment variables
- Consistent variable naming across services

### Negative
- Existing documentation referenced old domain
- OAuth redirects needed updating
- DNS propagation delay during migration

## Alternatives Considered

### Keep "staging" but add "production"
- Would require running two instances
- **Rejected because**: Cost, operational overhead

### Use academyv2.mereka.io
- Simpler URL
- **Accepted because**: We standardize on academyv2 for GKE now; academy.mereka.io remains unused

## Implementation Notes

- All domain references use MEREKA_* environment variables
- Cookie domain: `.academyv2.mereka.io` (supports LMS + Studio + MFEs)
- Production settings in `deploy/k8s/base/apps/openedx/settings/*/production.py`
- Caddy Caddyfile handles domain routing
