# Task Bundle: cross_repo_contract_change

- Intent: Change service, deployment, environment, or release contract truth across repos.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `generated/contracts/cross-repo-manifest.json`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`
- `generated/contracts/cross-repo-manifest.json`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`

## Affected Truth Surfaces
- `deploy/contracts/infra-crosswalk.yaml`
- `deploy/contracts/service-contracts/enterprise-services.yaml`
- `deploy/contracts/service-contracts/mfe.yaml`
- `deploy/contracts/service-contracts/observability-runtime.yaml`
- `deploy/contracts/service-contracts/openedx.yaml`
- `deploy/contracts/service-contracts/purchase-gateway.yaml`
- `deploy/contracts/service-contracts/runner-ci.yaml`
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`
- `generated/contracts/cross-repo-manifest.json`
- `generated/contracts/deployment-impact-report.json`
- `generated/contracts/release-obligations.md`
- `tools/contracts/build_cross_repo_manifest.py`
- `tools/contracts/build_deployment_impact_report.py`
- `tools/contracts/build_release_obligations.py`
- `tools/contracts/contract_runtime.py`
- `tools/contracts/verify_cross_repo_contracts.py`

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
- `require_runbook_update`
- `require_status_update`
- `reviewer_bundle`
- `runbook_reference`
- `security_review_note`
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
- `enterprise-services` -> verdict `manual_review_required`; reviewers: architecture, platform, release, tenancy_auth
- `mfe` -> verdict `manual_review_required`; reviewers: architecture, platform, release
- `observability-runtime` -> verdict `infra_counterpart_required`; reviewers: platform, release
- `openedx` -> verdict `manual_review_required`; reviewers: architecture, platform, release
- `purchase-gateway` -> verdict `infra_counterpart_required`; reviewers: architecture, platform, release, security
- `runner-ci` -> verdict `infra_counterpart_required`; reviewers: platform, release, security

## Out Of Scope
- live-cluster reconciliation
- direct edits to bbi-infrastructure from this repo
- repo-local wording-only cleanup

## Escalation Conditions
- mixed task overlaps with normative_spec_change
- mixed task overlaps with release_or_runtime_change
