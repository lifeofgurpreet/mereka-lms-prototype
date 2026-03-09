# Readiness Reports
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory is the active readiness surface for go/no-go assessments, environment readiness, and implementation readiness reporting. Start here when the question is “are we ready?” rather than “what happened?” or “what proof exists?”

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Check environment or rollout readiness | The most relevant report in this root | `../active/README.md` if the need is ongoing status rather than readiness judgment |
| Check whether proof exists for a readiness claim | The relevant readiness report here | [`../../evidence/operations/README.md`](../../evidence/operations/README.md) |
| Understand the reporting boundary | [`../INDEX.md`](../INDEX.md) | [`../../guides/standards/STATUS_REPORTING_STANDARD.md`](../../guides/standards/STATUS_REPORTING_STANDARD.md) |

## Use this directory for

- readiness assessments
- environment go/no-go reports
- rollout readiness notes
- preflight or readiness follow-up reports that are still active

## Do not use this directory for

- routine active status tracking that belongs in `docs/status/active/`
- migration progress notes that belong in `docs/status/migrations/`
- cold historical readiness reports that should be archived

## Authority rule

Files here are part of the active reporting root under `docs/status/**`.

Legacy `reports/2026/readiness/**` is a compatibility surface only.

## Current readiness reports

| Report | Use it when... |
|---|---|
| [CREDENTIALS_READINESS.md](CREDENTIALS_READINESS.md) | You need readiness judgment for the credentials surface. |
| [DRY_RUN_RESULTS_2026-02-03.md](DRY_RUN_RESULTS_2026-02-03.md) | You need the dry-run readiness outcome and follow-up posture. |
| [ENTERPRISE_DOMAIN_READINESS_REPORT_2026-02-28.md](ENTERPRISE_DOMAIN_READINESS_REPORT_2026-02-28.md) | You need enterprise domain readiness status. |
| [NOTIFICATIONS_TRACKER_READINESS_SECOND_PASS.md](NOTIFICATIONS_TRACKER_READINESS_SECOND_PASS.md) | You need readiness posture for notifications tracker work. |
| [OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md](OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md) | You need observability readiness judgment. |
| [PROCTORING_IMPLEMENTATION_READINESS.md](PROCTORING_IMPLEMENTATION_READINESS.md) | You need implementation readiness for proctoring. |
| [PROCTORING_VENDOR_READINESS.md](PROCTORING_VENDOR_READINESS.md) | You need vendor-readiness posture for proctoring. |
| [TENANT_BRANDING_READINESS_RAG.md](TENANT_BRANDING_READINESS_RAG.md) | You need tenant-branding readiness judgment. |
| [tenant-hosting-readiness.md](tenant-hosting-readiness.md) | You need readiness posture for tenant hosting. |

## What this root is not

- Not the place for raw proof artifacts. Those belong in `docs/evidence/**`.
- Not the place for day-to-day progress updates. Those belong in `docs/status/active/**`.
- Not the place for migration-progress reporting. That belongs in `docs/status/migrations/**`.
