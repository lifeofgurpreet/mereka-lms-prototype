# Docs Quality Scorecard — 2026-03-09

- Branch: `docs/docs-wave4-scorecard-refresh-20260309`
- Last updated: `2026-03-09T02:49:31Z`
- Sync status: `origin/main` delta `0 1`

## One-Week Scorecard Delta (Docs Compliance Gates)

| Gate | Status | Evidence | Notes |
|---|---|---|---|
| `tools/docs/verify/verify-docs-foundation-gates.sh` | pass | foundation summary | policy=pass, repo_structure=pass, policy_content_consistency=pass, policy_content_alignment=pass |
| `tools/docs/verify/verify-docs-policy.sh` | pass | foundation policy metrics | consistency_status=pass, consistency_detail=unknown, consistency_aligned=true, range=origin/main...HEAD, root_allowlist_violations=0, consistent=true, content_errors=0 |
| `tools/docs/verify/verify-doc-command-ref-baseline.sh` | pass | baseline summary | baseline file integrity contract, baseline_enabled=true, baseline_entries=4 |
| `tools/docs/verify/verify-doc-command-refs.sh` | pass | command refs summary | docs command/path references, files=6, candidates=77, inline=44, shell=33, md_link=0, md_autolink=0, md_refdef=0, missing_refs=0 |
| `tools/docs/verify/verify-doc-link-integrity.sh` | unknown | link integrity summary | files=0, broken_links=0 |
| `tools/docs/verify/verify-docs-scorecard-recency.sh` | pass | scorecard recency summary | max-age-days contract |
| `tools/docs/verify/verify-docs-scorecard-report-consistency.sh` | pass | consistency summary | filename/title date contract |
| `tools/docs/verify/verify-docs-scorecard-head-freshness.sh` | pass | head freshness summary | latest report aligned with HEAD date |
| `tools/docs/verify/verify-docs-scorecard-report-timestamp.sh` | pass | timestamp summary | Last verified (UTC) metadata contract |
| `tools/docs/verify/verify-docs-scorecard-delta-artifact.sh` | pass | delta artifact summary | quality/program date pairing contract |
| `tools/docs/scorecards/build-docs-compliance-summary.py` | pass | compliance summary | consolidated docs compliance status |

## Next Cycle

1. Regenerate both scorecards at cycle start.
2. Keep this artifact linked in the active PR and closure memo.
3. Escalate governance blockers: `GOV-01`, `GOV-02`, `CLS-02`.
