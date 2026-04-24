# Task Bundle: release_or_runtime_change

- Intent: Change release, deployment, runtime, or validator behavior affecting shipped reality.

## Read First
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` priority `1`: Governs release evidence and reviewer requirements.
- `docs/meta/contracts/INFRA_CROSSWALK.md` priority `2`: Shows what else must move in GitOps.
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md` priority `3`: Keeps runtime changes aligned with reviewer flow.

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
- deployment-affecting services span multiple review groups
- security review is implicated
