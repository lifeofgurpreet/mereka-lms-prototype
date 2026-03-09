# Status Index
_Audience: Contributors • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_

This is the active reporting and status root.

## Scope

Use `docs/status/**` for:

- active operational tracking
- readiness and go/no-go reporting
- incident summaries
- migration status

## Start here

- Need current rollout or program posture:
  - start with `docs/status/active/`
- Need readiness or go/no-go posture:
  - start with `docs/status/readiness/`
- Need current migration posture:
  - start with `docs/status/migrations/`
- Need recurring reporting cadence:
  - start with `docs/status/weekly/`
- Need incident-specific current status:
  - start with `docs/status/incidents/`

## Authority rule

- new active status belongs under `docs/status/**`
- `reports/2026/status/**` and `reports/2026/readiness/**` are compatibility surfaces only
- `docs/archive/reports/**` is cold-only historical context

## Intended layout

- `docs/status/active/`
- `docs/status/readiness/`
- `docs/status/migrations/`
- `docs/status/weekly/`
- `docs/status/incidents/`

## What belongs here

- current blockers
- current readiness posture
- current migration state
- active operational follow-up

## What does not belong here

- cold historical reporting
- long-term architecture standards
- operator procedures
- proof bundles that belong in `docs/evidence/**`

## Standards

- [Status Reporting Standard](../guides/standards/STATUS_REPORTING_STANDARD.md)
- [Documentation Authority Resolver](../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
