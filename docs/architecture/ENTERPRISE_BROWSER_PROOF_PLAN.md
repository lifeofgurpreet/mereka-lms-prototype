# Enterprise Browser Proof Plan
_Audience: Runtime Owners, Frontend QA, Release Reviewers • Owner: Platform Team • Last updated: 2026-03-11 • Status: planning_

## Purpose

Provide the minimum browser-proof plan needed to close enterprise frontend parity without creating broad E2E sprawl.

This document is planning scaffolding only. It does **not** claim runtime proof has been performed.

## In Scope

- enterprise learner portal shell
- enterprise admin portal shell
- one authenticated learner deep route
- one authenticated admin deep route
- auth redirect continuity needed to reach those routes

## Required Browser-Proof Matrix

| Surface | Browser proof type | Minimum state coverage |
|---|---|---|
| Enterprise learner portal root | unauthenticated + authenticated shell render | default, loading, broken-branding check |
| Enterprise learner deep route | authenticated | default, empty/error or unauthorized as applicable |
| Enterprise admin portal root | unauthenticated + authenticated shell render | default, loading, broken-branding check |
| Enterprise admin deep route | authenticated | default, empty/error or unauthorized as applicable |
| Enterprise auth redirect chain | session-aware browser journey | redirect continuity, refresh continuity, no wrong-host bounce |

## Must-Capture Assertions

Every browser proof pass should capture:

1. requested URL
2. final landed URL
3. host/domain used
4. screenshot of final state
5. visible tenant identity markers
6. evidence that runtime config is not obviously malformed
7. whether authenticated navigation succeeded

## Explicit Non-Goals

- broad cross-browser matrix
- performance benchmarking
- generic visual-regression suite
- unrelated LMS/Studio deep-route testing

## Recommended First Routes

### Enterprise learner

- root `/`
- one learner-owned protected route that exercises runtime API calls

### Enterprise admin

- root `/`
- one admin route that exercises enterprise service fan-out (`enterprise-catalog`, `enterprise-access`, or `enterprise-subsidy`)

## Failure Classes To Capture

- wrong host after redirect
- broken runtime URLs
- blank shell / placeholder shell
- cross-tenant branding bleed
- authenticated route fails after shell success
- major empty/error state is unhandled or malformed

## Output Expectations

Future runtime/browser lane should emit:

- route/state matrix
- screenshots
- final URL evidence
- short per-surface verdict

## Relationship To Policy

This plan operationalizes:

- `docs/architecture/ENTERPRISE_FRONTEND_PARITY_POLICY.md`
- `docs/architecture/ROUTE_TRUTH_RECONCILIATION.md`

It does not replace them.
