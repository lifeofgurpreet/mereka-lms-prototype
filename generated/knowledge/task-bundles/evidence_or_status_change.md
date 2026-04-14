# Task Bundle: evidence_or_status_change

- Intent: Change evidence, status, readiness, or proof surfaces without altering the governing contract.

## Read First
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md` priority `1`: Wave 5 defines evidence and review runtime semantics.
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md` priority `2`: Wave 6 defines release and contract evidence semantics.

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
- `specs/archive/**`

## Escalation Conditions
- evidence claims move without corresponding runtime or contract updates
