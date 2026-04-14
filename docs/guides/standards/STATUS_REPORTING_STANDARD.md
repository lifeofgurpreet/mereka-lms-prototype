---
title: Status Reporting Standard
owner: Platform Team
status: canonical
last_reviewed: 2026-03-08
last_verified: 2026-04-13
canonical_root: docs/guides/standards
doc_class: guide
audience:
  - contributors
summary: Defines the active reporting contract, status buckets, and rejection criteria for docs/status.
tags:
  - docs.status
  - docs.policy
---

# Status Reporting Standard

This standard defines the active reporting contract for `docs/status/**`.

## Authority

- Active status and readiness reporting MUST live under `docs/status/**`.
- `reports/**` is not an active reporting root for current operational truth.
- `docs/archive/reports/**` is cold storage only.

## Winning active roots

Use these status buckets:

- `docs/status/active/`
- `docs/status/readiness/`
- `docs/status/migrations/`
- `docs/status/weekly/`
- `docs/status/incidents/`

## Required status fields

Every active status document SHOULD include:

- owner
- date or reporting window
- scope
- current state
- explicit blockers or open risks
- next decision or next action

## What a good status document does

A good status document tells a reader:
1. what is true right now,
2. what is blocked or at risk,
3. what needs to happen next.

If the document mostly explains history, it is probably a report, not active status.

## Content rules

- Active status docs MUST describe current operational truth.
- Time-bound reports MUST move out of the hot path when they become historical.
- Status docs MUST NOT become a second architecture standard or long-term runbook.
- Status docs SHOULD link to current evidence packs when they make factual claims.

## Recommended structure

Use this structure unless the status type clearly needs a variation:

1. Scope
2. Current state
3. Blockers and risks
4. Evidence or proof links
5. Next action or next decision

## What gets rejected

- Status docs that only summarize completed work with no live decision value.
- Readiness docs that do not say who owns the go/no-go call.
- Migration status docs that omit current blockers or rollback posture.
- Incident/status docs that make factual claims without linking proof.
- Files that should be archived but still sit in active status roots.

## Migration and readiness guidance

- `docs/status/migrations/` is for active migration posture, not historical writeups.
- `docs/status/readiness/` is for go/no-go, readiness, and release posture.
- Once a status document stops representing live truth, it SHOULD be archived or superseded.

## Writing standard

- Put the current state in the first screenful.
- Prefer explicit state words such as `blocked`, `at risk`, `ready`, `not ready`, or `in progress`.
- Separate facts from planned actions.
- Link proof instead of restating the full evidence bundle.

## Archive rule

Do not keep active reporting in archive roots. If a status document is retained for history:

1. move it to cold storage or supersede it
2. leave a stub only when compatibility is required
3. keep the active root free of stale closures

## Related authority docs

- [Status Index](../../status/INDEX.md)
- [Documentation Index](../../README.md)
- [Docs / Specs Contract](./DOCS_SPECS_CONTRACT.md)
