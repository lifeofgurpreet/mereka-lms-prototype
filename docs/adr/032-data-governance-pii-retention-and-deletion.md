---
title: Data Governance, PII, Retention, and Deletion
owner: platform-security
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr
doc_class: adr
summary: Data governance contract for PII handling, retention, deletion workflows, and evidence hygiene across the platform.
tags:
- data.pii
- data.retention
- docs.evidence
decision_type: foundation
decision_status: accepted
governs:
- data.pii
- data.retention
- data.deletion
- docs.evidence
id: ADR-032
rollout_state: active
supersedes: []
amends: []
depends_on:
- ADR-028
- ADR-031
read_next:
- ADR-033
does_not_govern:
- business analytics questions
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
related_specs: []
related_runbooks:
- docs/policies/operations/DATA_RETENTION_POLICY.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-evidence-redaction.sh
- scripts/qa/scan-secrets-fast.sh
expiry_date: null
removal_condition: null
---

# ADR-032: Data Governance, PII, Retention, and Deletion

## Decision

PII-bearing data flows MUST declare retention windows, redaction boundaries, and deletion procedures.

## Scope

Covers platform logs, ADR evidence artifacts, operational exports, and user-linked platform data.

## Non-goals

- Defining application feature semantics unrelated to data governance.

## Context

Evidence and operational artifacts can accidentally retain sensitive data unless governance is explicit and enforced.

## Decision details

- Evidence artifacts MUST avoid live secret/token/cookie values.
- Retention/deletion pathways MUST be documented and testable.
- Deletion requests MUST be traceable to policy and execution evidence.

## Invariants

- Secrets MUST NOT be committed in docs or evidence.
- Retention policy documents MUST map to actual operational procedures.

## Verification

- `scripts/qa/verify-evidence-redaction.sh`
- `scripts/qa/scan-secrets-fast.sh`

## Failure modes

- PII leakage via evidence markdown.
- Retention promises with no operational delete path.

## Consequences

- Governance reviews must include evidence hygiene checks.

## Alternatives considered

- Policy-only approach without testable gates.
  - Rejected: non-enforceable in multi-agent workflows.
