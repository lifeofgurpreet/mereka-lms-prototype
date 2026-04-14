# Task Bundle: generated_surface_refresh

- Intent: Refresh generated catalogs, graphs, manifests, bundles, and indexes without changing governing policy.

## Read First
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md` priority `1`: Generated surfaces still derive from Wave 4 topology.

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
- `generated/knowledge/task-bundles/runbook_or_ops_change.json`
- `generated/knowledge/task-bundles/runbook_or_ops_change.md`

## Reviewers And Evidence
- reviewers: docs
- evidence: require_adr_update, require_runbook_update, require_status_update

## Cross-Repo Dependencies
- none

## Out Of Scope
- `docs/archive/**`
- `specs/archive/**`

## Escalation Conditions
- generated output drifts after source updates
