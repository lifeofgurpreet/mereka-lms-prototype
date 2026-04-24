# Task Bundle: architecture_or_adr_change

- Intent: Change architecture rationale, decision-ledger truth, or system model docs.

## Read First
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md` priority `1`: Fastest architecture-oriented entry path into canonical docs.
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md` priority `2`: Existing reviewer runtime model must remain authoritative.

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
- evidence: require_adr_update, require_runbook_update, require_status_update

## Cross-Repo Dependencies
- none

## Out Of Scope
- `docs/archive/**`

## Escalation Conditions
- runtime or deployment obligations shift without corresponding contract review
