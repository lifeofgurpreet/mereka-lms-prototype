---
id: ADR-031
title: Deprecation and Removal Policy
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: platform-team
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: ["ADR-013", "ADR-022"]
depends_on: ["ADR-028", "ADR-030"]
read_next: []
governs: ["deprecation-policy", "sunset-lifecycle", "exception-expiry"]
does_not_govern: ["incident-response runtime triage"]
related_oep: []
related_tutor_docs: ["https://docs.openedx.org"]
related_specs: []
related_runbooks: ["docs/operations/POSTMERGE_GOVERNANCE_CLOSURE.md"]
related_evidence: []
fitness_functions: ["scripts/qa/verify_exception_expiry.py"]
expiry_date: null
removal_condition: null
---

# ADR-031: Deprecation and Removal Policy

## Decision

Deprecated architecture paths MUST have an explicit removal process with deadline, owner, and verification gate.

## Scope

Applies to ADR exceptions, temporary workarounds, and superseded implementation paths.

## Non-goals

- Replacing rollout policy for new features.

## Context

Current corpus contains accepted workarounds that behave like permanent decisions.

## Decision details

- Exception ADRs MUST include `expiry_date` and `removal_condition`.
- Superseded ADRs MUST link replacement ADR IDs.
- Removal PRs MUST include evidence that old path is no longer active.

## Invariants

- "Temporary" without expiry MUST NOT be merged.
- Superseded decisions MUST remain traceable.

## Verification

- `scripts/qa/verify_exception_expiry.py`
- `scripts/qa/verify_adr_manifest.py`

## Failure modes

- Expired exceptions still active in production.
- Removal work untracked due to missing ownership.

## Consequences

- Monthly exception and deprecation review becomes mandatory.

## Alternatives considered

- Manual tracking in free-form docs.
  - Rejected: high drift and weak accountability.
