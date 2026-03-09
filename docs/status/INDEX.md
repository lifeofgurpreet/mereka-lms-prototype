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

## Common routes

| If your question is... | Start here | Move elsewhere when... |
|---|---|---|
| "What is happening right now?" | `docs/status/active/` | You need durable proof, then use `docs/evidence/**` |
| "Are we ready to proceed?" | `docs/status/readiness/` | You need a hard gate proof pack, then use `docs/evidence/**` |
| "What is the migration posture?" | `docs/status/migrations/` | You need source-system facts, then use `docs/reference/migrations/**` |
| "What is the current weekly cadence?" | `docs/status/weekly/` | You need cold history, then move to `docs/archive/**` |
| "What is the current incident state?" | `docs/status/incidents/` | The incident is over and should be archived |

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

## Review standard

- A status document here should answer “what is the current state?” clearly and quickly.
- If the document mainly proves a claim, it belongs in `docs/evidence/**`.
- If the document is no longer active, move it to `docs/archive/**` instead of leaving it in the hot path.
