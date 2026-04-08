---
id: ADR-005
title: Domain Migration (legacy environment → academyV2)
decision_status: accepted
decision_type: migration
rollout_state: historical
owner: platform-team
created: '2026-02-03'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next: []
governs: []
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-tutor-version-pin.sh
- scripts/qa/verify-repo-structure.sh
expiry_date: null
removal_condition: null
historical_reason: Completed migration history; no longer part of current read-first
  law.
---
<!-- markdownlint-disable -->

# ADR-005: Domain Migration (legacy environment → academyV2)

> **Legacy note:** The old environment name is retired. References to the legacy label are historical only; active environments are production (GKE) and dev (kind).

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

<!-- Last verified: 2026-02-13 -->

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
