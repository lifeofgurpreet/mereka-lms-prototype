# Migration Reference
_Audience: Migration operators and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root for factual migration reference: source-system inventories, API and payload reference, mapping tables, and review queues. Start here when the question is “what is the source system like?” or “what reference do I need to run the migration correctly?” Do not use this root for execution steps or live migration reporting.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Work on the Drive/Airtable pipeline | [`drive-airtable/README.md`](drive-airtable/README.md) | [`drive-airtable/REVIEW_QUEUE.md`](drive-airtable/REVIEW_QUEUE.md) |
| Work on Kajabi migration inputs | [`kajabi/README.md`](kajabi/README.md) | [`kajabi/OPS_KAJABI_README.md`](kajabi/OPS_KAJABI_README.md) |
| Work on MCT migration reference | [`mct/README.md`](mct/README.md) | [`mct/DOCUMENTATION_INDEX.md`](mct/DOCUMENTATION_INDEX.md) |
| Look up the full MCT API surface | [`mct/API_COMPLETE_REFERENCE.md`](mct/API_COMPLETE_REFERENCE.md) | [`mct/api-endpoints/README.md`](mct/api-endpoints/README.md) |
| Check migration progress rather than source reference | [`../../status/migrations/README.md`](../../status/migrations/README.md) | The active migration status document there |

## Use this directory for

- migration source-system reference
- API and payload reference used during migration work
- review queues and migration-specific lookup material
- stable migration inventories that support runbooks and status tracking

## Domains

- [`drive-airtable/README.md`](drive-airtable/README.md) for Drive to Airtable migration reference
- [`drive-airtable/REVIEW_QUEUE.md`](drive-airtable/REVIEW_QUEUE.md) for the Drive/Airtable review queue
- [`kajabi/README.md`](kajabi/README.md) for Kajabi migration reference
- [`kajabi/OPS_KAJABI_README.md`](kajabi/OPS_KAJABI_README.md) for Kajabi operator notes and source reference
- [`mct/README.md`](mct/README.md) for MCT migration reference
- [`mct/API_COMPLETE_REFERENCE.md`](mct/API_COMPLETE_REFERENCE.md) for complete MCT API reference
- [`mct/API_ENDPOINTS_TEMPLATE.md`](mct/API_ENDPOINTS_TEMPLATE.md) for endpoint reference templates
- [`mct/DOCUMENTATION_INDEX.md`](mct/DOCUMENTATION_INDEX.md) for MCT documentation navigation
- [`mct/PROGRAMS_QUICK_REFERENCE.md`](mct/PROGRAMS_QUICK_REFERENCE.md) for program mappings
- [`mct/QUICK_REFERENCE_USER_IMPORT.md`](mct/QUICK_REFERENCE_USER_IMPORT.md) for user import reference

## Do not use this directory for

- execution procedures, which belong in `docs/ops/runbooks/**`
- active migration status, which belongs in `docs/status/migrations/**`
- historical migration closeout, which belongs in archive or report surfaces

## How To Use This Root Well

1. Start here for source truth and lookup material.
2. If you need a step-by-step migration procedure, move to [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md).
3. If you need to know what is currently blocked, ready, or finished, move to [`../../status/migrations/README.md`](../../status/migrations/README.md).
