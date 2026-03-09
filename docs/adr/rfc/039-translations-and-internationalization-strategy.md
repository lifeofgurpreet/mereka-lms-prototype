---
title: Translations and Internationalization Strategy
proposal_state: proposed
owner: frontend-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes translation and internationalization rules for frontend surfaces.
tags:
- frontend
- i18n
- translations
decision_type: domain
decision_status: proposed
governs:
- frontend.i18n
id: ADR-039
rollout_state: planned
supersedes: []
amends: []
depends_on:
- ADR-035
read_next: []
does_not_govern:
- content-authoring-language-policy
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-translation-contract.sh
expiry_date: null
removal_condition: null
---

# ADR-039: Translations and Internationalization Strategy

## Decision
Translations MUST be treated as architecture: versioned message contracts, deterministic locale fallback, and release-time validation.

## Scope
Covers platform translation lifecycle and runtime i18n behavior.

## Non-goals
Defining marketing/editorial language choices.

## Context
Translation drift creates silent UX regressions and inconsistent tenant behavior.

## Decision details
- Message keys MUST be stable and versioned.
- Locale fallback chain MUST be explicit.

## Invariants
No locale deployment without translation contract checks.

## Verification
Translation contract gates in CI.

## Failure modes
Missing keys and mixed-language runtime surfaces.

## Consequences
Improved multilingual reliability and predictable rollout quality.

## Alternatives considered
Best-effort translation updates without contract enforcement.
