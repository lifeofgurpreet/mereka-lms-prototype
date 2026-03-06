# Docs Program Scorecard 20260307
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified (UTC): 2026-03-06T23:29:22Z • Status: supporting_

## KPI Snapshot
- Total docs scope: 991
- Canonical docs: 18
- Stale canonical docs: 0
- Missing canonical owner: 0
- Missing canonical verified date: 0
- Missing canonical files: 0
- Canonical high-risk entries: 0
- Catalog score: 100 / threshold 80 (pass)
- Scorecard trend: base=100, current=100, drop=0, threshold=10, status=pass
- Command reference checks: pass (1 files, 0 missing)

## Evidence Inputs
- base_ref=origin/main
- verify-doc-catalog-health.py (summary + freshness gate)
- build-docs-scorecard.py (min-score gate)
- verify-doc-command-refs.sh (command/path references)
- compare-docs-scorecard-to-base.sh (base trend + regression threshold)

## Risk Notes
- Command references check is scoped to non-archive docs; update SKIP_PATH_PREFIXES if scope changes.
- Full scorecard pass is expected at target=80; trend fail requires governance review if score_drop > 10.

## Recommendation
- Publish this report at the same cadence as governance cycles and link from the closure readiness artifact.
