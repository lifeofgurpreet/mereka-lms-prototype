# Mobile Apps Overview
_Audience: Engineering Team, Mobile Release Owners, Platform Operators • Owner: Platform Team • Status: canonical • Last verified: 2026-04-10_

This document defines the stable architecture-root view of the Mereka mobile-app
lane.

Use it to understand the current platform boundary for iOS and Android without
treating paused delivery work as active runtime proof.

For current workflow and resumed operational procedures, use:

- `docs/reference/operations/IOS_CI_CD_REFERENCE.md`
- `docs/ops/runbooks/MOBILE_DEPLOYMENT.md`
- `docs/ops/runbooks/MOBILE_APPS_RUNBOOK.md`

## Current Platform Boundary

- iOS remains a first-class intended product surface.
- The maintained iOS CI front door is `.github/workflows/ios-testflight.yml`.
- The iOS delivery lane is currently paused for program timing and CI/TestFlight
  cost control.
- Android remains deferred.
- Mobile runtime verification is not currently complete enough to treat mobile as
  an always-live acceptance lane.

This means mobile architecture should be documented honestly as a supported
future/resumed surface, not as a currently exercised runtime lane.

## Stable Component Model

The current durable model is:

1. mobile clients remain product surfaces, not independent backend owners
2. LMS/OAuth and tenant/domain truth stay owned by the shared platform
3. mobile-specific distribution, signing, and notification credentials stay in
   the build/release lane
4. runtime proof for resumed mobile behavior must cover auth, branding,
   notifications, and content access separately

### Client surfaces

- iOS app based on the Open edX upstream mobile architecture
- Android app design contract retained as deferred reference

### Platform dependencies

The mobile lane depends on shared platform systems rather than owning a separate
backend:

- LMS/OAuth endpoints for authentication
- mobile REST API endpoints
- tenant-aware branding/configuration surfaces
- APNs/FCM credentials and notification dispatch
- shared course, enrollment, and profile APIs

### Delivery and release dependencies

- Apple Developer / App Store Connect setup for iOS
- Firebase / APNs / FCM credentials for notification delivery
- Google Play service-account path for future Android distribution
- active GitHub workflow and signing contract under the maintained CI front
  door

### Tenant boundary

Mobile clients are expected to honor the same tenant/domain contract as the web
lane:

- tenant-aware identity routing
- tenant-correct branding payloads
- tenant-correct deep links and host handoff

Related current canon:

- [PLATFORM_AUTHORITY_MAP.md](PLATFORM_AUTHORITY_MAP.md)

### Release boundary

The mobile lane has four separate truths that must not be collapsed:

- workflow truth: the maintained CI/signing contract exists
- build truth: an app package can be produced successfully
- distribution truth: TestFlight / store upload works
- runtime truth: auth, branding, content access, and notifications work on
  actual devices

Paused delivery means the workflow contract is maintained while build,
distribution, and runtime proof are intentionally not being claimed as current.

## Architectural Rules

### 1. Paused does not mean abandoned

- iOS remains part of the intended product model.
- Docs must not imply the lane is dead just because the current delivery lane is
  paused.

### 2. Paused also does not mean live

- Do not describe mobile authentication, push, offline mode, or branded
  multi-tenant delivery as current runtime-proofed behavior unless the lane is
  explicitly reactivated and verified.

### 3. Workflow truth beats historical iOS archaeology

- The current repo-owned CI front door is `ios-testflight.yml`.
- Older Fastlane and signing learnings remain debugging history, not the primary
  design authority for resumed delivery.

### 4. Android remains design reference

- Android contract material may stay documented for completeness.
- It must not be treated as currently implemented or launch-ready.

## Current Readiness Snapshot

| Surface | Current state | Notes |
|---|---|---|
| iOS workflow contract | Maintained | Front door exists under `ios-testflight.yml` |
| iOS delivery lane | Paused | Resume only after source-backed revalidation |
| Android delivery lane | Deferred | Retained as design reference only |
| Push notifications | Planned/gated | Do not claim runtime proof |
| Offline mode | Planned/gated | Do not claim runtime proof |
| Tenant branding in app | Planned/gated | Depends on resumed lane verification |

## Reactivation Checklist Boundary

Before the lane can honestly move from paused to active:

1. confirm the maintained workflow contract in
   [IOS_CI_CD_REFERENCE.md](../reference/operations/IOS_CI_CD_REFERENCE.md)
2. confirm current secret and signing inputs in
   [MOBILE_SECRETS_MANAGEMENT.md](../reference/operations/MOBILE_SECRETS_MANAGEMENT.md)
3. confirm resumed deployment procedure in
   [MOBILE_DEPLOYMENT.md](../ops/runbooks/MOBILE_DEPLOYMENT.md)
4. runtime-verify auth, tenant branding, course access, and any notification
   path you intend to claim

## Canonical Companion Surfaces

- [IOS_CI_CD_REFERENCE.md](../reference/operations/IOS_CI_CD_REFERENCE.md)
- [MOBILE_DEPLOYMENT.md](../ops/runbooks/MOBILE_DEPLOYMENT.md)
- [MOBILE_APPS_RUNBOOK.md](../ops/runbooks/MOBILE_APPS_RUNBOOK.md)
- [mobile-apps-enterprise_spec.md](../../specs/proposals/mobile-apps-enterprise_spec.md)
