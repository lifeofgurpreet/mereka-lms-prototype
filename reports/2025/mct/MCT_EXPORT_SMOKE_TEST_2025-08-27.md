# MCT Export Script Smoke Test Results
_Audience: QA • Owner: Migration Squad • Last verified: 2025-08-27 • Status: historical_

This file preserves the historical smoke-test outcome from the initial MCT export implementation. It is evidence/history, not an active operator runbook.

## Summary

- Script implementation matched the expected working code path.
- Authentication logic was structurally correct.
- The tested credential sets had expired at the time of the run.

## Historical Result Snapshot

### Dry run
- Passed

### Credential set 1
- Result: expired secret (`AADSTS7000222`)

### Credential set 2
- Result: expired secret (`AADSTS7000222`)

### Implementation verification
- The implementation matched the reference authentication pattern at the time.

## Current Guidance

- Use [`../../../docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md`](../../../docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md) for the active export procedure.
- Use the canonical secret store for current credentials.
- Treat this file as historical evidence only.
