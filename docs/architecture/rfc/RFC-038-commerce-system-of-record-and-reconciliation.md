# RFC-038 Commerce System Of Record And Reconciliation

Status: proposed
Source record: `docs/adr/038-commerce-system-of-record-and-reconciliation.md`

## Intent

Define the modern system of record and reconciliation guarantees after Oscar retirement.

## Why This Is Still An RFC

The direction is strong, but it should stay proposal-grade until the full contract is operationally proven.

## Candidate Invariants

- Payment, order, and enrollment state are traceable.
- Reconciliation windows are explicit.
- No final order exists without reconcilable internal and provider state.
