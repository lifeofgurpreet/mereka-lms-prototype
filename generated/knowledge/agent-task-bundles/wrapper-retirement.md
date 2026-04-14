<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. Rebuild with tools/knowledge/build_agent_task_bundles.py -->
# Task Bundle: wrapper retirement

- Purpose: Remove compatibility surfaces only when canonical replacements and live references are settled.
- Why this bundle exists: Prevents agents from deleting compatibility surfaces without canonical replacement proof.
- What this bundle intentionally excludes: Does not treat generated inventories as sufficient proof without canonical replacement and zero live refs.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/build-doc-catalog.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `tools/docs/verify/verify-doc-catalog-governance.py` [canonical] Canonical entrypoint for domain `docs-control-plane`.
- `generated/catalogs/docs-catalog.json` [generated] Canonical entrypoint for domain `docs-control-plane`.
- `specs/standards/SPEC_SYSTEM_CHARTER.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `specs/standards/SPEC_METADATA_MODEL.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `specs/standards/SPEC_AUTHORING_STANDARD.md` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `tools/specs/verify_spec_frontmatter.py` [canonical] Canonical entrypoint for domain `specs-control-plane`.
- `tools/specs/verify_spec_taxonomy.py` [canonical] Canonical entrypoint for domain `specs-control-plane`.

## Surface Meaning
- Normative: none
- Proposal: none
- Plan: none
- Generated: generated/knowledge/agent-entrypoints.json, generated/knowledge/change-manifest.json, generated/knowledge/review-bundle.md, generated/knowledge/truth-impact-report.json
- Historical context only: compatibility wrappers as primary authority, docs/archive/**

## Reviewers And Evidence
- Reviewers: architecture, docs
- Evidence: review_bundle, status_update, truth_impact_report, wrapper_retirement_report

## Validation Commands
- `python3 tools/knowledge/build_wrapper_retirement_report.py --check --repo-root .`
- `bash scripts/qa/run-knowledge-runtime-gates.sh`

## Cross-Repo Fallout
- Overall verdict: `infra_counterpart_not_required`
- Repositories: none
- Reviewers: none
