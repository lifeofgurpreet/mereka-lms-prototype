# Task Bundle: normative_spec_change

- Intent: Change normative product, platform, or policy contract truth.

## Read First
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` priority `1`: Wave 4 remains the topology and authority baseline.
- `specs/standards/SPEC_SYSTEM_CHARTER.md` priority `2`: Governs normative spec intent and contract scope.
- `specs/standards/SPEC_METADATA_MODEL.md` priority `3`: Governs normative spec metadata obligations.
- `specs/standards/SPEC_AUTHORING_STANDARD.md` priority `4`: Governs normative authoring and boundary rules.

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
- reviewers: none
- evidence: none

## Cross-Repo Dependencies
- none

## Out Of Scope
- `docs/archive/**`
- `specs/archive/**`
- `specs/proposals/**`

## Escalation Conditions
- cross-repo contract surfaces are also touched
- release/runtime validators change in the same packet
