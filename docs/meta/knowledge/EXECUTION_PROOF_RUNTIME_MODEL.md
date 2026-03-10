# Execution Proof Runtime Model

Wave 13 extends the Wave 12 decision runtime with receipt-bearing proof surfaces.

## Purpose
- record what was executed
- record what was reviewed
- record which evidence classes were satisfied
- preserve unresolved inputs explicitly instead of implying completion

## Canonical Inputs
1. Wave 12 canonical machine outputs under `generated/knowledge/*.json`
2. Wave 11 canonical pack and skill surfaces under `generated/skills/*.json`
3. canonical contracts, specs, and compiled references already named by those outputs

## Canonical Outputs
- execution receipts
- approval receipts
- proof bundle manifests
- receipt evaluation outputs

These machine-readable outputs are canonical. Any Markdown mirrors are projections only.

## Precedence
1. decision runtime outputs
2. pack registry and skill registry
3. evidence sufficiency and mixed-diff arbitration
4. canonical source contracts/specs/docs
5. projections for human review

## Receipt Classes
- `execution_receipt`
  - proves which commands and generators ran
- `approval_receipt`
  - records modeled reviewer obligations and explicit unresolved approval inputs
- `evidence_receipt`
  - records which evidence classes were satisfied, missing, or advisory
- `runtime_proof_receipt`
  - records attached runtime proof references when they exist
- `release_decision_receipt`
  - binds release-readiness output to the evidence and approval state used

## Deterministic Guarantees
- no wall-clock timestamps in generated truth
- no local absolute paths in payloads
- every receipt must explain itself through canonical inputs
- unresolved live state must stay unresolved, never guessed

## Blocking Semantics
- missing canonical inputs are blocking
- schema-invalid receipts are blocking
- high-risk changes without reviewer or evidence receipts are blocking
- missing live approval state is unresolved input, not implicit pass

## Non-Goals
- no live GitHub API reads
- no live cluster queries
- no vendor-specific assistant packaging
