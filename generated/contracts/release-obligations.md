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
- Touched paths: `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`
- Active obligation classes: `deployment_affecting_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`
- Unknowns: service-specific overlay decomposition for enterprise-catalog, enterprise-access, and related services is not declared in this repo
- Notes: Enterprise service rollout remains coupled to shared Open edX deployment surfaces unless explicitly split in GitOps

### openedx
- Verdict: `manual_review_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`, staging -> `apps/mereka-lms/overlays/staging/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `.github/workflows/ci.yml`
- Active obligation classes: `image_or_artifact_change`
- Required evidence: `release_obligations`, `reviewer_bundle`
- Runbooks to review: `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md`, `docs/reference/operations/OPENEDX_HOSTNAMES.md`
- Unknowns: exact ArgoCD application or ApplicationSet filenames are not declared in this repo, exact secret store resource paths are not declared in this repo
- Notes: deploy/k8s/overlays/rke2-nonprod in this repo is deprecated in favor of bbi-infrastructure dev overlays, deploy/k8s/overlays/production in this repo is deprecated in favor of bbi-infrastructure prod overlays

### purchase-gateway
- Verdict: `infra_counterpart_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: dev -> `apps/mereka-lms/overlays/dev/`, prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `apps/mereka-lms/`
- Touched paths: `docs/ops/runbooks/PURCHASE_GATEWAY_K8S.md`
- Active obligation classes: `deployment_affecting_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/PURCHASE_GATEWAY_K8S.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md`
- Unknowns: Stripe secret materialization path is not declared in this repo, exact purchase-gateway ingress and service object files are not declared in this repo
- Notes: production rollout requires GitOps overlay image pinning and ingress realization

### runner-ci
- Verdict: `infra_counterpart_required`
- Deployment repo: `bbi-infrastructure`
- Overlay roots: prod -> `apps/mereka-lms/overlays/prod/`
- Argo/GitOps surfaces: `none`
- Touched paths: `.github/workflows/ci.yml`, `docs/ops/runbooks/CI_CD_RUNBOOK.md`
- Active obligation classes: `deployment_affecting_change`, `image_or_artifact_change`
- Required evidence: `release_obligations`, `reviewer_bundle`, `truth_impact_report`
- Runbooks to review: `docs/ops/runbooks/CI_CD_RUNBOOK.md`, `docs/reference/operations/CI_CD_SETUP.md`
- Unknowns: exact self-hosted runner host configuration and secret provisioning files are not declared in this repo
- Notes: runner and release automation are cross-repo because release scripts write into bbi-infrastructure

## Required infra follow-up

- `enterprise-services` -> `manual_review_required` in `bbi-infrastructure`
- `openedx` -> `manual_review_required` in `bbi-infrastructure`
- `purchase-gateway` -> `infra_counterpart_required` in `bbi-infrastructure`
- `runner-ci` -> `infra_counterpart_required` in `bbi-infrastructure`

## Required evidence and runbook updates

- Evidence artifacts: `release_obligations`, `reviewer_bundle`, `truth_impact_report`
- Runbook surfaces: `docs/ops/runbooks/CI_CD_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`, `docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md`, `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md`, `docs/ops/runbooks/PURCHASE_GATEWAY_K8S.md`, `docs/reference/operations/CI_CD_SETUP.md`, `docs/reference/operations/OPENEDX_HOSTNAMES.md`

## Required release and promotion notes

- Services requiring release-note treatment: `enterprise-services`, `openedx`, `purchase-gateway`, `runner-ci`

## Reviewer checklist

- Confirm whether a counterpart `bbi-infrastructure` PR exists for every `infra_counterpart_required` service.
- Check all `manual_review_required` services for missing exact GitOps file paths before merge.
- Verify runbook and evidence surfaces moved with each deployment-affecting change.
- Treat secret-surface changes as blocked until security and platform review are present.

## Ignored surfaces

- `config/admin-merge-exception-ledger.yaml`, `config/branch-protection-contract.yaml`, `config/structural-debt-register.yaml`, `docs/CONTRIBUTING.md`, `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`, `docs/README.md`, `docs/_generated/bundles/60-docs-specs-contract.md`, `docs/adr/templates/README.md`, `docs/architecture/CONTENT_LIBRARIES_MODEL.md`, `docs/architecture/README.md`, `docs/architecture/assessment-audit-report.md`, `docs/architecture/codejail-status.md`, `docs/architecture/mobile-apps-overview.md`, `docs/architecture/purchase-gateway-overview.md`, `docs/architecture/video-pipeline-overview.md`, `docs/catalog.json`, `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`, `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`, `docs/concepts/architecture/README.md`, `docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md`, `docs/evidence/INDEX.md`, `docs/evidence/operations/README.md`, `docs/guides/INDEX_BY_AUDIENCE.md`, `docs/guides/README.md`, `docs/guides/admin/CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md`, `docs/guides/admin/ENTERPRISE_SERVICES_GUIDE.md`, `docs/guides/admin/OBSERVABILITY_GUIDE.md`, `docs/guides/admin/README.md`, `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`, `docs/guides/branding/TENANT_CONFIG_HANDOFF.md`, `docs/guides/onboarding/DEVCONTAINER_GUIDE.md`, `docs/guides/onboarding/README.md`, `docs/guides/onboarding/REPOSITORY_GUIDE.md`, `docs/guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md`, `docs/guides/platform/CONTENT_LIBRARIES_AUTHORING_GUIDE.md`, `docs/guides/platform/COURSE_AUTHORING_QUICKSTART.md`, `docs/guides/platform/PLATFORM_START_HERE.md`, `docs/guides/standards/DOCS_SPECS_CONTRACT.md`, `docs/guides/standards/DOCUMENTATION_STANDARDS.md`, `docs/guides/standards/EVIDENCE_PACK_STANDARD.md`, `docs/guides/standards/README.md`, `docs/guides/standards/STATUS_REPORTING_STANDARD.md`, `docs/guides/standards/STYLE_GUIDE.md`, `docs/meta/README.md`, `docs/meta/adr-process/adr-review.md`, `docs/meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`, `docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`, `docs/meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md`, `docs/meta/docs-program/WAVE9_CLOSEOUT.md`, `docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md`, `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md`, `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md`, `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md`, `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md`, `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md`, `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md`, `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md`, `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md`, `docs/meta/docs-program/companion-surface-review.v1.yaml`, `docs/meta/docs-program/metadata/METADATA_MODEL.md`, `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`, `docs/meta/docs-program/metadata/frontmatter-schema.json`, `docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md`, `docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md`, `docs/meta/docs-program/owner-gap-ledger.v1.yaml`, `docs/meta/docs-program/root-collapse/README.md`, `docs/meta/knowledge/AGENT_REVIEW_HANDOFF.md`, `docs/meta/knowledge/WAVE10_CLOSEOUT.md`, `docs/meta/skills/SKILL_RUNTIME_MODEL.yaml`, `docs/meta/skills/SKILL_TAXONOMY.yaml`, `docs/meta/skills/TASK_TYPE_TAXONOMY.yaml`, `docs/policies/README.md`, `docs/policies/architecture/SELECTOR_HARDENING_POLICY.md`, `docs/policies/operations/BRANCH_PROTECTION.md`, `docs/policies/operations/CI_RUNNER_POLICY.md`, `docs/policies/operations/SLO_POLICY.md`, `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`, `docs/reference/README.md`, `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`, `docs/reference/architecture/MFE_SELECTOR_AUDIT.md`, `docs/reference/architecture/README.md`, `docs/reference/governance/DEPRECATION_LEDGER.md`, `docs/reference/migrations/README.md`, `docs/reference/migrations/drive-airtable/REVIEW_QUEUE.md`, `docs/reference/migrations/mct/PROGRAMS_SETUP_PLAN.md`, `docs/reference/migrations/mct/README.md`, `docs/stabilization/AGENT_OPERATING_MODEL.md`, `docs/stabilization/CI_FALSE_RED_PREVENTION.md`, `docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md`, `docs/stabilization/EXECUTION_INVARIANTS.md`, `docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`, `docs/status/INDEX.md`, `docs/status/active/DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md`, `docs/status/active/PRODUCTION_READINESS_AUDIT_2026-04-04.md`, `docs/status/migrations/2026-03-wave-2b-final-closeout.md`, `docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md`, `generated/agent/command-registry.json`, `generated/agent/cross-repo-manifest.json`, `generated/agent/read-first.md`, `generated/agent/release-obligations-pack.json`, `generated/agent/topology-pack.json`, `generated/catalogs/docs-catalog.json`, `generated/catalogs/knowledge-catalog.json`, `generated/graphs/knowledge-graph.json`, `generated/knowledge/agent-entrypoints.json`, `generated/knowledge/agent-task-bundles/cross-repo-contract-change.md`, `generated/knowledge/agent-task-bundles/docs-architecture-change.md`, `generated/knowledge/agent-task-bundles/evidence-status-update.md`, `generated/knowledge/agent-task-bundles/incident-debug.md`, `generated/knowledge/agent-task-bundles/migration-change.md`, `generated/knowledge/agent-task-bundles/normative-spec-change.md`, `generated/knowledge/agent-task-bundles/proposal-change.md`, `generated/knowledge/agent-task-bundles/release-change.md`, `generated/knowledge/agent-task-bundles/reviewer-pass.md`, `generated/knowledge/agent-task-bundles/wrapper-retirement.md`, `generated/knowledge/change-manifest.json`, `generated/knowledge/review-bundle.md`, `generated/knowledge/task-bundles/architecture_or_adr_change.json`, `generated/knowledge/task-bundles/architecture_or_adr_change.md`, `generated/knowledge/task-bundles/compatibility_or_wrapper_cleanup.json`, `generated/knowledge/task-bundles/compatibility_or_wrapper_cleanup.md`, `generated/knowledge/task-bundles/cross_repo_contract_change.json`, `generated/knowledge/task-bundles/cross_repo_contract_change.md`, `generated/knowledge/task-bundles/evidence_or_status_change.json`, `generated/knowledge/task-bundles/evidence_or_status_change.md`, `generated/knowledge/task-bundles/generated_surface_refresh.json`, `generated/knowledge/task-bundles/generated_surface_refresh.md`, `generated/knowledge/task-bundles/normative_spec_change.json`, `generated/knowledge/task-bundles/normative_spec_change.md`, `generated/knowledge/task-bundles/proposal_or_rfc_change.json`, `generated/knowledge/task-bundles/proposal_or_rfc_change.md`, `generated/knowledge/task-bundles/release_or_runtime_change.json`, `generated/knowledge/task-bundles/release_or_runtime_change.md`, `generated/knowledge/task-bundles/reviewer_handoff_or_policy_change.json`, `generated/knowledge/task-bundles/reviewer_handoff_or_policy_change.md`, `generated/knowledge/task-bundles/runbook_or_ops_change.json`, `generated/knowledge/task-bundles/runbook_or_ops_change.md`, `generated/knowledge/task-context-report.json`, `generated/knowledge/truth-impact-report.json`, `generated/knowledge/wave10-source-map.json`, `generated/skills/read-first.json`, `generated/skills/read-first.md`, `generated/skills/runtime-convergence-report.json`, `generated/skills/scenario-packs.json`, `generated/skills/skill-dependency-graph.json`, `generated/skills/skill-registry.json`, `infrastructure/monitoring/grafana/dashboards/public-endpoints.json`, `scripts/qa/lint-repo-conventions.sh`, `scripts/qa/run-agent-readiness-gates.sh`, `scripts/qa/verify-admin-merge-exceptions.sh`, `scripts/qa/verify-branch-protection.sh`, `scripts/qa/verify-manifest-integrity.sh`, `scripts/qa/verify-mfe-selectors.sh`, `scripts/qa/verify-selector-hardening.sh`, `scripts/qa/verify-slot-migration-readiness.sh`, `tools/docs/verify/run-docs-world-class-gates.sh`, `tools/docs/verify/verify-docs-policy.sh`, `tools/docs/verify/verify_companion_surfaces.py`, `tools/docs/verify/verify_concepts_architecture_clean.py`, `tools/docs/verify/verify_legacy_architecture_root.py`, `tools/docs/verify/verify_maintained_doc_hygiene.py`, `tools/docs/verify/verify_owner_gap_ledger.py`, `tools/knowledge/build_agent_readiness_report.py`, `tools/knowledge/build_agent_task_bundles.py`, `tools/knowledge/build_cross_repo_agent_packs.py`, `tools/knowledge/build_task_bundle.py`, `tools/knowledge/build_wave10_source_map.py`, `tools/knowledge/change_runtime.py`, `tools/knowledge/skill_runtime.py`, `tools/knowledge/verify_agent_consumption_runtime.py`, `tools/skills/build_skill_dependency_graph.py`, `tools/skills/verify_agent_pack_runtime.py`, `tools/skills/verify_skill_runtime.py`, `tools/specs/build_spec_bundles.py`, `verification/catalogs/VERIFICATION_CATALOG.md`, `verification/catalogs/verification_catalog.json`
