# ADR-005: Domain Migration (staging → academyV2)

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

## Context

The original staging environment used `staging.mereka.io` which was confusing:
- "Staging" implied non-production, but it served real users
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

### Use academy.mereka.io
- Simpler URL
- **Rejected because**: Reserved for potential future use

## Implementation Notes

- All domain references use MEREKA_* environment variables
- Cookie domain: `.mereka.io` (supports all subdomains)
- Production settings in `deploy/k8s/base/apps/openedx/settings/*/production.py`
- Caddy Caddyfile handles domain routing
