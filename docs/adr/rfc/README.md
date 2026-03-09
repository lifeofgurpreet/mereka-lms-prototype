# RFC Queue

This directory is the live proposal queue for architectural work that is not yet accepted.

Use this surface when you need to review open architectural proposals without treating them as accepted policy. RFCs here are intentionally kept out of the accepted ADR hot path until they are accepted, superseded, or withdrawn.

## Start here

1. Read [../README.md](../README.md) for the accepted ADR ledger and generated index.
2. Read [../../concepts/architecture/ARCHITECTURE_CHARTER.md](../../concepts/architecture/ARCHITECTURE_CHARTER.md) if you need the current living rules first.
3. Read the relevant RFC here only after you know the current law it might change.

## How to use this queue

- Treat files in this directory as proposed decisions, not current law.
- Use RFCs to review unresolved design direction, not to justify current production behavior.
- When an RFC is accepted, it must move back into the accepted ADR surface and re-enter generated bundles, indexes, and graphs accordingly.
- When an RFC is rejected or withdrawn, keep the history clear rather than letting it drift as a quasi-accepted proposal.

## Current proposal range

The current RFC queue contains the proposed decisions that were moved out of the accepted ADR path:

- `ADR-034` Event Contract and Transport Independence
- `ADR-035` Frontend Runtime Composition and Dependency Alignment
- `ADR-036` Cache Topology and Invalidation Strategy
- `ADR-037` Async Task User-Facing Contract
- `ADR-038` Commerce System of Record and Reconciliation
- `ADR-039` Translations and Internationalization Strategy
- `ADR-040` Internal Packages, Plugins, and Versioning Policy
- `ADR-041` Authorization and Role-Boundary Model

## What this queue is not

- not an accepted-decision surface
- not a replacement for living architecture standards
- not the place to store implementation plans that are not architectural proposals

## Related authority docs

- [Architecture Charter](../../concepts/architecture/ARCHITECTURE_CHARTER.md)
- [Documentation Authority Resolver](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
