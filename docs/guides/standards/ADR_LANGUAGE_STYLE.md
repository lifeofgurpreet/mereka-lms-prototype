# ADR Language Style Contract
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

## Required Sections

Every ADR MUST contain:
- Decision
- Scope
- Non-goals
- Context
- Decision details
- Invariants
- Verification
- Failure modes
- Consequences
- Alternatives considered

## Normative Language

Use RFC-style keywords:
- MUST
- MUST NOT
- SHOULD
- SHOULD NOT
- MAY

## Banned Phrases

- "we plan to"
- "probably"
- "usually"
- "should be okay"
- "for now" without explicit expiry and removal condition

## Sentence Quality

Good examples:
- "Production image references MUST resolve from GHCR."
- "Cross-root-domain auth MUST use federation, not shared cookies."
- "Exception ADRs MUST include expiry_date and removal_condition."
