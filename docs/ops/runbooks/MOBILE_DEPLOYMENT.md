# Mobile Deployment Runbook
_Audience: Operators and mobile release owners • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

Use this runbook as the front door for the mobile delivery lane.

> **Current posture (2026-04-09)**: iOS remains a major intended product surface, but the active delivery lane is paused while the platform focuses on earlier launch work and avoids unnecessary CI/TestFlight cost. Android remains deferred. Treat this runbook as the maintained reactivation entrypoint, not proof that the mobile lane is currently being exercised.
> **Reactivation rule**: Before treating the iOS lane as live again, re-check the active workflow and signing path against current Open edX mobile guidance instead of reviving older repo-local Fastlane habits by default.

## Start here

- [`../../reference/operations/IOS_CI_CD_REFERENCE.md`](../../reference/operations/IOS_CI_CD_REFERENCE.md)
- [`MOBILE_APPS_RUNBOOK.md`](MOBILE_APPS_RUNBOOK.md)
- [`../ci-cd/FASTLANE_AUTOMATION.md`](../ci-cd/FASTLANE_AUTOMATION.md) for legacy Fastlane archaeology only

## Current Reactivation Procedure

Use this runbook when the paused mobile delivery lane is intentionally being
brought back into service.

1. confirm the maintained iOS workflow contract in
   [../../reference/operations/IOS_CI_CD_REFERENCE.md](../../reference/operations/IOS_CI_CD_REFERENCE.md)
2. confirm current secret inventory and external-state dependencies in
   [../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md](../../reference/operations/MOBILE_SECRETS_MANAGEMENT.md)
3. confirm Apple Developer / TestFlight setup is still valid for the intended
   bundle and team
4. run the maintained workflow front door, not an archived Fastlane lane by
   habit
5. hand off to [MOBILE_APPS_RUNBOOK.md](MOBILE_APPS_RUNBOOK.md) for runtime
   device verification

## Release Boundary

Separate these states explicitly:

- workflow contract maintained
- build succeeds
- TestFlight upload succeeds
- runtime device proof succeeds

Do not call the lane resumed until all claimed layers above are actually proved.
