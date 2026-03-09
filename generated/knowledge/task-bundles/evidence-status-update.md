<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: evidence status update

- Purpose: Update evidence, status, or closeout surfaces without pretending they are normative law.
- Why this bundle exists: Keeps evidence and status updates grounded in actual obligations instead of narrative-only summaries.
- What this bundle intentionally excludes: Does not treat status docs as a source of normative behavior.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/build-doc-catalog.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/verify-doc-catalog-governance.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `generated/catalogs/docs-catalog.json` [generated] Canonical entrypoint for domain `docs-control-plane`.
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` [canonical] Canonical entrypoint for domain `runtime/release`.
- `generated/contracts/release-obligations.md` [generated] Canonical entrypoint for domain `runtime/release`.
- `generated/contracts/deployment-impact-report.json` [generated] Canonical entrypoint for domain `runtime/release`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/contracts/cross-repo-manifest.json, generated/contracts/deployment-impact-report.json, generated/contracts/release-obligations.md, generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: docs/archive/**, generated outputs without upstream source

## Reviewers And Evidence
- Reviewers: architecture, docs, platform
- Evidence: incident_notes, release_obligations, review_bundle, runtime_evidence, status_update, truth_impact_report

## Validation Commands
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `bash scripts/qa/run-knowledge-runtime-gates.sh`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
