# Docs Quality Scorecard — 2026-03-07

- Branch: `docs/docs-first-class-20260307-followup-4`
- Last updated: `2026-03-07T00:28:40Z`
- Sync status: `origin/main` delta `0 8`

## One-Week Scorecard Delta (Docs Compliance Gates)

| Gate | Status | Evidence | Notes |
|---|---|---|---|
| `docs/qa/verify-doc-command-ref-baseline.sh` | pass | baseline summary | baseline file integrity contract |
| `docs/qa/verify-doc-command-refs.sh` | pass | command refs summary | docs command/path references |
| `docs/qa/verify-docs-scorecard-recency.sh` | pass | scorecard recency summary | max-age-days contract |
| `docs/qa/verify-docs-scorecard-report-consistency.sh` | pass | consistency summary | filename/title date contract |
| `docs/qa/verify-docs-scorecard-head-freshness.sh` | pass | head freshness summary | latest report aligned with HEAD date |
| `docs/qa/verify-docs-scorecard-report-timestamp.sh` | pass | timestamp summary | Last verified (UTC) metadata contract |
| `docs/qa/verify-docs-scorecard-delta-artifact.sh` | pass | delta artifact summary | quality/program date pairing contract |
| `docs/qa/build-docs-compliance-summary.py` | pass | compliance summary | consolidated docs compliance status |

## Next Cycle

1. Regenerate both scorecards at cycle start.
2. Keep this artifact linked in the active PR and closure memo.
3. Escalate governance blockers: `GOV-01`, `GOV-02`, `CLS-02`.
