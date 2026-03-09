# Task Bundle: architecture_or_adr_change

- Intent: Change architecture decisions, rationale, or decision-ledger truth.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/truth-impact-report.json`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`

## Affected Truth Surfaces
- `docs/adr/011-convention-based-spec-verification.md`
- `docs/adr/013-studio-sso-bypass-middleware.md`
- `docs/adr/015-mobile-push-notification-provider.md`
- `docs/adr/016-android-app-support-decision.md`
- `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- `docs/adr/022-session-cookie-samesite-policy.md`
- `docs/adr/028-platform-sources-of-truth-and-control-planes.md`
- `docs/adr/029-identity-session-and-domain-boundary-strategy.md`
- `docs/adr/030-feature-flag-and-rollout-lifecycle.md`
- `docs/adr/031-deprecation-and-removal-policy.md`
- `docs/adr/032-data-governance-pii-retention-and-deletion.md`
- `docs/adr/033-tenant-lifecycle-contract.md`
- `docs/adr/manifest.yaml`
- `docs/adr/rfc/034-event-contract-and-transport-independence.md`
- `docs/adr/rfc/035-frontend-runtime-composition-and-dependency-alignment.md`
- `docs/adr/rfc/036-cache-topology-and-invalidation-strategy.md`
- `docs/adr/rfc/037-async-task-user-facing-contract.md`
- `docs/adr/rfc/038-commerce-system-of-record-and-reconciliation.md`
- `docs/adr/rfc/039-translations-and-internationalization-strategy.md`
- `docs/adr/rfc/040-internal-packages-plugins-and-versioning-policy.md`
- `docs/adr/rfc/041-authorization-and-role-boundary-model.md`
- `docs/catalog.json`
- `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- `docs/concepts/architecture/AUTHORIZATION_MODEL.md`
- `docs/concepts/architecture/CONTROL_PLANES.md`
- `docs/concepts/architecture/DATA_GOVERNANCE.md`
- `docs/concepts/architecture/README.md`
- `docs/concepts/architecture/TENANT_LIFECYCLE.md`
- `docs/concepts/architecture/TUTOR_AND_EXTENSION_MODEL.md`
- `docs/concepts/architecture/notification-pipeline-overview.md`
- `docs/concepts/architecture/proctoring-architecture-overview.md`
- `docs/reference/architecture/API_CONTRACTS.md`
- `docs/reference/architecture/MOBILE_TOKEN_PARITY.md`
- `generated/catalogs/knowledge-catalog.json`

## Required Reviewers
- `architecture`
- `docs`

## Required Evidence
- `require_adr_update`
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
- `purchase-gateway` -> verdict `infra_counterpart_required`; reviewers: architecture, platform, release, security

## Out Of Scope
- mass runbook rewrites
- runtime-only fixes without decision changes
- generated artifact refresh without source-policy change

## Escalation Conditions
- mixed task overlaps with cross_repo_contract_change
- mixed task overlaps with release_or_runtime_change
- human review required if architecture and runtime truth move together
