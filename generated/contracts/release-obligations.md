# Wave 6 Release Obligations

- Range: `origin/main...HEAD`
- Overall cross-repo verdict: `infra_counterpart_not_required`
- Required counterpart repos: none
- Required reviewers: none

## Service obligations

## Required infra follow-up


## Required evidence and runbook updates

- Evidence artifacts: none
- Runbook surfaces: none

## Required release and promotion notes

- Services requiring release-note treatment: none

## Reviewer checklist

- Confirm whether a counterpart `bbi-infrastructure` PR exists for every `infra_counterpart_required` service.
- Check all `manual_review_required` services for missing exact GitOps file paths before merge.
- Verify runbook and evidence surfaces moved with each deployment-affecting change.
- Treat secret-surface changes as blocked until security and platform review are present.

## Ignored surfaces

- `docs/catalog.json`, `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`, `docs/meta/knowledge/AGENT_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE10_CLOSEOUT.md`, `generated/catalogs/docs-catalog.json`, `generated/catalogs/knowledge-catalog.json`, `generated/contracts/cross-repo-manifest.json`, `generated/contracts/deployment-impact-report.json`, `generated/contracts/release-obligations.md`, `generated/graphs/knowledge-graph.json`, `generated/knowledge/agent-entrypoints.json`, `generated/knowledge/agent-task-bundles/cross-repo-contract-change.md`, `generated/knowledge/agent-task-bundles/docs-architecture-change.md`, `generated/knowledge/agent-task-bundles/evidence-status-update.md`, `generated/knowledge/agent-task-bundles/incident-debug.md`, `generated/knowledge/agent-task-bundles/migration-change.md`, `generated/knowledge/agent-task-bundles/normative-spec-change.md`, `generated/knowledge/agent-task-bundles/proposal-change.md`, `generated/knowledge/agent-task-bundles/release-change.md`, `generated/knowledge/agent-task-bundles/reviewer-pass.md`, `generated/knowledge/agent-task-bundles/wrapper-retirement.md`, `generated/knowledge/change-manifest.json`, `generated/knowledge/review-bundle.md`, `generated/knowledge/task-bundles/architecture_or_adr_change.json`, `generated/knowledge/task-bundles/architecture_or_adr_change.md`, `generated/knowledge/task-bundles/compatibility_or_wrapper_cleanup.json`, `generated/knowledge/task-bundles/compatibility_or_wrapper_cleanup.md`, `generated/knowledge/task-bundles/cross_repo_contract_change.json`, `generated/knowledge/task-bundles/cross_repo_contract_change.md`, `generated/knowledge/task-bundles/evidence_or_status_change.json`, `generated/knowledge/task-bundles/evidence_or_status_change.md`, `generated/knowledge/task-bundles/generated_surface_refresh.json`, `generated/knowledge/task-bundles/generated_surface_refresh.md`, `generated/knowledge/task-bundles/normative_spec_change.json`, `generated/knowledge/task-bundles/normative_spec_change.md`, `generated/knowledge/task-bundles/proposal_or_rfc_change.json`, `generated/knowledge/task-bundles/proposal_or_rfc_change.md`, `generated/knowledge/task-bundles/release_or_runtime_change.json`, `generated/knowledge/task-bundles/release_or_runtime_change.md`, `generated/knowledge/task-bundles/reviewer_handoff_or_policy_change.json`, `generated/knowledge/task-bundles/reviewer_handoff_or_policy_change.md`, `generated/knowledge/task-bundles/runbook_or_ops_change.json`, `generated/knowledge/task-bundles/runbook_or_ops_change.md`, `generated/knowledge/task-context-report.json`, `generated/knowledge/truth-impact-report.json`, `generated/knowledge/wave10-source-map.json`, `scripts/governance/script-registry.yaml`, `tools/knowledge/build_agent_readiness_report.py`, `tools/knowledge/build_agent_task_bundles.py`, `tools/knowledge/build_cross_repo_agent_packs.py`, `tools/knowledge/build_task_bundle.py`, `tools/knowledge/build_wave10_source_map.py`, `tools/knowledge/change_runtime.py`, `tools/knowledge/skill_runtime.py`, `tools/knowledge/verify_agent_consumption_runtime.py`, `verification/catalogs/verification_catalog.json`
