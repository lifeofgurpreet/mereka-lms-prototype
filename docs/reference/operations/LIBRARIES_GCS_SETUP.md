# Libraries GCS Setup Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the storage expectations for Content Libraries v2.

## Current storage truth

- Content libraries depend on GCS-backed Blockstore storage.
- Terraform storage ownership lives under `infrastructure/terraform/modules/storage/`.
- The expected bucket name used in repo checks is `lms-blockstore`.
- the Blockstore service account needs bucket read/write permissions for that bucket

## What this file is for

- confirming that content-library storage is expected to be GCS-backed
- pointing operators to the owning infra and verification surfaces
- keeping Blockstore storage facts out of unrelated runbooks

## Verification

- `bash scripts/qa/verify-libraries-foundation.sh`

## Related docs

- [`../../ops/runbooks/CONTENT_LIBRARIES_V2_MIGRATION.md`](../../ops/runbooks/CONTENT_LIBRARIES_V2_MIGRATION.md)
- [content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md) remains background context only.
