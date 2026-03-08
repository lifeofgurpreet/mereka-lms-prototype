# Docs Quality Scorecard — 2026-03-07

- Branch: `fix/docs-compliance-drift-determinism`
- Last updated: `2026-03-07T23:24:03Z`
- Sync status: `origin/main` delta `0 9`

## One-Week Scorecard Delta (Docs Compliance Gates)

| Gate | Status | Evidence | Notes |
|---|---|---|---|
| `docs/qa/verify-docs-foundation-gates.sh` | pass | foundation summary | policy=pass, repo_structure=pass, policy_content_consistency=pass, policy_content_alignment=pass |
| `docs/qa/verify-docs-policy.sh` | pass | foundation policy metrics | consistency_status=pass, consistency_detail=unknown, consistency_aligned=true, range=HEAD...HEAD, root_allowlist_violations=0, consistent=true, content_errors=0 |
| `docs/qa/verify-doc-command-ref-baseline.sh` | pass | baseline summary | baseline file integrity contract, baseline_enabled=true, baseline_entries=4 |
| `docs/qa/verify-doc-command-refs.sh` | pass | command refs summary | docs command/path references, files=695, candidates=6317, inline=4428, shell=1887, md_link=1, md_autolink=1, md_refdef=0, missing_refs=0 |
| `docs/qa/verify-doc-link-integrity.sh` | unknown | link integrity summary | files=982, broken_links=0 |
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
