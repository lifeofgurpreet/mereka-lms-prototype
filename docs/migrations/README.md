# Migration Runbooks
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2026-03-05_

Every large-scale content or user migration lives under this folder. Pick the domain below to jump into the relevant export/import guides, verification plans, and rollback checklists.

| Domain | Entry Doc | Focus | Last Verified |
| --- | --- | --- | --- |
| Kajabi | [`kajabi/README.md`](kajabi/README.md) | Canonical export -> transform -> import playbook plus QA/rollback notes. | 2025-11-09 |
| MCT | [`mct/README.md`](mct/README.md) | Legacy Microsoft Community Training migration docs and API research. | 2025-08-31 |
| Drive + Airtable Video Inventory | [`drive-airtable/README.md`](drive-airtable/README.md), [`drive-airtable/STATUS.md`](drive-airtable/STATUS.md), [`drive-airtable/REVIEW_QUEUE.md`](drive-airtable/REVIEW_QUEUE.md) | Course-first pipeline with migration-readiness gates, blocker tracking, subtitle integrity checks, and Open edX handoff mapping. | 2026-03-05 |

**Adding another system?** Create `docs/migrations/<system>/README.md`, mirror the metadata block, and cross-link it from here and the global docs index.
