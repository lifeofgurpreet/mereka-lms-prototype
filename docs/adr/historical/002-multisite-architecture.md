---
id: ADR-002
title: Multisite Architecture
decision_status: accepted
decision_type: domain
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
- scripts/qa/verify-repo-structure.sh
- scripts/qa/verify-tutor-config-safety.sh
expiry_date: null
removal_condition: null
historical_reason: Superseded in practice by ADR-029 and ADR-033 for current tenancy
  and identity law.
---

# ADR-002: Multisite Architecture

**Status**: Accepted
**Date**: 2026-02-03
**Deciders**: Platform Team

<!-- Last verified: 2026-02-13 -->

## Context

Mereka Academy serves multiple brands:
- academyv2.mereka.io (primary)
- academy.biji-biji.com (partner brand)
- skillourfuture domains (planned)

We needed to decide how to serve multiple domains from a single Open edX installation.

## Decision

We chose a **single-cluster multisite** architecture where one Open edX installation serves all domains, with shared databases and differentiated theming.

## Consequences

### Positive
- Single deployment to maintain
- Shared course catalog (courses can be made available across sites)
- Cost-efficient (one set of resources)
- Simplified operations

### Negative
- Shared database means shared downtime
- Cookie domain management is complex (requires `.mereka.io` wildcard)
- Theming must be carefully managed per-site
- All sites must be on same Open edX version

## Alternatives Considered

### Separate Open edX Instances per Brand
- Complete isolation
- Independent upgrade cycles
- **Rejected because**: 2-3x infrastructure cost, operational overhead

### Tutor Multi-instance Setup
- Multiple Tutor environments on same cluster
- Separate databases per instance
- **Rejected because**: Complex networking, resource overhead

## Implementation Notes

- Caddy handles domain routing via Server Names
- SESSION_COOKIE_DOMAIN set to `.mereka.io` for cross-subdomain auth
- Site configuration in `infrastructure/tutor/multisite-sites.yml`
- Themes differentiate branding per domain
