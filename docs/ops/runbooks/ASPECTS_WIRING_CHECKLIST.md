# Aspects Wiring Checklist
_Audience: Operators and analytics owners • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

Use this checklist when analytics wiring or Aspects readiness is being
verified. It is a deferred-state verification surface, not a deployment or
release checklist for shared environments.

## Boundary

- This checklist does not authorize a shared-environment rollout.
- Shared-environment analytics remains deferred until the decision gate changes
  and an explicit release authority exists.
- If someone is using Tutor or direct `kubectl` steps in a shared environment,
  that is a legacy/manual bootstrap exception, not the canonical operator path.

## Start here

- [`../../concepts/analytics/CURRENT_ANALYTICS_STATE.md`](../../concepts/analytics/CURRENT_ANALYTICS_STATE.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
- [`../../reference/operations/ASPECTS_ANALYTICS_SETUP.md`](../../reference/operations/ASPECTS_ANALYTICS_SETUP.md)
- [`../../../scripts/qa/verify-aspects-wiring.sh`](../../../scripts/qa/verify-aspects-wiring.sh)
