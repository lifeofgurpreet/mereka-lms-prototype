# Architecture Policies
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root when you need the rules that constrain platform shape, UX consistency, performance limits, and architecture-level exceptions. Start here for “what rule should govern this design?” Do not use this root for ADR history, runtime procedures, or raw specs.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Check accessibility or readability rules | [`ACCESSIBILITY_CONFORMANCE_POLICY.md`](ACCESSIBILITY_CONFORMANCE_POLICY.md) | [`WCAG_CONTRAST_POLICY_V2.md`](WCAG_CONTRAST_POLICY_V2.md) |
| Check frontend interaction or copy consistency rules | [`COPY_TERMINOLOGY_CONTRACT.md`](COPY_TERMINOLOGY_CONTRACT.md) | [`INTERACTION_STATE_CONTRACT.md`](INTERACTION_STATE_CONTRACT.md) |
| Check performance limits | [`PERFORMANCE_BUDGETS.md`](PERFORMANCE_BUDGETS.md) | [`LIGHTHOUSE_BUDGETS.md`](LIGHTHOUSE_BUDGETS.md) |
| Check frontend selector or footer exceptions | [`MFE_SELECTOR_EXCEPTIONS.md`](MFE_SELECTOR_EXCEPTIONS.md) | [`footer-slot-exceptions.md`](footer-slot-exceptions.md) |
| Check analytics, privacy, or multisite architecture policy | [`ANALYTICS_DECISION_GATE.md`](ANALYTICS_DECISION_GATE.md) | [`GDPR_COMPLIANCE.md`](GDPR_COMPLIANCE.md) or [`MULTISITE_UX_CONSISTENCY.md`](MULTISITE_UX_CONSISTENCY.md) |

## Use this directory for

- architecture policy and guardrail documents
- UX, performance, and consistency policies
- cross-cutting architecture exceptions and limits

## Core policy set

- [`ACCESSIBILITY_CONFORMANCE_POLICY.md`](ACCESSIBILITY_CONFORMANCE_POLICY.md) for accessibility conformance rules
- [`WCAG_CONTRAST_POLICY_V2.md`](WCAG_CONTRAST_POLICY_V2.md) for contrast and readability requirements
- [`COPY_TERMINOLOGY_CONTRACT.md`](COPY_TERMINOLOGY_CONTRACT.md) for copy and terminology consistency
- [`INTERACTION_STATE_CONTRACT.md`](INTERACTION_STATE_CONTRACT.md) for user interaction-state rules
- [`PERFORMANCE_BUDGETS.md`](PERFORMANCE_BUDGETS.md) for architecture-level performance limits
- [`LIGHTHOUSE_BUDGETS.md`](LIGHTHOUSE_BUDGETS.md) for Lighthouse-facing budget thresholds

## Frontend and selector policy

- [`MFE_FIRST_POLICY.md`](MFE_FIRST_POLICY.md) for the runtime-first frontend posture
- [`MFE_SELECTOR_EXCEPTIONS.md`](MFE_SELECTOR_EXCEPTIONS.md) for approved selector exceptions
- [`SELECTOR_HARDENING_POLICY.md`](SELECTOR_HARDENING_POLICY.md) for selector hardening rules
- [`footer-slot-exceptions.md`](footer-slot-exceptions.md) for governed footer-slot exceptions

## Platform and compliance policy

- [`ANALYTICS_DECISION_GATE.md`](ANALYTICS_DECISION_GATE.md) for analytics governance posture
- [`ANALYTICS_DRIFT_GUARDRAILS.md`](ANALYTICS_DRIFT_GUARDRAILS.md) for analytics drift prevention
- [`GDPR_COMPLIANCE.md`](GDPR_COMPLIANCE.md) for privacy and retention-related architecture policy
- [`MULTISITE_UX_CONSISTENCY.md`](MULTISITE_UX_CONSISTENCY.md) for multisite experience rules
- [`OSCAR_DEPRECATION.md`](OSCAR_DEPRECATION.md) for legacy commerce deprecation policy

## Do not use this directory for

- accepted ADRs, which belong in `docs/adr/**`
- operator-facing runtime procedures, which belong in `docs/ops/**`
- raw specs, which belong in `specs/**`

## How To Use This Root Well

1. Start here when the question is about a design rule, boundary, or guardrail.
2. If you need the current factual system shape rather than the rule, move to [`../../reference/architecture/README.md`](../../reference/architecture/README.md).
3. If you need execution steps, move to [`../../ops/README.md`](../../ops/README.md).
