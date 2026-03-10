# Forum Meilisearch Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the current search backend posture for the forum service.

## Current truth

- The Python forum uses Meilisearch as its search backend.
- Elasticsearch is not the active forum search dependency.
- Repo verification lives in `scripts/qa/verify-forum-meilisearch.sh` and `scripts/qa/verify-forum-smoke.sh`.

## Where to look next

- runtime and routing procedure: [`../../ops/runbooks/RKE2_TENANT_ROUTES.md`](../../ops/runbooks/RKE2_TENANT_ROUTES.md)
- service migration contract: `specs/forum-service-migration_spec.md`

## Verification

- `bash scripts/qa/verify-forum-meilisearch.sh`
- `bash scripts/qa/verify-forum-smoke.sh`
