# RFC-036 Cache Topology And Invalidation Strategy

Status: proposed
Source record: `docs/adr/036-cache-topology-and-invalidation-strategy.md`

## Intent

Define ownership, invalidation, and stale-read behavior for cache layers.

## Why This Is Still An RFC

The repo has incidents and partial checks, but not yet a single accepted cache constitution.

## Candidate Invariants

- Each cache has an owner and namespace.
- Each cache has invalidation semantics.
- Staleness tolerance is explicit.
