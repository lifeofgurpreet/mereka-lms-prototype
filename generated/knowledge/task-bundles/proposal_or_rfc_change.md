# Task Bundle: proposal_or_rfc_change

- Intent: Change proposal-lane, RFC, or future-shape design material.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` priority `1`: Keeps proposal work aligned with canonical topology.
- `specs/proposals/README.md` priority `2`: Governs proposal-lane meaning and boundaries.

## Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/specs/verify_spec_frontmatter.py --repo-root .`
- `python3 tools/specs/verify_spec_taxonomy.py --repo-root .`
- `python3 tools/specs/verify_spec_paths.py --repo-root .`
- `python3 tools/specs/verify_docs_specs_boundary.py --repo-root .`
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
- reviewers: docs
- evidence: require_adr_update, require_runbook_update, require_status_update

## Cross-Repo Dependencies
- none

## Out Of Scope
- `specs/archive/**`
- `docs/archive/**`

## Escalation Conditions
- root normative specs are touched in the same packet
