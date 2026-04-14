# Task Bundle: cross_repo_contract_change

- Intent: Change service, environment, release, or cross-repo deployment contract truth.

## Read First
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md` priority `1`: Wave 6 defines the cross-repo contract runtime law.
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml` priority `2`: Defines repo ownership and mandatory review groups.
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` priority `3`: Defines release and evidence obligations.
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml` priority `4`: Defines environment and deployment surfaces.
- `docs/meta/contracts/INFRA_CROSSWALK.md` priority `5`: Defines the app-to-infra crosswalk boundary.

## Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/knowledge/resolve_task_context.py --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/resolve_task_context.py --check --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Related Contracts
- `none`

## Related Specs
- `none`

## Related Runbooks
- `none`

## Reviewers And Evidence
- reviewers: architecture, docs
- evidence: release_obligations, require_adr_update, require_runbook_update, require_status_update, reviewer_bundle, truth_impact_report

## Cross-Repo Dependencies
- none

## Out Of Scope
- `docs/archive/**`
- `specs/archive/**`

## Escalation Conditions
- Wave 6 verdict is manual_review_required
- Wave 6 verdict is unknown_mapping
