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
