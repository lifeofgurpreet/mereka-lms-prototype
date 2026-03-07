# One-Week First-Class Docs Execution Plan

_Audience: Docs Team • Owner: Docs Lead • Last verified: 2026-03-06 • Status: supporting_

## Scope
This is a concrete PR-ready one-week execution package to continue from the current handover state in the isolated docs worktree branch (`docs/docs-first-class-20260307-followup-7`).

Use this as the next agent’s executable plan, not prose. Each day ends with a small PR and a closed tracker row.

## 1) Team Ownership Matrix

| Role | Owner | Decision Scope | Escalation |
|---|---|---|---|
| Docs Lead | Platform Docs Lead | Final quality gates, PR readiness, conflict resolution | `GOV` / `CLS` approval |
| Canonical Domain Owner | Domain SME (Ops / Branding / Onboarding / QA) | Canonical assignment and contradiction approvals | Domain Owner |
| Docs Operator | Assigned agent | Structural updates, link rewrites, metadata updates | Docs Lead |
| Reviewer | Reviewer + platform owner | Evidence sanity checks and command accuracy review | Docs Lead |

## 2) Hard Acceptance Gates (must be true before close)

- `docs/qa/verify-docs-policy.sh` passes.
- `./scripts/qa/verify-repo-structure.sh` passes.
- `docs/qa/verify-docs-scorecard-recency.sh --max-age-days 7` passes.
- `docs/qa/verify-docs-scorecard-head-freshness.sh` passes.
- Changed canonical docs include metadata (`Status`, `Owner`, `Last verified`) in subtitle or frontmatter.
- Every moved/renamed file has updated inbound+outbound links in the same PR.
- No `docs/` root files outside allowlist unless explicitly approved.
- Scorecard delta for the new week is published and attached to PR.

## 3) Day 1 — Sync, baseline, and lock scope

### AC-DOCS-101: Keep branch synced to latest `origin/main` every 20 minutes
- [ ] `cd /home/gurpreet/projects/k8s/mereka-lms-wt-docs-remediation`
- [x] `git fetch origin`
- [x] `git checkout docs/docs-first-class-20260307-followup-7`
- [x] `./docs/qa/run-docs-world-class-gates.sh --sync --sync-strategy auto --require-sync --max-age-seconds 1200`
- [x] Keep world-class gate `--base-ref` configurable (default `origin/main`) and reuse it for sync, policy range, and trend comparison.
- [x] World-class gate runner must fail fast when `--base-ref` cannot be resolved (`git rev-parse --verify "$BASE_REF"`).
- [x] Never `git checkout main` in this worktree; stay on the docs branch.
- [x] World-class gate runner must fail-fast on `main`/`master` and require a dedicated docs branch in the isolated worktree.
- [ ] Repeat sync at least every 20 minutes during long editing sessions.
- [ ] If branch push is rejected after rebase due remote race, run:
  - `git push --force-with-lease origin docs/docs-first-class-20260307-followup-7`
    (keeps branch rebased to latest `origin/main` while protecting against blind overwrite)
- [ ] If repeated rebase conflicts block sync, use controlled fallback:
  - `git rebase --abort` (if mid-rebase)
  - `git merge --no-edit origin/main`
  - resolve conflicts favoring stricter docs-gate behavior, then commit and push
- [x] `git status --short` is clean
- [x] `git rev-list --left-right --count origin/main...HEAD`

### AC-DOCS-102: Baseline for this execution week
- [x] Re-run baseline checks in branch:
  - `docs/qa/verify-docs-policy.sh`
  - `./scripts/qa/verify-repo-structure.sh`
- [x] Record `git rev-parse --short HEAD` and baseline in PR notes.
- [x] Before any large content-edit burst, run:
  - `./docs/qa/run-docs-world-class-gates.sh --sync --sync-strategy auto --require-sync --max-age-seconds 1200`
    (`1200s` defaults to 20 minutes)
- [x] Open/confirm existing blocker gates:
  - `GOV-01`, `GOV-02`, `CLS-02`

## 4) Day 2 — Command-accuracy hardening (code-reflective docs)

### AC-DOCS-201: Draft command reference verifier
- [x] Create a script: `docs/qa/verify-doc-command-refs.sh`
- [ ] Script must:
  - scan canonical docs for command snippets in fenced code blocks and inline command references;
  - parse markdown path targets in inline code, markdown links (`[x](docs/operations/TROUBLESHOOTING.md)`), and markdown autolinks (`<docs/operations/TROUBLESHOOTING.md>`);
  - validate each referenced command/script exists in repo (`scripts/**`, `.github/workflows/**`, canonical runbook commands);
  - emit summary JSON with stable schema even for zero-scope runs (include `candidate_sources` keys with zero values);
  - normalize missing `candidate_sources` keys to zero in consolidated compliance outputs.
  - normalize all `candidate_sources` values to nonnegative integers before emitting compliance/scorecard artifacts.
  - normalize malformed command-ref metric shapes (`candidate_sources` non-object, numeric strings, negative/non-numeric counts).
  - normalize `baseline_enabled` to a strict boolean in consolidated compliance outputs (`true|false` only).
  - normalize status fields from any input type to the canonical set (`pass|warn|fail|unknown`).
  - normalize malformed list fields to arrays and normalize list items to non-empty strings (`missing`, `broken`, `duplicates`, `invalid_non_markdown`, `policy_content_errors`).
  - preserve `baseline_enabled=true` / `baseline_entries=<n>` semantics even when effective scan scope is zero after filters.
  - preserve zero-scope schema for nonexistent explicit input paths (`baseline_enabled=false`, `baseline_entries=0`, all source counters zero).
  - verify consolidated compliance output normalizes `candidate_sources` keys to zero even when command-ref summary omits that object.
  - fail on missing or unresolved references.
- [ ] Use backlog snapshot for execution:
  - `docs/archive/reports/cmdref-backlog-snapshot-20260306.md`

### AC-DOCS-202: Seed initial high-risk doc checks
- [x] Apply checks at least to these documents:
  - `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`
  - `docs/ops/quickref/QUICK_REFERENCE.md`
  - `docs/guides/branding/BRANDING_OPERATOR_GUIDE.md`
  - `docs/ops/monitoring/OBSERVABILITY_PARITY_MATRIX.md`
- [x] Fix any broken references in the same PR.

## 5) Day 3 — CI pipeline enforcement

### AC-DOCS-301: Add docs compliance workflow
- [x] Add workflow: `.github/workflows/docs-compliance.yml`
- [x] Trigger: `on: [pull_request]` for paths under `docs/**` and command-verifier inputs.
- [x] Required jobs:
  - `verify-docs-policy`: run `docs/qa/verify-docs-policy.sh`
  - `verify-repo-structure`: run `./scripts/qa/verify-repo-structure.sh`
  - `verify-doc-command-refs`: run `docs/qa/verify-doc-command-refs.sh`
  - `verify-doc-link-integrity`: run docs link check scoped to changed files
- [x] PR gate must print status summary and fail hard on any command-reference miss.

### AC-DOCS-302: PR summary contract
- [x] Add a step/job output block that prints:
  - changed canonical docs count
  - broken links count
  - link-integrity files checked
  - command-reference files checked
  - command-reference total candidates
  - command-reference baseline enabled flag
  - command-reference baseline entries count
  - command-reference candidate source breakdowns (inline, shell, markdown-link, markdown-autolink, markdown-refdef)
  - stale canonical count
  - command-reference miss count
- [x] Resolve PR workflow base reference deterministically:
  - resolve once per workflow run and export via environment for downstream steps
  - compute `BASE_REF` with fallback to `origin/main` when `${{ github.base_ref }}` is empty
  - fail fast if resolved `BASE_REF` cannot be verified in git (`git rev-parse --verify "$BASE_REF"`)
  - reuse one `POLICY_RANGE="${BASE_REF}...${{ github.sha }}"` across policy, changed-doc scope, and foundation checks
- [x] `build-docs-compliance-summary.py` stdout contract must include:
  - `cmdref_baseline_enabled=<true|false>`
  - `cmdref_baseline_entries=<n>`

## 6) Day 4 — Scorecard + drift gates

### AC-DOCS-401: Weekly KPI scorecard (single source output)
- [x] Create/update `docs/guides/admin/DOCS_PROGRAM_SCORECARD_<YYYYMMDD>.md` for this week.
- [x] Generate from canonical tooling (do not hand-edit metrics):
  - `./docs/qa/generate-docs-scorecard-report.sh --date <YYYYMMDD>`
- [ ] Include at minimum:
  - canonical coverage %
  - duplicate canonical conflicts
  - broken links in changed scope
  - command-reference baseline coverage (`enabled`, `entries`) in both program and quality scorecards
  - program scorecard assertions verify baseline coverage values (not only heading presence)
  - command-reference candidate source breakdowns (inline, shell, markdown-link, markdown-autolink, markdown-refdef)
  - root policy violations
  - redirect-stub debt
- [x] Publish scorecard delta in handoff artifact.

### AC-DOCS-402: Stale canonical escalation policy
- [x] Run freshness scan against canonical docs in `docs/catalog.json`.
- [x] Run `python3 docs/qa/verify-doc-catalog-health.py --max-stale-days 45`.
- [x] Create follow-up tracker ticket per stale canonical (owner + due date).  
      No stale canonical files found; no tracker items needed for this run.

## 7) Day 5 — Merge readiness and closure continuity

### AC-DOCS-501: Governance closure prep
- [x] Confirm ownership and approvals are present:
  - `docs/archive/reports/governance-approval-note-20260306.md`
  - `docs/archive/reports/escalation-appendix-20260306.md`
  - `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`
- [x] Update `docs/archive/reports/program-closure-readiness-20260306.md` with final status.
- [x] Run final compliance checks + `git push`.

## 8) PR-ready template (copy/paste)

### PR Title
`docs: elevate documentation quality to first-class with command-accuracy and CI gates`

### PR Body checklist
- [ ] Scope: one-week hardening cycle complete
- [ ] Validation run:
  - `docs/qa/verify-docs-policy.sh`
  - `./scripts/qa/verify-repo-structure.sh`
  - `docs/qa/verify-doc-command-refs.sh` (new)
  - `python3 docs/qa/verify-doc-catalog-health.py --max-stale-days 45`
  - docs policy workflow passes
- [ ] Contradictions resolved:
  - onboarding / access / branding / runbooks clusters
- [ ] Scorecard delta attached
- [ ] Governance approvals linked in tracker thread

## 9) If only one PR can be made this cycle

Prioritize in this order:
1. `AC-DOCS-101` and `AC-DOCS-102`
2. `AC-DOCS-301` and `AC-DOCS-201`
3. `AC-DOCS-401`
4. Merge only after `AC-DOCS-501` is complete

## 10) Handoff continuity requirement

Before handoff to next agent, include:
- link to this plan file
- latest base hash (`git rev-parse --short HEAD`)
- gate statuses for `GOV-01`, `GOV-02`, `CLS-02`
- list of unresolved contradiction findings
