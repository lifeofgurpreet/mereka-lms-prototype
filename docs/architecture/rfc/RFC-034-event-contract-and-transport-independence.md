# RFC-034 Event Contract And Transport Independence

Status: proposed
Source record: `docs/adr/034-event-contract-and-transport-independence.md`

## Intent

Define events by schema and semantics first, with transport treated as replaceable infrastructure.

## Why This Is Still An RFC

The decision is valuable, but it is still future-facing domain architecture rather than settled platform history.

## Candidate Invariants

- Event schemas are versioned.
- Producers emit schema-versioned payloads.
- Consumers tolerate additive compatible changes.
