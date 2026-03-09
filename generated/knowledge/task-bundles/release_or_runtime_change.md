# Task Bundle: release_or_runtime_change

- Intent: Change release, deployment, runtime, or evidence-convergence behavior.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/truth-impact-report.json`
- `generated/knowledge/review-bundle.md`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`

## Affected Truth Surfaces
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/knowledge/wrapper-retirement-report.json`
- `scripts/qa/run-cross-repo-contract-gates.sh`
- `scripts/qa/run-knowledge-integrity-gates.sh`
- `scripts/qa/run-knowledge-runtime-gates.sh`
- `scripts/qa/run-spec-integrity-gates.sh`
- `scripts/qa/scan-hubspot-credentials.sh`
- `scripts/qa/spec-tools/build_spec_catalog.py`
- `scripts/qa/spec-tools/extract_manual_entries.py`
- `scripts/qa/spec-tools/mereka_spec_verify.py`
- `scripts/qa/spec-tools/render_index.py`
- `scripts/qa/spec-tools/spec_coverage_report.py`
- `scripts/qa/spec-tools/spec_lint.py`
- `scripts/qa/spec-tools/spec_verify.py`
- `scripts/qa/verify-brand-pack-schema.sh`
- `scripts/qa/verify-hubspot-alerts.sh`
- `scripts/qa/verify-hubspot-k8s-security.sh`
- `scripts/qa/verify-hubspot-registration.sh`
- `scripts/qa/verify-hubspot-secrets.sh`
- `scripts/qa/verify-mfe-css-architecture.sh`
- `scripts/qa/verify-mobile-deployment.sh`
- `scripts/qa/verify-mobile-secrets-inventory.sh`
- `scripts/qa/verify-mobile-secrets-runtime.sh`
- `scripts/qa/verify-mobile-token-parity.sh`
- `scripts/qa/verify-paragon-json-token-hierarchy.sh`
- `scripts/qa/verify-paragon-runtime.sh`
- `scripts/qa/verify-paragon-theme-urls.sh`
- `scripts/qa/verify-paragon-token-coverage.sh`
- `scripts/qa/verify-paragon-tokens.sh`
- `scripts/qa/verify-proctoring-advanced.sh`
- `scripts/qa/verify-proctoring-environment.sh`
- `scripts/qa/verify-proctoring-integration.sh`
- `scripts/qa/verify-proctoring.sh`
- `scripts/qa/verify-spec-coverage.sh`
- `scripts/qa/verify-theming-generated-artifacts.sh`
- `scripts/qa/verify_adr_governs_vocabulary.py`
- `scripts/qa/verify_adr_suite.sh`
- `specs/k8s-deployment_spec.md`
- `specs/plans/k8s-deployment_plan.md`
- `specs/plans/k8s-deployment_testplan.md`
- `tools/contracts/build_cross_repo_manifest.py`
- `tools/contracts/build_deployment_impact_report.py`
- `tools/contracts/build_release_obligations.py`
- `tools/contracts/contract_runtime.py`
- `tools/contracts/verify_cross_repo_contracts.py`
- `tools/docs/verify/report-hotpath-doc-metadata.py`
- `tools/docs/verify/verify-legacy-testmaps-frozen-test.sh`
- `tools/docs/verify/verify-legacy-testmaps-frozen.py`

## Required Reviewers
- `architecture`
- `docs`
- `platform`
- `release`
- `security`
- `tenancy_auth`

## Required Evidence
- `release_obligations`
- `require_adr_update`
- `require_evidence_pack`
- `require_plan_refresh`
- `require_runbook_update`
- `require_status_update`
- `require_testplan_refresh`
- `reviewer_bundle`
- `runbook_reference`
- `truth_impact_report`

## Required Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Likely Cross-Repo Dependencies
- `openedx` -> verdict `manual_review_required`; reviewers: architecture, platform, release

## Out Of Scope
- architecture history edits unless explicitly required
- new deployment topology debates
- wrapper-retirement work that does not block runtime truth

## Escalation Conditions
- mixed task overlaps with architecture_or_adr_change
- mixed task overlaps with cross_repo_contract_change
