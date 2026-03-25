# Active Status Reports
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory is the active status surface for open operational, program, and remediation tracking that is still relevant to current work. Start here when the question is “what is in flight right now?” rather than “are we ready?” or “what proof do we have?”

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Check the current docs-control-plane posture | [DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md](DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md) | [`../../meta/docs-program/README.md`](../../meta/docs-program/README.md) |
| Check active frontend/platform follow-up work | [FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md](FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md) | [FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md](FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md) |
| Check observability work still in flight | [OBSERVABILITY_REMAINING_WORK_2026-02-27.md](OBSERVABILITY_REMAINING_WORK_2026-02-27.md) | [OBSERVABILITY_ROADMAP_MEREKA_LMS.md](OBSERVABILITY_ROADMAP_MEREKA_LMS.md) |
| Check whether an item belongs in status at all | [`../INDEX.md`](../INDEX.md) | [`../../guides/standards/STATUS_REPORTING_STANDARD.md`](../../guides/standards/STATUS_REPORTING_STANDARD.md) |

## Use this directory for

- active operational status notes
- current program tracking
- open follow-up lists
- in-flight platform work summaries

## Do not use this directory for

- readiness reports that belong in `docs/status/readiness/`
- migration-specific status that belongs in `docs/status/migrations/`
- historical or closed reporting that belongs in archive or other cold surfaces

## Authority rule

Files here are part of the active reporting root under `docs/status/**`.

Do not create new active status docs under legacy `reports/**` paths.

## Current active reports

| Report | Use it when... |
|---|---|
| [BACKUP_TOOLING_STATUS.md](BACKUP_TOOLING_STATUS.md) | You need the current backup-tooling status. |
| [CI_OPTIMIZATION_TRACKER.md](CI_OPTIMIZATION_TRACKER.md) | You need current CI optimization work tracking. |
| [DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md](DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md) | You need the current docs control-plane closure state. |
| [DEV_STAGING_TRUTH_TRACKER_2026-03-25.md](DEV_STAGING_TRUTH_TRACKER_2026-03-25.md) | You need the current cross-repo truth tracker for DEV/staging operational closure. |
| [DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md](DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md) | You need a direct handoff brief for the next agent working the DEV/staging truth lane. |
| [FOLLOW_UPS_2026-01-20.md](FOLLOW_UPS_2026-01-20.md) | You need outstanding follow-up items still considered active. |
| [FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md](FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md) | You need active CI simplification work for frontend. |
| [FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md](FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md) | You need the frontend closure status matrix. |
| [FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md](FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md) | You need current frontend runtime stability posture. |
| [INFRA_TEAM_ACTION_ITEMS.md](INFRA_TEAM_ACTION_ITEMS.md) | You need the current infra action list. |
| [NEXT-PHASE-ROADMAP.md](NEXT-PHASE-ROADMAP.md) | You need the active next-phase roadmap. |
| [OBSERVABILITY_ENHANCEMENT_PLAN.md](OBSERVABILITY_ENHANCEMENT_PLAN.md) | You need the current observability enhancement plan. |
| [OBSERVABILITY_REMAINING_WORK_2026-02-27.md](OBSERVABILITY_REMAINING_WORK_2026-02-27.md) | You need the current remaining observability work. |
| [OBSERVABILITY_REVIEW_AND_FIRST_CLASS_WORKPLAN_2026-02-25.md](OBSERVABILITY_REVIEW_AND_FIRST_CLASS_WORKPLAN_2026-02-25.md) | You need the active observability review/workplan. |
| [OBSERVABILITY_ROADMAP_MEREKA_LMS.md](OBSERVABILITY_ROADMAP_MEREKA_LMS.md) | You need the broader active observability roadmap. |
| [PLUGIN_SPLIT_STATUS_2026-03-02.md](PLUGIN_SPLIT_STATUS_2026-03-02.md) | You need plugin-split progress state. |
| [ULMO_DEV_STAGING_PARITY.md](ULMO_DEV_STAGING_PARITY.md) | You need parity tracking for the Ulmo/dev-staging surface. |
| [blocked-epics.md](blocked-epics.md) | You need the current blocked-epics view. |

## What this root is not

- Not the place for readiness judgments. Use `docs/status/readiness/**`.
- Not the place for migration-focused reporting. Use `docs/status/migrations/**`.
- Not the place for raw proof. Use `docs/evidence/**`.
