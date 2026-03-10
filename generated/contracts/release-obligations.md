# Wave 6 Release Obligations

- Range: `origin/main...HEAD`
- Overall cross-repo verdict: `infra_counterpart_required`
- Required counterpart repos: bbi-infrastructure
- Required reviewers: architecture, platform, release, security, tenancy_auth

## Service obligations

### enterprise-services
- Verdict: `manual_review_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `specs/enterprise-microservices_spec.md`, `specs/secrets-management_spec.md`
- Active obligation classes: `image_or_artifact_change`, `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`
- Unknowns: service-specific overlay decomposition for enterprise-catalog, enterprise-access, and related services is not declared in this repo
- Notes: Enterprise service rollout remains coupled to shared Open edX deployment surfaces unless explicitly split in GitOps

### mfe
- Verdict: `manual_review_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`, staging -> `apps/mereka-lms/overlays/staging/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `specs/secrets-management_spec.md`
- Active obligation classes: `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/MFE_PLUGIN_SLOTS_RUNBOOK.md`, `docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`, `docs/runbooks/architecture/ENTERPRISE_MFE_MAINTENANCE.md`
- Unknowns: exact ingress object, edge route, or CDN-related files are not declared in this repo
- Notes: MFE image pin and ingress host updates are expected to land in GitOps overlays, not in app-repo production overlays

### observability-runtime
- Verdict: `infra_counterpart_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `apps/mereka-lms/`, `platform monitoring applications`
- Touched paths: `specs/observability-stack_spec.md`, `specs/secrets-management_spec.md`
- Active obligation classes: `image_or_artifact_change`, `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/OBSERVABILITY_QUICKSTART.md`, `docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md`, `docs/ops/runbooks/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`
- Unknowns: exact monitoring and alerting application paths in bbi-infrastructure are not declared in this repo
- Notes: observability is a mixed ownership surface: app repo owns contracts and runbooks, infra repo owns realization

### openedx
- Verdict: `manual_review_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`, staging -> `apps/mereka-lms/overlays/staging/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `.github/workflows/ci.yml`, `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`, `specs/k8s-deployment_spec.md`, `specs/secrets-management_spec.md`
- Active obligation classes: `deployment_affecting_change`, `image_or_artifact_change`, `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md`, `docs/reference/operations/OPENEDX_HOSTNAMES.md`
- Unknowns: exact ArgoCD application or ApplicationSet filenames are not declared in this repo, exact secret store resource paths are not declared in this repo
- Notes: deploy/k8s/overlays/rke2-nonprod in this repo is deprecated in favor of bbi-infrastructure dev overlays, deploy/k8s/overlays/production in this repo is deprecated in favor of bbi-infrastructure prod overlays

### purchase-gateway
- Verdict: `infra_counterpart_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`, `specs/ecommerce-purchase-gateway_spec.md`, `specs/secrets-management_spec.md`
- Active obligation classes: `deployment_affecting_change`, `image_or_artifact_change`, `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/PURCHASE_GATEWAY_K8S.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md`
- Unknowns: Stripe secret materialization path is not declared in this repo, exact purchase-gateway ingress and service object files are not declared in this repo
- Notes: production rollout requires GitOps overlay image pinning and ingress realization

### runner-ci
- Verdict: `infra_counterpart_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `none`
- Touched paths: `.github/workflows/ci.yml`, `specs/secrets-management_spec.md`
- Active obligation classes: `image_or_artifact_change`, `secret_surface_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/CI_CD_RUNBOOK.md`, `docs/reference/operations/CI_CD_SETUP.md`
- Unknowns: exact self-hosted runner host configuration and secret provisioning files are not declared in this repo
- Notes: runner and release automation are cross-repo because release scripts write into bbi-infrastructure

## Required infra follow-up

- `enterprise-services` -> `manual_review_required` in `bbi-infrastructure`
- `mfe` -> `manual_review_required` in `bbi-infrastructure`
- `observability-runtime` -> `infra_counterpart_required` in `bbi-infrastructure`
- `openedx` -> `manual_review_required` in `bbi-infrastructure`
- `purchase-gateway` -> `infra_counterpart_required` in `bbi-infrastructure`
- `runner-ci` -> `infra_counterpart_required` in `bbi-infrastructure`

## Required evidence and runbook updates

- Evidence artifacts: `release_obligations`, `reviewer_bundle`, `security_review_note`, `truth_impact_report`
- Runbook surfaces: `docs/ops/runbooks/CI_CD_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`, `docs/ops/runbooks/MFE_PLUGIN_SLOTS_RUNBOOK.md`, `docs/ops/runbooks/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`, `docs/ops/runbooks/OBSERVABILITY_QUICKSTART.md`, `docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md`, `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_K8S.md`, `docs/reference/operations/CI_CD_SETUP.md`, `docs/reference/operations/OPENEDX_HOSTNAMES.md`, `docs/runbooks/architecture/ENTERPRISE_MFE_MAINTENANCE.md`, `docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`

## Required release and promotion notes

- Services requiring release-note treatment: `enterprise-services`, `mfe`, `observability-runtime`, `openedx`, `purchase-gateway`, `runner-ci`

## Reviewer checklist

- Confirm whether a counterpart `bbi-infrastructure` PR exists for every `infra_counterpart_required` service.
- Check all `manual_review_required` services for missing exact GitOps file paths before merge.
- Verify runbook and evidence surfaces moved with each deployment-affecting change.
- Treat secret-surface changes as blocked until security and platform review are present.

## Ignored surfaces

- `Makefile`, `docs/README.md`, `docs/_generated/bundles/60-docs-specs-contract.md`, `docs/adr/011-convention-based-spec-verification.md`, `docs/adr/013-studio-sso-bypass-middleware.md`, `docs/adr/015-mobile-push-notification-provider.md`, `docs/adr/016-android-app-support-decision.md`, `docs/adr/022-session-cookie-samesite-policy.md`, `docs/adr/028-platform-sources-of-truth-and-control-planes.md`, `docs/adr/029-identity-session-and-domain-boundary-strategy.md`, `docs/adr/030-feature-flag-and-rollout-lifecycle.md`, `docs/adr/031-deprecation-and-removal-policy.md`, `docs/adr/032-data-governance-pii-retention-and-deletion.md`, `docs/adr/033-tenant-lifecycle-contract.md`, `docs/adr/manifest.yaml`, `docs/adr/rfc/034-event-contract-and-transport-independence.md`, `docs/adr/rfc/035-frontend-runtime-composition-and-dependency-alignment.md`, `docs/adr/rfc/036-cache-topology-and-invalidation-strategy.md`, `docs/adr/rfc/037-async-task-user-facing-contract.md`, `docs/adr/rfc/038-commerce-system-of-record-and-reconciliation.md`, `docs/adr/rfc/039-translations-and-internationalization-strategy.md`, `docs/adr/rfc/040-internal-packages-plugins-and-versioning-policy.md`, `docs/adr/rfc/041-authorization-and-role-boundary-model.md`, `docs/archive/FRONTEND_PHASE_B_PROMPT.md`, `docs/archive/FRONTEND_PHASE_C_PROMPT.md`, `docs/archive/FRONTEND_PHASE_D_PROMPT.md`, `docs/archive/evidence/operations/evidence/spec-dedupe-normalize-report.md`, `docs/archive/superseded/ROADMAP.md`, `docs/archive/superseded/runbooks/external-registration-runbook.md`, `docs/archive/superseded/runbooks/proctoring-operations-runbook.md`, `docs/catalog.json`, `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`, `docs/concepts/architecture/AUTHORIZATION_MODEL.md`, `docs/concepts/architecture/CONTROL_PLANES.md`, `docs/concepts/architecture/DATA_GOVERNANCE.md`, `docs/concepts/architecture/README.md`, `docs/concepts/architecture/TENANT_LIFECYCLE.md`, `docs/concepts/architecture/TUTOR_AND_EXTENSION_MODEL.md`, `docs/concepts/architecture/notification-pipeline-overview.md`, `docs/concepts/architecture/proctoring-architecture-overview.md`, `docs/guides/README.md`, `docs/guides/admin/DOCS_CMDREF_BACKLOG_20260313.md`, `docs/guides/branding/BRANDING_PLAN.md`, `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`, `docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md`, `docs/guides/onboarding/REPOSITORY_GUIDE.md`, `docs/guides/onboarding/TEAM_SCALING_GUIDE.md`, `docs/guides/platform/COURSE_AUTHORING_QUICKSTART.md`, `docs/guides/platform/MULTI_TENANCY_EXPLAINED.md`, `docs/guides/platform/OPENEDX_FOR_TEAM_MEMBERS.md`, `docs/guides/platform/OPENEDX_SETTINGS_MATRIX.md`, `docs/guides/platform/PLATFORM_START_HERE.md`, `docs/guides/platform/SOURCE_MAP.md`, `docs/guides/platform/SUPPORT_AND_ESCALATION.md`, `docs/guides/standards/ADR_LANGUAGE_STYLE.md`, `docs/guides/standards/ADR_NUMBERING_AND_NAMING.md`, `docs/guides/standards/DOCS_SPECS_CONTRACT.md`, `docs/guides/standards/DOCUMENTATION_STANDARDS.md`, `docs/guides/standards/EVIDENCE_PACK_STANDARD.md`, `docs/guides/standards/README.md`, `docs/guides/standards/STATUS_REPORTING_STANDARD.md`, `docs/guides/standards/STYLE_GUIDE.md`, `docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md`, `docs/meta/docs-program/README.md`, `docs/meta/docs-program/SPEC_COVERAGE.md`, `docs/meta/docs-program/WAVE3_CLOSEOUT.md`, `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`, `docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE4_CHARTER.md`, `docs/meta/docs-program/WAVE4_CLOSEOUT.md`, `docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md`, `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`, `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`, `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`, `docs/meta/docs-program/metadata/METADATA_MODEL.md`, `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`, `docs/meta/docs-program/metadata/frontmatter-schema.json`, `docs/meta/docs-program/metadata/governs-taxonomy.yaml`, `docs/meta/knowledge/CHANGE_CLASSES.yaml`, `docs/meta/knowledge/DECISION_RUNTIME_MODEL.md`, `docs/meta/knowledge/EVIDENCE_OBLIGATIONS.yaml`, `docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md`, `docs/meta/knowledge/OWNERSHIP_MAP.yaml`, `docs/meta/knowledge/RECEIPT_CLASSES.yaml`, `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md`, `docs/meta/knowledge/REVIEW_RULES.yaml`, `docs/meta/knowledge/WAVE10_CLOSEOUT.md`, `docs/meta/knowledge/WAVE10_EXECUTION_TRACKER.md`, `docs/meta/knowledge/WAVE10_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE10_SOURCE_OF_TRUTH_MAP.md`, `docs/meta/knowledge/WAVE12_CLOSEOUT.md`, `docs/meta/knowledge/WAVE12_EXECUTION_TRACKER.md`, `docs/meta/knowledge/WAVE12_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE13_CLOSEOUT.md`, `docs/meta/knowledge/WAVE13_EXECUTION_TRACKER.md`, `docs/meta/knowledge/WAVE13_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE14_CLOSEOUT.md`, `docs/meta/knowledge/WAVE14_EXECUTION_TRACKER.md`, `docs/meta/knowledge/WAVE14_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE5_EXECUTION_TRACKER.md`, `docs/meta/knowledge/schemas/approval-receipt.schema.json`, `docs/meta/knowledge/schemas/evidence-obligations.schema.json`, `docs/meta/knowledge/schemas/evidence-receipt.schema.json`, `docs/meta/knowledge/schemas/execution-receipt.schema.json`, `docs/meta/knowledge/schemas/proof-bundle-manifest.schema.json`, `docs/meta/knowledge/schemas/read-first-packs.schema.json`, `docs/meta/knowledge/schemas/release-decision-receipt.schema.json`, `docs/meta/knowledge/schemas/release-readiness.schema.json`, `docs/meta/knowledge/schemas/review-decision.schema.json`, `docs/meta/knowledge/schemas/reviewer-obligations.schema.json`, `docs/meta/knowledge/schemas/runtime-evaluation.schema.json`, `docs/meta/knowledge/schemas/runtime-proof-receipt.schema.json`, `docs/meta/skills/AGENT_PACK_ABI.yaml`, `docs/meta/skills/REPO_DISCOVERY_MODEL.yaml`, `docs/meta/skills/SKILL_RUNTIME_MODEL.yaml`, `docs/meta/skills/SKILL_TAXONOMY.yaml`, `docs/meta/skills/WAVE11_CLOSEOUT.md`, `docs/meta/skills/WAVE11_EXECUTION_TRACKER.md`, `docs/meta/skills/WAVE11_REVIEW_HANDOFF.md`, `docs/meta/skills/schemas/command-registry.schema.json`, `docs/meta/skills/schemas/evidence-sufficiency-map.schema.json`, `docs/meta/skills/schemas/mixed-diff-arbitration.schema.json`, `docs/meta/skills/schemas/pack-registry.schema.json`, `docs/meta/skills/schemas/read-first.schema.json`, `docs/meta/skills/schemas/runtime-convergence-report.schema.json`, `docs/meta/skills/schemas/scenario-packs.schema.json`, `docs/meta/skills/schemas/skill-dependency-graph.schema.json`, `docs/meta/skills/schemas/skill-registry.schema.json`, `docs/reference/architecture/API_CONTRACTS.md`, `docs/reference/architecture/MOBILE_TOKEN_PARITY.md`, `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md`, `fixtures/decision-runtime/scenarios.json`, `generated/adr-bundles/00-foundations.md`, `generated/adr-bundles/10-auth-and-tenancy.md`, `generated/adr-bundles/50-commerce.md`, `generated/agent/command-registry.json`, `generated/agent/cross-repo-manifest.json`, `generated/agent/read-first.md`, `generated/agent/release-obligations-pack.json`, `generated/agent/reviewer-map.json`, `generated/agent/topology-pack.json`, `generated/catalogs/docs-catalog.json`, `generated/catalogs/knowledge-catalog.json`, `generated/graphs/knowledge-graph.json`, `generated/knowledge/approval-receipt.json`, `generated/knowledge/change-manifest.json`, `generated/knowledge/evidence-obligations.json`, `generated/knowledge/evidence-receipt.json`, `generated/knowledge/execution-receipt.json`, `generated/knowledge/proof-bundle-manifest.json`, `generated/knowledge/read-first-packs.json`, `generated/knowledge/release-decision-receipt.json`, `generated/knowledge/release-readiness.json`, `generated/knowledge/release-readiness.md`, `generated/knowledge/review-bundle.md`, `generated/knowledge/review-decision.json`, `generated/knowledge/review-decision.md`, `generated/knowledge/reviewer-obligations.json`, `generated/knowledge/runtime-evaluation.json`, `generated/knowledge/runtime-proof-receipt.json`, `generated/knowledge/truth-impact-report.json`, `generated/knowledge/wave10-source-map.json`, `generated/knowledge/wrapper-retirement-report.json`, `generated/platform/domain-access-reference.json`, `generated/platform/team-topology-reference.json`, `generated/skills/command-registry.json`, `generated/skills/evidence-sufficiency-map.json`, `generated/skills/mixed-diff-arbitration.json`, `generated/skills/pack-registry.json`, `generated/skills/read-first.json`, `generated/skills/read-first.md`, `generated/skills/runtime-convergence-report.json`, `generated/skills/scenario-packs.json`, `generated/skills/skill-dependency-graph.json`, `generated/skills/skill-registry.json`, `infrastructure/tutor/themes/mereka/README.md`, `infrastructure/tutor/themes/mereka/tenants/_template/README.md`, `scripts/branding/sync-tokens-to-json.sh`, `scripts/mobile/validate-mobile-secrets.sh`, `scripts/qa/run-agent-pack-runtime-gates.sh`, `scripts/qa/run-cross-repo-agent-gates.sh`, `scripts/qa/run-decision-runtime-gates.sh`, `scripts/qa/run-execution-proof-runtime-gates.sh`, `scripts/qa/run-knowledge-integrity-gates.sh`, `scripts/qa/run-knowledge-runtime-gates.sh`, `scripts/qa/run-skill-runtime-gates.sh`, `scripts/qa/run-spec-integrity-gates.sh`, `scripts/qa/run-team-handbook-gates.sh`, `scripts/qa/scan-hubspot-credentials.sh`, `scripts/qa/spec-tools/build_spec_catalog.py`, `scripts/qa/spec-tools/extract_manual_entries.py`, `scripts/qa/spec-tools/mereka_spec_verify.py`, `scripts/qa/spec-tools/render_index.py`, `scripts/qa/spec-tools/spec_coverage_report.py`, `scripts/qa/spec-tools/spec_lint.py`, `scripts/qa/spec-tools/spec_verify.py`, `scripts/qa/verify-brand-pack-schema.sh`, `scripts/qa/verify-hubspot-alerts.sh`, `scripts/qa/verify-hubspot-k8s-security.sh`, `scripts/qa/verify-hubspot-registration.sh`, `scripts/qa/verify-hubspot-secrets.sh`, `scripts/qa/verify-mfe-css-architecture.sh`, `scripts/qa/verify-mobile-deployment.sh`, `scripts/qa/verify-mobile-secrets-inventory.sh`, `scripts/qa/verify-mobile-secrets-runtime.sh`, `scripts/qa/verify-mobile-token-parity.sh`, `scripts/qa/verify-paragon-json-token-hierarchy.sh`, `scripts/qa/verify-paragon-runtime.sh`, `scripts/qa/verify-paragon-theme-urls.sh`, `scripts/qa/verify-paragon-token-coverage.sh`, `scripts/qa/verify-paragon-tokens.sh`, `scripts/qa/verify-proctoring-advanced.sh`, `scripts/qa/verify-proctoring-environment.sh`, `scripts/qa/verify-proctoring-integration.sh`, `scripts/qa/verify-proctoring.sh`, `scripts/qa/verify-spec-coverage.sh`, `scripts/qa/verify-theming-generated-artifacts.sh`, `scripts/qa/verify_adr_governs_vocabulary.py`, `scripts/qa/verify_adr_suite.sh`, `scripts/tenants/validate-tenant-brand-pack.sh`, `specdocs.config.yml`, `specdocs/CERTIFICATION_SCORECARD.yml`, `specdocs/agents/SYSTEM.md`, `specdocs/agents/WORKFLOW.md`, `specdocs/agents/prompts/00_router.md`, `specdocs/agents/prompts/10_generate_spec.md`, `specdocs/agents/prompts/50_spec_to_tests.md`, `specdocs/templates/README.md`, `tools/docs/build_domain_access_reference.py`, `tools/docs/build_team_topology_reference.py`, `tools/docs/verify/report-hotpath-doc-metadata.py`, `tools/docs/verify/verify-legacy-testmaps-frozen-test.sh`, `tools/docs/verify/verify-legacy-testmaps-frozen.py`, `tools/docs/verify/verify_team_handbook.py`, `tools/knowledge/build_approval_receipt.py`, `tools/knowledge/build_change_manifest.py`, `tools/knowledge/build_cross_repo_agent_packs.py`, `tools/knowledge/build_evidence_obligations.py`, `tools/knowledge/build_evidence_receipt.py`, `tools/knowledge/build_execution_receipt.py`, `tools/knowledge/build_knowledge_catalog.py`, `tools/knowledge/build_knowledge_graph.py`, `tools/knowledge/build_read_first_packs.py`, `tools/knowledge/build_release_decision_receipt.py`, `tools/knowledge/build_release_readiness.py`, `tools/knowledge/build_review_bundle.py`, `tools/knowledge/build_review_decision.py`, `tools/knowledge/build_reviewer_obligations.py`, `tools/knowledge/build_runtime_evaluation.py`, `tools/knowledge/build_runtime_proof_receipt.py`, `tools/knowledge/build_truth_impact_report.py`, `tools/knowledge/build_wave10_source_map.py`, `tools/knowledge/build_wrapper_retirement_ledger.py`, `tools/knowledge/build_wrapper_retirement_report.py`, `tools/knowledge/change_runtime.py`, `tools/knowledge/knowledge_model.py`, `tools/knowledge/report_knowledge_control_plane.py`, `tools/knowledge/verify_decision_runtime.py`, `tools/knowledge/verify_execution_proof_runtime.py`, `tools/knowledge/verify_knowledge_runtime.py`, `tools/skills/build_command_registry.py`, `tools/skills/build_pack_registry.py`, `tools/skills/build_runtime_convergence_report.py`, `tools/skills/build_scenario_packs.py`, `tools/skills/build_skill_abi_maps.py`, `tools/skills/build_skill_dependency_graph.py`, `tools/skills/build_skill_registry.py`, `tools/skills/repo_discovery.py`, `tools/skills/verify_agent_pack_runtime.py`, `tools/skills/verify_agent_pack_schemas.py`, `tools/skills/verify_skill_runtime.py`, `tools/specs/build_spec_bundles.py`, `tools/specs/build_spec_graph.py`, `tools/specs/report_spec_metadata_coverage.py`, `tools/specs/spec_tooling.py`, `tools/specs/verify_docs_specs_boundary.py`, `tools/specs/verify_docs_specs_boundary_test.sh`, `tools/specs/verify_spec_frontmatter.py`, `tools/specs/verify_spec_paths.py`, `tools/specs/verify_spec_taxonomy.py`, `verification/catalogs/QA_SCRIPT_CATALOG.yml`
