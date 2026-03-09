<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: docs architecture change

- Purpose: Update architecture or governing documentation without changing spec topology.
- Why this bundle exists: Directs agents to governing architecture surfaces instead of broad docs spelunking.
- What this bundle intentionally excludes: Does not reopen Wave 4 root topology or spec taxonomy.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `architecture`.
- `docs/adr` [canonical] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/review-bundle.md` [generated] Canonical entrypoint for domain `architecture`.
- `generated/knowledge/truth-impact-report.json` [generated] Canonical entrypoint for domain `architecture`.
- `tools/docs/verify/build-doc-catalog.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/verify-doc-catalog-governance.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `generated/catalogs/docs-catalog.json` [generated] Canonical entrypoint for domain `docs-control-plane`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: docs/archive/**, generated catalogs as sole authority

## Reviewers And Evidence
- Reviewers: architecture, docs
- Evidence: review_bundle, status_update, truth_impact_report

## Validation Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_required`
- Repositories: bbi-infrastructure
- Reviewers: architecture, platform, release, security, tenancy_auth
