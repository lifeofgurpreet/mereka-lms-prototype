---
title: Frontend Runtime Composition and Dependency Alignment
proposal_state: proposed
owner: frontend-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes frontend runtime composition, branding-token, and dependency alignment
  rules.
tags:
- frontend
- runtime
- dependencies
decision_type: domain
decision_status: proposed
governs:
- frontend.composition
- frontend.brand.tokens
- build.version-pin
id: ADR-035
rollout_state: planned
supersedes: []
amends:
- ADR-014
- ADR-021
depends_on:
- ADR-028
- ADR-029
read_next: []
does_not_govern:
- visual-brand-campaign-content
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks:
- docs/guides/branding/BRANDING_OPERATING_MODEL.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-mfe-image-branding.sh
expiry_date: null
removal_condition: null
---

# ADR-035: Frontend Runtime Composition and Dependency Alignment

## Decision
Frontend customization MUST prioritize runtime composition via supported plugin-slot and token contracts over source patching.

## Scope
Governs MFE composition, dependency pin alignment, and runtime injection contracts.

## Non-goals
Defining exact product UI copy.

## Context
Half-migrated patch paths increase upgrade risk and runtime drift.

## Decision details
- Slot-first customization MUST be default.
- Dependency versions MUST be aligned to release-line constraints.
- Runtime config generation MUST be deterministic.

## Invariants
No new direct source surgery when supported hook/slot exists.

## Verification
Branding/runtime QA gates and dependency contract checks.

## Failure modes
Hidden source patches breaking after upgrades.

## Consequences
Sharper upgrade posture and predictable frontend composition.

## Alternatives considered
Continue mixed slot + ad-hoc patch strategy.
