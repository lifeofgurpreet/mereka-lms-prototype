# Architecture Charter

## Purpose

This charter defines the living architecture control model for Mereka LMS.
It separates current law, historical decisions, machine-checkable contracts, operational runbooks, and evidence.

## Non-Negotiables

1. Living standards in `docs/architecture/constitution/` define what MUST be true now.
2. ADRs record why a decision was made and what it superseded; they are not the sole home for ongoing governance.
3. Undecided architecture work lives in RFCs before it becomes an ADR.
4. Contracts express machine-checkable compatibility boundaries for runtime, build, auth, tenancy, and commerce surfaces.
5. Runbooks describe operator actions; evidence records proof; neither should be embedded as primary ADR content.
6. For Open edX and Tutor guidance, official sources MUST be used first:
   - `https://docs.openedx.org`
   - `https://docs.tutor.edly.io`
7. Tutor customization MUST prefer supported plugins/hooks and `config.yml` over manual edits to rendered or generated outputs.
8. Identity architecture MUST be federation-first across domain boundaries; cookie-sharing workarounds are exceptions, not the target model.
9. Eventing MUST be schema-first and transport-abstracted.
10. Every living standard MUST carry owner, review cadence, governed scope, non-goals, and fitness functions.

## Artifact Model

- Constitution: living standards, reviewed on a schedule.
- ADRs: historical decision record, supersedable and lightweight.
- RFCs: undecided future architecture proposals.
- Contracts: schema and interface truth for compatibility checking.
- Runbooks: operator procedures.
- Evidence: proof that a contract, rollout, or review actually occurred.

## Review Rhythm

- Constitution: quarterly review.
- Exception ADRs: monthly review until removed.
- Contracts: verified continuously in CI and local gates.
- RFCs: active review only while pending a decision.

## Decision Rule

When a topic needs both history and current law:
- write or update the living standard first,
- record the decision in an ADR second,
- attach proof and procedures outside the ADR.
