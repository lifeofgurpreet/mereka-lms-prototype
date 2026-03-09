# Task Bundle: evidence_or_status_change

- Intent: Change evidence, proof, status, or readiness surfaces without changing core contracts.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`

## Affected Truth Surfaces
- `docs/archive/evidence/operations/evidence/spec-dedupe-normalize-report.md`
- `docs/catalog.json`
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`
- `docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md`
- `docs/meta/docs-program/README.md`
- `docs/meta/docs-program/SPEC_COVERAGE.md`
- `docs/meta/docs-program/WAVE3_CLOSEOUT.md`
- `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`
- `docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md`
- `docs/meta/docs-program/WAVE4_CHARTER.md`
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md`
- `docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md`
- `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`
- `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md`
- `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`
- `docs/meta/docs-program/metadata/METADATA_MODEL.md`
- `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
- `docs/meta/docs-program/metadata/frontmatter-schema.json`
- `docs/meta/docs-program/metadata/governs-taxonomy.yaml`
- `docs/meta/knowledge/CHANGE_CLASSES.yaml`
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/knowledge/EVIDENCE_OBLIGATIONS.yaml`
- `docs/meta/knowledge/OWNERSHIP_MAP.yaml`
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/knowledge/REVIEW_RULES.yaml`
- `docs/meta/knowledge/WAVE5_EXECUTION_TRACKER.md`
- `docs/meta/skills/AGENT_SKILL_CHARTER.md`
- `docs/meta/skills/SKILL_BUNDLE_RULES.yaml`
- `docs/meta/skills/TASK_TYPE_TAXONOMY.yaml`
- `docs/meta/skills/WAVE7_EXECUTION_TRACKER.md`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`
- `specs/_generated/testmaps/README.md`
- `specs/_generated/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/_generated/testmaps/mobile-apps-secrets-management_spec.testmap.yml`
- `specs/_generated/testmaps/paragon-design-tokens-migration_spec.testmap.yml`
- `specs/testmaps/RETIREMENT_PLAN.md`
- `specs/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/testmaps/mobile-apps-secrets-management_spec.testmap.yml`

## Required Reviewers
- `architecture`
- `docs`
- `platform`

## Required Evidence
- `require_adr_update`
- `require_evidence_pack`
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
- `openedx` -> verdict `manual_review_required`; reviewers: architecture, platform, release

## Out Of Scope
- contract changes without corresponding source edits
- new reviewer policy invention
- runtime or infra behavior changes

## Escalation Conditions
- mixed task overlaps with normative_spec_change
- mixed task overlaps with release_or_runtime_change
