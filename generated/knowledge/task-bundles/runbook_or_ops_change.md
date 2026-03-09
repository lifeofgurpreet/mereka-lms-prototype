# Task Bundle: runbook_or_ops_change

- Intent: Change operational guidance, incident procedure, or maintenance instruction.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`

## Affected Truth Surfaces
- `docs/catalog.json`
- `docs/ops/quickref/verification-scripts.md`
- `docs/ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`
- `docs/ops/runbooks/FORUM_SERVICE_RUNBOOK.md`
- `docs/ops/runbooks/MOBILE_APPS_RUNBOOK.md`
- `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`
- `generated/catalogs/knowledge-catalog.json`

## Required Reviewers
- `docs`

## Required Evidence
- `require_adr_update`
- `require_runbook_update`
- `require_status_update`

## Required Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Likely Cross-Repo Dependencies
- none

## Out Of Scope
- normative product contract changes
- GitOps topology redesign
- generated-surface-only refresh

## Escalation Conditions
- mixed task overlaps with release_or_runtime_change
- mixed task overlaps with cross_repo_contract_change
