# Enrollment Comparison Quickstart
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2026-03-10 • Status: canonical_

Use this reference when reconciling legacy Kajabi enrollments against Open edX after migration work.

## Inputs

- Kajabi exports
- Open edX enrollment export
- comparison scripts under `scripts/migrations/kajabi/**`

## Outputs

- comparison CSVs and summary files under the Kajabi migration output path
- discrepancy counts that drive remediation or certificate follow-up

## Related docs

- [`../../ops/runbooks/migrations/kajabi/README.md`](../../ops/runbooks/migrations/kajabi/README.md)
- [`DATA_SOURCES_EXPLAINED.md`](DATA_SOURCES_EXPLAINED.md)
