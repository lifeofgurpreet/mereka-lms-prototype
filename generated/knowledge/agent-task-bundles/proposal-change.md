<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: proposal change

- Purpose: Update proposal-only or RFC-style surfaces without presenting them as normative law.
- Why this bundle exists: Keeps proposal work from being mistaken for binding contract truth.
- What this bundle intentionally excludes: Does not authorize normative spec rewrites unless the task escalates.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/build-doc-catalog.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/verify-doc-catalog-governance.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `generated/catalogs/docs-catalog.json` [generated] Canonical entrypoint for domain `docs-control-plane`.
- `specs/frontend-performance-budgets_spec.md` [normative] Canonical entrypoint for domain `frontend`.
- `generated/knowledge/review-bundle.md` [generated] Canonical entrypoint for domain `frontend`.

## Surface Meaning
- Normative: specs/frontend-performance-budgets_spec.md
- Proposal: none
- Plan: none
- Generated: generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: docs/archive/**, specs/archive/**

## Reviewers And Evidence
- Reviewers: architecture, docs
- Evidence: review_bundle, status_update, truth_impact_report

## Validation Commands
- `python3 tools/knowledge/build_change_manifest.py --check --range origin/main...HEAD --repo-root .`
- `python3 tools/knowledge/build_review_bundle.py --check --range origin/main...HEAD --repo-root .`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_not_required`
- Repositories: none
- Reviewers: none
