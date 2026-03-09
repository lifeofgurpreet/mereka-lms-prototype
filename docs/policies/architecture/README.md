# Architecture Policies
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains architecture-level policy documents that govern how the platform should be shaped and constrained.

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
