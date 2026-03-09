# Task Bundle: proposal_or_rfc_change

- Intent: Change non-normative proposal, RFC, or future-shape design truth.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `specs/proposals/README.md`
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`

## Affected Truth Surfaces
- `specs/proposals/README.md`
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`

## Required Reviewers

## Required Evidence

## Required Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/specs/verify_spec_frontmatter.py --repo-root .`
- `python3 tools/specs/verify_spec_taxonomy.py --repo-root .`
- `python3 tools/specs/verify_spec_paths.py --repo-root .`
- `python3 tools/specs/verify_docs_specs_boundary.py --repo-root .`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Likely Cross-Repo Dependencies
- none

## Out Of Scope
- normative contract edits in root specs
- runtime rollout or release obligations
- retroactive ADR rewriting

## Escalation Conditions
- mixed task overlaps with normative_spec_change
- mixed task overlaps with cross_repo_contract_change
