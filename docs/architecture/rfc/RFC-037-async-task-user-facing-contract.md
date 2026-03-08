# RFC-037 Async Task User-Facing Contract

Status: proposed
Source record: `docs/adr/037-async-task-user-facing-contract.md`

## Intent

Create one user-visible state model for long-running operations.

## Why This Is Still An RFC

This is still design work for consistency across services, not yet settled historical policy.

## Candidate Invariants

- Async APIs return correlation IDs.
- User-visible states are deterministic.
- Retry and terminal failure semantics are documented.
