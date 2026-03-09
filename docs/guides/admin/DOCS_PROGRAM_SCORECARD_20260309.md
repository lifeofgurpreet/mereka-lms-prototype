# Docs Program Scorecard 20260309
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified (UTC): 2026-03-09T05:33:42Z • Status: supporting_

## KPI Snapshot
- Total docs scope: 1431
- Canonical docs: 74
- Stale canonical docs: 0
- Missing canonical owner: 0
- Missing canonical verified date: 0
- Missing canonical files: 0
- Canonical high-risk entries: 0
- Catalog score: 100 / threshold 80 (pass)
- Scorecard trend: base=100, current=100, drop=0, threshold=10, status=pass
- Command reference checks: pass (6 files, 0 missing)
- Command reference baseline coverage: enabled=true, entries=4
- Command reference source breakdown: inline=44, shell=33, md_link=0, md_autolink=0, md_refdef=0
- Link integrity checks: pass (0 files, 0 broken)

## Compliance Gate Snapshot
- Overall compliance status: pass
- catalog=pass, cmdref_baseline=pass, cmdref=pass, scorecard=pass, trend=pass
- recency=pass, consistency=pass, head_freshness=pass, timestamp=pass, delta=pass, drift=pass
- foundation_policy_range=origin/main...HEAD, root_allowlist_violations=0, changed_markdown_files=0
- foundation_policy_content_status=pass, foundation_policy_content_consistency=pass, foundation_policy_content_alignment=pass, foundation_policy_content_consistency_detail=unknown, foundation_policy_content_consistency_aligned=true, foundation_policy_content_consistent=true, foundation_policy_content_errors=0

## Evidence Inputs
- base_ref=origin/main
- verify-doc-catalog-health.py (summary + freshness gate)
- build-docs-scorecard.py (min-score gate)
- verify-doc-command-refs.sh (command/path references)
- verify-doc-link-integrity.sh (broken-doc-link references)
- compare-docs-scorecard-to-base.sh (base trend + regression threshold)
- build-docs-compliance-summary.py (consolidated status)

## Risk Notes
- Command references check is scoped to non-archive docs; update SKIP_PATH_PREFIXES if scope changes.
- Full scorecard pass is expected at target=80; trend fail requires governance review if score_drop > 10.

## Recommendation
- Publish this report at the same cadence as governance cycles and link from the closure readiness artifact.
