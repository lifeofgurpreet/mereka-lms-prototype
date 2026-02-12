# Next Phase Roadmap (Deferred)

> Generated 2026-02-11. Resume after resolving production regression issues.

## Current State Summary

| Dimension | Status |
|-----------|--------|
| Foundation (Tier 0-3) | 95%+ done |
| Enterprise Core (Tier 4-6) | Partial — auth/SSO is the gap |
| Features (Tier 7+) | Mostly unimplemented |
| Live Cluster | 72.4% verification pass rate |
| Spec Coverage | 59.6% mapped (458/769 ACs) |

## Quick Wins (hours)
1. Fix hostname registry drift (ingress YAML vs spec)
2. Fix gitops pin drift (bbi-infrastructure ref vs HEAD)
3. Fix verify-body-limits.sh grep pattern

## Medium Effort (days)
4. Auth/SSO Enterprise Tier 5 (34/45 ACs unmapped) — BIGGEST BLOCKER
5. Multi-tenancy remaining 12 ACs
6. HubSpot registration enablement (feature flag flip)

## Larger Effort (weeks)
7. Email notification pipeline (45 ACs)
8. Video pipeline Mux integration (11 ACs)
9. Content Libraries v2 (33 ACs)

## Deferred (2027)
- Mobile apps (37 ACs), Proctoring (38 ACs), GDPR (30 ACs)

## Verification Failure Breakdown (29 failures)
- ~18 not-yet-implemented features
- ~7 config drift / fixable bugs
- ~4 missing test data / creds
