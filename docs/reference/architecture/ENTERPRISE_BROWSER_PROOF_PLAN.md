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

## Execution Matrix

This matrix is the minimum execution-grade plan for the runtime/browser lane.

| Surface | Minimum route under test | Session requirement | Required states | Required evidence | Pass rule |
|---|---|---|---|---|---|
| Enterprise learner portal root | enterprise learner host `/` | unauthenticated and authenticated rerun | default, initial loading, broken-branding check | screenshot, final URL, host, visible tenant markers | lands on correct host, shell renders, branding is not obviously broken |
| Enterprise learner deep route | one protected learner route that performs runtime API calls | authenticated | default plus one of: empty, error, or unauthorized | screenshot, final URL, route-state verdict, note on API-backed content presence | protected navigation succeeds and the state is handled coherently |
| Enterprise admin portal root | enterprise admin host `/` | unauthenticated and authenticated rerun | default, initial loading, broken-branding check | screenshot, final URL, host, visible tenant markers | lands on correct host, shell renders, admin branding is not obviously broken |
| Enterprise admin deep route | one protected admin route that exercises enterprise service fan-out | authenticated | default plus one of: empty, error, or unauthorized | screenshot, final URL, route-state verdict, note on service-backed content presence | protected navigation succeeds and no obvious wrong-host or malformed-runtime failure appears |
| Enterprise auth redirect chain | enterprise entrypoint to authenticated landing route | session-aware | redirect continuity, refresh continuity, wrong-host detection | start URL, redirect chain summary, final URL, screenshot | no wrong-host bounce, no dead-end redirect loop, final route belongs to intended tenant/surface |

## Evidence Contract

Every recorded browser-proof case should emit the same minimum bundle:

1. surface name
2. route under test
3. requested URL
4. final landed URL
5. host/domain used
6. authentication state used
7. state classification observed
8. screenshot or equivalent browser artifact
9. short verdict: `pass`, `fail`, or `indeterminate`
10. short note explaining any indeterminate condition

## State Coverage Rules

The runtime/browser lane does not need to exhaust every state permutation. It does need to prove the most failure-prone state for each surface family.

| Surface family | Required state beyond default | Why |
|---|---|---|
| Portal shell root | initial loading or hydration transition | catches blank shell / broken bundle / wrong runtime config earlier than default-only proof |
| Protected learner route | one negative state: empty, error, or unauthorized | proves the route is not only happy-path renderable |
| Protected admin route | one negative state: empty, error, or unauthorized | admin flows often fail on API fan-out, permissions, or table-state handling |
| Auth redirect chain | redirect continuity and refresh continuity | catches wrong-host bounce, broken callback, and post-login dead-end failures |

## Minimum Pass / Fail Semantics

### Pass

A surface may be marked `pass` only when:

- the final URL belongs to the intended enterprise host or shared surface
- no cross-tenant identity bleed is visible
- no malformed runtime URLs or placeholder shell is visible
- the tested state is handled coherently enough for release confidence

### Fail

A surface must be marked `fail` when any of the following occur:

- wrong host after redirect
- cross-tenant identity bleed
- placeholder or blank shell after bundle load
- malformed runtime links or obvious missing config
- protected route cannot be reached after successful auth/session restore
- tested negative state is visibly broken or unhandled

### Indeterminate

Use `indeterminate` only when the browser lane is blocked by missing credentials, unavailable runtime dependency, or another external precondition that prevents a meaningful route verdict.

`indeterminate` is not a pass.

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
  - first governed route: `/dashboard`

### Enterprise admin

- root `/`
- one admin route that exercises enterprise service fan-out (`enterprise-catalog`, `enterprise-access`, or `enterprise-subsidy`)
  - first governed route: `/admin/analytics/`

## First Governed Execution Lane

The first repo-owned execution lane for this plan is the authenticated SSO canary:

- script: `scripts/qa/verify-authenticated-sso-canary.sh`
- workflow: `.github/workflows/smoke-authenticated.yml`

### Current Route / State Matrix

| Surface | Route | Auth state | Expected pass semantics |
|---|---|---|---|
| Enterprise learner portal root | `https://learner.<env-host>/` | authenticated | remains on learner host and renders a coherent shell (no login bounce / no blank shell) |
| Enterprise learner deep route | `https://learner.<env-host>/dashboard` | authenticated | remains on learner host and renders a coherent default or negative state |
| Enterprise admin portal root | `https://admin.<env-host>/` | authenticated | remains on admin host and renders a coherent shell (no login bounce / no blank shell) |
| Enterprise admin deep route | `https://admin.<env-host>/admin/analytics/` | authenticated | remains on admin host and renders a coherent default or negative state |

### Environment-Aware Skip Rule

If an enterprise host is not live for a lane yet (for example DNS does not resolve), the authenticated canary records that as a skip for the enterprise browser extension rather than a false route failure. A live host that resolves but serves a broken runtime surface is still a failure.

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
- explicit `pass` / `fail` / `indeterminate` count

## Required vs Deferred Coverage

### Required in the first runtime/browser pass

- enterprise learner portal root
- enterprise learner protected route
- enterprise admin portal root
- enterprise admin protected route
- enterprise auth redirect chain

### Deferred unless the release specifically changes them

- broader Studio/LMS deep-route coverage outside the enterprise journey
- wide visual-regression baselines
- cross-browser matrix expansion
- performance benchmarking

## Ownership Boundary

This plan is owned by the repo as planning truth only.

Execution remains outside this lane and belongs to the runtime/browser owners because the required proof depends on:

- live hosts
- live auth/session behavior
- live runtime config
- live tenant identity

## Relationship To Policy

This plan operationalizes:

- `docs/policies/architecture/ENTERPRISE_FRONTEND_PARITY_POLICY.md`
- `docs/reference/architecture/ROUTE_TRUTH_RECONCILIATION.md`

It does not replace them.
