# Docs Command-Reference Backlog (Full Non-Archive Sweep)

_Generated: 2026-03-13 · Source: /tmp/cmdref-full-summary.json_

## Context

- Files scanned: 644
- Path-reference candidates: 6213
- Missing references: 436
- Scope: `docs/**/*.md` excluding `docs/archive/**` (non-archive docs only).

## Executive summary

- Severity is by concentration: files with the most missing references first.
- Use one-file-per-PR repair pattern to keep reviewers scoped and make review reversible.
- Keep scope to this file list to avoid duplicate triage before merge gates.

## Ownership buckets (quick dispatch)

- Operations Lead: 46 refs
- Platform Architecture: 27 refs
- Unassigned (determine domain owner): 22 refs
- Docs Lead: 13 refs
- Ops Platform Owner: 10 refs
- ADR / Architecture Owner: 6 refs
- Docs QA: 3 refs

## Priority queue by file (top 120 concentrated misses)

| File | Missing refs | Owner | Suggested next action |
|---|---:|---|---|
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 34 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 28 | Ops Platform Owner | fix inline path references and missing commands |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 19 | Ops Platform Owner | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 15 | Platform Architecture | fix inline path references and missing commands |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 13 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 11 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 9 | Platform Architecture | fix inline path references and missing commands |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 8 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/mct/OPS_MCT_README.md | 8 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 7 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 7 | Platform Architecture | fix inline path references and missing commands |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 7 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 7 | Docs Lead | fix inline path references and missing commands |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 7 | Operations Lead | fix inline path references and missing commands |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 7 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 6 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/mct/MIGRATION_PLAN.md | 6 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 6 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 6 | Operations Lead | fix inline path references and missing commands |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 5 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 5 | Platform Architecture | fix inline path references and missing commands |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 5 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 5 | Docs Lead | fix inline path references and missing commands |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 5 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 5 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 5 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 5 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 5 | Operations Lead | fix inline path references and missing commands |
| docs/ops/runbooks/scaling.md | 5 | Ops Platform Owner | fix inline path references and missing commands |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 5 | Docs QA | fix inline path references and missing commands |
| docs/policies/architecture/ANALYTICS_DECISION_GATE.md | 4 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md | 4 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/branding/TENANT_BRANDING_CONTRACT.md | 4 | Docs Lead | fix inline path references and missing commands |
| docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md | 4 | Operations Lead | fix inline path references and missing commands |
| docs/status/readiness/CREDENTIALS_READINESS.md | 4 | Operations Lead | fix inline path references and missing commands |
| docs/adr/016-android-app-support-decision.md | 3 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/concepts/analytics/ASPECTS_ACCESS.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/concepts/analytics/ASPECTS_QUICKSTART.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/policies/architecture/COPY_TERMINOLOGY_CONTRACT.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md | 3 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/branding/TENANT_CONFIG_HANDOFF.md | 3 | Docs Lead | fix inline path references and missing commands |
| docs/status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md | 3 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/operations/ASPECTS_WIRING_CHECKLIST.md | 3 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/AUTHENTICATED_SMOKE_A11Y.md | 3 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md | 3 | Operations Lead | fix inline path references and missing commands |
| reports/2026/closures/POSTMERGE_GOVERNANCE_CLOSURE.md | 3 | Operations Lead | fix inline path references and missing commands |
| docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md | 3 | Operations Lead | fix inline path references and missing commands |
| docs/ops/quickref/verification-scripts.md | 3 | Ops Platform Owner | fix inline path references and missing commands |
| docs/ops/runbooks/database-issues.md | 3 | Ops Platform Owner | fix inline path references and missing commands |
| docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md | 2 | Docs Lead | fix inline path references and missing commands |
| docs/adr/006-tutor-plugin-based-configuration.md | 2 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/concepts/analytics/ASPECTS_INSTALLATION.md | 2 | Platform Architecture | fix inline path references and missing commands |
| docs/concepts/analytics/PANORAMA_ANALYTICS.md | 2 | Platform Architecture | fix inline path references and missing commands |
| docs/policies/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md | 2 | Platform Architecture | fix inline path references and missing commands |
| reports/2026/closures/ASSESSMENT_EPIC_CLOSURE.md | 2 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md | 2 | Platform Architecture | fix inline path references and missing commands |
| docs/concepts/architecture/PROCTORING_INTEGRATION.md | 2 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/admin/MULTI_SITE_GUIDE.md | 2 | Docs Lead | fix inline path references and missing commands |
| docs/guides/admin/OBSERVABILITY_GUIDE.md | 2 | Docs Lead | fix inline path references and missing commands |
| docs/guides/standards/DOCUMENTATION_STANDARDS.md | 2 | Docs Lead | fix inline path references and missing commands |
| docs/runbooks/migrations/kajabi/EXECUTION_PLAN_VERIFICATION.md | 2 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/migrations/kajabi/KAJABI_REMIGRATION_RUNBOOK.md | 2 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/migrations/kajabi/VERIFY_AND_SYNC_KAJABI.md | 2 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/meta/docs-program/DEPLOY_TENANCY_EPIC.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/ECOMMERCE_THEMING.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/FORUM_AUTH_E2E.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/FORUM_MEILISEARCH.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/GDPR_COMPLIANCE.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md | 2 | Operations Lead | fix inline path references and missing commands |
| docs/status/active/blocked-epics.md | 2 | Operations Lead | fix inline path references and missing commands |
| verification/assurance/ASSURANCE_CASE.md | 2 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/adr/007-forum-migration-ruby-to-python.md | 1 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/adr/009-in-cluster-storage.md | 1 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/adr/010-monorepo-architecture.md | 1 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/adr/017-analytics-target-decision.md | 1 | ADR / Architecture Owner | fix inline path references and missing commands |
| docs/concepts/analytics/ENROLLMENT_COMPARISON_QUICKSTART.md | 1 | Platform Architecture | fix inline path references and missing commands |
| docs/reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md | 1 | Platform Architecture | fix inline path references and missing commands |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md | 1 | Platform Architecture | fix inline path references and missing commands |
| docs/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md | 1 | Platform Architecture | fix inline path references and missing commands |
| docs/guides/INDEX_BY_AUDIENCE.md | 1 | Docs Lead | fix inline path references and missing commands |
| docs/guides/admin/ENTERPRISE_SERVICES_GUIDE.md | 1 | Docs Lead | fix inline path references and missing commands |
| docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md | 1 | Docs Lead | fix inline path references and missing commands |
| docs/guides/onboarding/LOCAL_SETUP.md | 1 | Docs Lead | fix inline path references and missing commands |
| docs/guides/onboarding/TEAM_SCALING_GUIDE.md | 1 | Docs Lead | fix inline path references and missing commands |
| docs/migrations/kajabi/KAJABI_CERTIFICATE_MIGRATION.md | 1 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_ISSUE.md | 1 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/migrations/kajabi/VERIFY_WHEN_SITE_BACK_UP.md | 1 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/mct/EXPORT_COMPLETE.md | 1 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/migrations/mct/EXPORT_SUMMARY.md | 1 | Unassigned (determine domain owner) | fix inline path references and missing commands |
| docs/runbooks/operations/A11Y_TENANT_BRANDING_GATE.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md | 1 | Operations Lead | fix inline path references and missing commands |
| reports/2026/audits/CONFIG_REVIEW_2026-02-03.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/policies/operations/DATA_RETENTION_POLICY.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/DOMAIN_MANAGEMENT.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/ECOMMERCE_OAUTH_TROUBLESHOOTING.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/FOOTER_VARIANT_MATRIX.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md | 1 | Operations Lead | fix inline path references and missing commands |
| reports/2026/closures/LOGO-404-EMERGENCY-FIX.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/MOBILE_OAUTH_PROVISIONING.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/MONGODB_DEV_SEED.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/policies/operations/MULTISITE_GOVERNANCE.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/policies/operations/OBSERVABILITY_GA_READINESS_GATE.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/status/readiness/PROCTORING_VENDOR_READINESS.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/RELEASE_EVIDENCE.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/ROUTE_MATRIX.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/policies/operations/SLO_POLICY.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/TENANT_BRANDING_MATRIX.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/TENANT_BRANDING_TROUBLESHOOTING.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/runbooks/operations/TENANT_FOOTER_VARIANT_LANE.md | 1 | Operations Lead | fix inline path references and missing commands |
| reports/2026/audits/UI_UX_AUDIT_REPORT.md | 1 | Operations Lead | fix inline path references and missing commands |
| docs/reference/operations/CI_CD_SETUP.md | 1 | Ops Platform Owner | fix inline path references and missing commands |

## Complete backlog

| File | Line | Missing Reference |
|---|---:|---|
| docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md | 314 | docs/archive/evidence/YYYY-Qx/ |
| docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md | 436 | docs/archive/reports/docs-program-scorecard-YYYYMMDD.md |
| docs/adr/006-tutor-plugin-based-configuration.md | 150 | infrastructure/tutor/plugins/_mereka_lms/ |
| docs/adr/006-tutor-plugin-based-configuration.md | 153 | .github/workflows/tutor-plugin-test.yml |
| docs/adr/007-forum-migration-ruby-to-python.md | 82 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/adr/009-in-cluster-storage.md | 85 | scripts/infra/fix-velero-restore-test.sh |
| docs/adr/010-monorepo-architecture.md | 142 | services/ |
| docs/adr/016-android-app-support-decision.md | 118 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| docs/adr/016-android-app-support-decision.md | 14 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| docs/adr/016-android-app-support-decision.md | 95 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| docs/adr/017-analytics-target-decision.md | 104 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/ASPECTS_ACCESS.md | 146 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/ASPECTS_ACCESS.md | 147 | docs/ASPECTS_INSTALLATION.md |
| docs/concepts/analytics/ASPECTS_ACCESS.md | 148 | docs/ASPECTS_VS_PANORAMA.md |
| docs/concepts/analytics/ASPECTS_INSTALLATION.md | 167 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/ASPECTS_INSTALLATION.md | 168 | docs/concepts/analytics/OPENEDX_ANALYTICS.md |
| docs/concepts/analytics/ASPECTS_QUICKSTART.md | 79 | docs/ASPECTS_ACCESS.md |
| docs/concepts/analytics/ASPECTS_QUICKSTART.md | 80 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/ASPECTS_QUICKSTART.md | 81 | docs/ASPECTS_INSTALLATION.md |
| docs/concepts/analytics/ENROLLMENT_COMPARISON_QUICKSTART.md | 36 | scripts/migrations/kajabi/output/comparison/summary.txt |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 11 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 122 | docs/PANORAMA_ANALYTICS.md |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 12 | docs/PANORAMA_ANALYTICS.md |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 471 | docs/MONITORING.md |
| docs/concepts/analytics/OPENEDX_ANALYTICS.md | 80 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/PANORAMA_ANALYTICS.md | 198 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/concepts/analytics/PANORAMA_ANALYTICS.md | 232 | docs/concepts/analytics/ASPECTS_ANALYTICS.md |
| docs/policies/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md | 229 | scripts/qa/verify-keyboard-navigation.sh |
| docs/policies/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md | 349 | scripts/qa/verify-accessibility.sh |
| docs/policies/architecture/ANALYTICS_DECISION_GATE.md | 105 | docs/product/FEATURE_REQUESTS.md |
| docs/policies/architecture/ANALYTICS_DECISION_GATE.md | 110 | docs/product/FEATURE_REQUESTS.md |
| docs/policies/architecture/ANALYTICS_DECISION_GATE.md | 84 | docs/operations/INCIDENT_LOG.md |
| docs/policies/architecture/ANALYTICS_DECISION_GATE.md | 91 | docs/operations/INCIDENT_LOG.md |
| docs/reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md | 263 | deploy/k8s/base/plugins/aspects/prometheusrule.yml |
| reports/2026/closures/ASSESSMENT_EPIC_CLOSURE.md | 104 | docs/ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md |
| reports/2026/closures/ASSESSMENT_EPIC_CLOSURE.md | 68 | docs/ops/runbooks/XQUEUE_HEALTH_RUNBOOK.md |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 274 | infrastructure/tutor/patches/build-opt-dockerfile.sh |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 275 | infrastructure/tutor/patches/build-opt-settings.sh |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 276 | infrastructure/tutor/patches/build-opt-routing.sh |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 277 | infrastructure/tutor/patches/build-opt-theme-sync.sh |
| docs/meta/docs-program/openedx-repo-audit/BUILD_OPTIMIZATIONS_REFACTOR.md | 280 | scripts/qa/verify-patch-modularity.sh |
| docs/policies/architecture/COPY_TERMINOLOGY_CONTRACT.md | 142 | docs/concepts/architecture/MFE_FOOTER_V2_DESIGN.md |
| docs/policies/architecture/COPY_TERMINOLOGY_CONTRACT.md | 262 | docs/concepts/architecture/MFE_FOOTER_V2_DESIGN.md |
| docs/policies/architecture/COPY_TERMINOLOGY_CONTRACT.md | 263 | docs/concepts/architecture/TENANT_BRANDING_CONTRACT.md |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 140 | deploy/k8s/base/apps/lms/deployment.yaml |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 141 | deploy/k8s/base/services.yml |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 49 | deploy/k8s/base/apps/lms/deployment.yaml |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 69 | deploy/k8s/base/apps/lms/deployment.yaml |
| reports/2025/closures/MONGODB_ATLAS_MIGRATION.md | 70 | deploy/k8s/base/services.yml |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md | 236 | docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md | 404 | infrastructure/k8s/README.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md | 575 | docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md | 167 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md | 168 | scripts/qa/verify-theme-artifacts-determinism.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md | 170 | scripts/qa/verify-tenant-registry-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md | 170 | scripts/tenants/validate-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md | 43 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md | 52 | scripts/qa/verify-theme-artifacts-determinism.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md | 66 | scripts/tenants/validate-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 140 | docs/policies/operations/REPO_BOUNDARIES.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 193 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 195 | assets/branding/brand-packages.manifest.yml |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 205 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 241 | docs/guides/branding/THEMING_ARTIFACT_POLICY.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 246 | scripts/qa/verify-theme-artifacts-determinism.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 294 | scripts/qa/verify-manifest.yml |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 301 | scripts/qa/run-lane-auth.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 302 | scripts/qa/run-lane-branding.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 303 | scripts/qa/run-lane-ops.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 354 | scripts/tenants/apply-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 369 | scripts/tenants/apply-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 465 | scripts/qa/verify-submodule-path-contract.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 52 | docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md | 79 | docs/operations/EVIDENCE_STORAGE_POLICY.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md | 131 | docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md | 13 | docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md | 87 | docs/policies/operations/REPO_BOUNDARIES.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 100 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 101 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 36 | assets/branding/brand-packages.manifest.yml |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 38 | scripts/branding/sync-brand-packages.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 68 | scripts/branding/sync-brand-packages.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 79 | scripts/qa/verify-brand-packages-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md | 83 | docs/guides/branding/BRAND_ASSET_SYNC_CONTRACT.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md | 39 | docs/guides/branding/THEMING_ARTIFACT_POLICY.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md | 41 | scripts/qa/verify-theme-artifacts-determinism.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md | 76 | scripts/qa/verify-theme-artifacts-determinism.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 32 | scripts/qa/verify-manifest.yml |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 36 | docs/operations/VERIFY_SUITE_OPERATING_MODEL.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 67 | scripts/qa/run-lane-infra.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 68 | scripts/qa/run-lane-branding.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 69 | scripts/qa/run-lane-auth.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 70 | scripts/qa/run-lane-observability.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md | 85 | scripts/qa/run-lane-infra.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 109 | scripts/qa/verify-tenant-registry-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 134 | scripts/qa/verify-tenant-registry-drift.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 39 | scripts/tenants/validate-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 41 | docs/operations/TENANT_REGISTRY_CONTRACT.md |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 63 | scripts/tenants/validate-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 74 | scripts/tenants/apply-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 76 | scripts/tenants/render-tenant-configmap.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 98 | scripts/tenants/apply-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md | 99 | scripts/tenants/apply-tenant-registry.sh |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md | 105 | services/purchase-gateway/app/workers/reconciliation.py |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md | 70 | services/purchase-gateway/app/workers/fulfillment_worker.py |
| docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md | 74 | services/purchase-gateway/k8s/deployment-worker.yaml |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 109 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 110 | deploy/k8s/base/services.yml |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 112 | deploy/k8s/base/plugins/ecommerce/ |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 160 | deploy/k8s/base/plugins/ecommerce/ |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 160 | docs/archive/oscar-ecommerce-settings/ |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 65 | services/purchase-gateway/app/middleware/migration.py |
| docs/policies/architecture/OSCAR_DEPRECATION.md | 99 | scripts/infra/decommission-legacy-ecommerce.sh |
| docs/concepts/architecture/PROCTORING_INTEGRATION.md | 197 | docs/ops/runbooks/PROCTORING_RUNBOOK.md |
| docs/concepts/architecture/PROCTORING_INTEGRATION.md | 217 | docs/ops/runbooks/PROCTORING_RUNBOOK.md |
| docs/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md | 483 | deploy/k8s/base/plugins/aspects/backup-cronjob.yml |
| docs/guides/INDEX_BY_AUDIENCE.md | 389 | scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh |
| docs/guides/admin/ENTERPRISE_SERVICES_GUIDE.md | 547 | docs/runbooks/operations/ENTERPRISE_SERVICES_RUNBOOK.md |
| docs/guides/admin/MULTI_SITE_GUIDE.md | 175 | deploy/k8s/overlays/production/ingress-openedx-lms.yaml |
| docs/guides/admin/MULTI_SITE_GUIDE.md | 446 | deploy/k8s/overlays/production/ingress-openedx-lms.yaml |
| docs/guides/admin/OBSERVABILITY_GUIDE.md | 136 | deploy/k8s/base/monitoring/prometheusrule-services.yaml |
| docs/guides/admin/OBSERVABILITY_GUIDE.md | 485 | infrastructure/monitoring/ |
| docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md | 302 | infrastructure/tutor/plugins/multi-tenancy/middleware.py |
| docs/guides/branding/TENANT_BRANDING_CONTRACT.md | 326 | docs/reference/domain-ssl-management.md |
| docs/guides/branding/TENANT_BRANDING_CONTRACT.md | 403 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png |
| docs/guides/branding/TENANT_BRANDING_CONTRACT.md | 49 | infrastructure/tutor/plugins/mereka_lms.py |
| docs/guides/branding/TENANT_BRANDING_CONTRACT.md | 705 | docs/reference/domain-ssl-management.md |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 344 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 449 | infrastructure/tutor/themes/mereka/tenants/acme-corp/branding.json |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 567 | infrastructure/tutor/themes/mereka/tenants/new-tenant/branding.json |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 570 | infrastructure/tutor/themes/mereka/tenants/new-tenant/branding.json |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 620 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 623 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png |
| docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md | 626 | infrastructure/tutor/themes/mereka/tenants/acme-corp/branding.json |
| docs/guides/branding/TENANT_CONFIG_HANDOFF.md | 145 | deploy/k8s/base/apps/tenant-registry-configmap.yaml |
| docs/guides/branding/TENANT_CONFIG_HANDOFF.md | 157 | deploy/k8s/base/apps/tenant-registry-configmap.yaml |
| docs/guides/branding/TENANT_CONFIG_HANDOFF.md | 21 | assets/branding/logo-mereka.svg |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 136 | docs/LOCAL_DEVELOPMENT_GUIDE.md |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 137 | docs/AGENT_SETUP_CHECKLIST.md |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 138 | docs/OPERATIONAL_STATUS.md |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 163 | docs/LOCAL_DEVELOPMENT_GUIDE.md |
| docs/guides/onboarding/DEVELOPER_ONBOARDING.md | 169 | docs/OPERATIONAL_STATUS.md |
| docs/guides/onboarding/LOCAL_SETUP.md | 120 | scripts/migrations/kajabi/output/ |
| docs/guides/onboarding/TEAM_SCALING_GUIDE.md | 584 | specs/templates/spec-template.md |
| docs/guides/standards/DOCUMENTATION_STANDARDS.md | 501 | docs/archive/superseded/ |
| docs/guides/standards/DOCUMENTATION_STANDARDS.md | 842 | docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 127 | infrastructure/tutor/plugins/multi-tenancy/tenants/skillourfuture-brand.json |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 211 | infrastructure/tutor/plugins/multi-tenancy/tenants/skillourfuture-brand.json |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 265 | infrastructure/tutor/themes/mereka/common/static/images/sof/ |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 277 | reports/2026/audits/CONFIG_REVIEW_2026-02-03.md |
| docs/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md | 66 | infrastructure/tutor/themes/mereka/common/static/images/sof/ |
| docs/runbooks/migrations/kajabi/EXECUTION_PLAN_VERIFICATION.md | 139 | scripts/migrations/kajabi/output/verification/import_missing_enrollments.sh |
| docs/runbooks/migrations/kajabi/EXECUTION_PLAN_VERIFICATION.md | 82 | scripts/migrations/kajabi/openedx_bulk_import.py |
| docs/migrations/kajabi/KAJABI_CERTIFICATE_MIGRATION.md | 172 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 13 | scripts/migrations/kajabi/transform_data.py |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 17 | scripts/migrations/kajabi/build_course_packages.py |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 54 | scripts/migrations/kajabi/transform_data.py |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 65 | scripts/migrations/kajabi/build_course_packages.py |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md | 66 | scripts/migrations/kajabi/output/course_structure.json |
| docs/migrations/kajabi/KAJABI_LESSON_CONTENT_ISSUE.md | 93 | scripts/migrations/kajabi/build_course_packages.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 17 | scripts/migrations/kajabi/transform_data.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 32 | scripts/migrations/kajabi/build_course_packages.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 33 | scripts/migrations/kajabi/output/course_structure.json |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 44 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 70 | scripts/migrations/kajabi/import_courses.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 74 | scripts/migrations/kajabi/run_batches.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 77 | scripts/migrations/kajabi/run_batches.py |
| docs/migrations/kajabi/KAJABI_MIGRATION.md | 82 | scripts/migrations/kajabi/logs/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 102 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 117 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 132 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 145 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 14 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 156 | scripts/migrations/kajabi/logs/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 15 | scripts/migrations/kajabi/logs/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 15 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 166 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 16 | services/kajabi-webhook/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 182 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 193 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 203 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 314 | docs/migrations/kajabi/KAJABI_MIGRATION.md |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 315 | services/kajabi-webhook/README.md |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 320 | scripts/migrations/kajabi/transform_data.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 321 | scripts/migrations/kajabi/build_course_packages.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 322 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 323 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 324 | scripts/migrations/kajabi/openedx_bulk_import.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 325 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 328 | scripts/migrations/kajabi/logs/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 333 | scripts/migrations/kajabi/output/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 334 | services/kajabi-webhook/outbox/ |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 382 | scripts/migrations/kajabi/transform_data.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 384 | scripts/migrations/kajabi/build_course_packages.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 385 | scripts/migrations/kajabi/output/course_structure.json |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 389 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 394 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 399 | scripts/migrations/kajabi/run_batches.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 404 | scripts/migrations/kajabi/import_courses.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 86 | scripts/migrations/kajabi/transform_data.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 92 | scripts/migrations/kajabi/build_course_packages.py |
| reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md | 93 | scripts/migrations/kajabi/output/course_structure.json |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 126 | scripts/migrations/kajabi/output/ |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 153 | scripts/migrations/kajabi/openedx_bulk_import.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 154 | scripts/migrations/kajabi/run_batches.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 161 | scripts/migrations/kajabi/run_batches.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 175 | scripts/migrations/kajabi/run_batches.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 188 | scripts/migrations/kajabi/import_courses.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 194 | scripts/migrations/kajabi/import_courses.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 235 | services/kajabi-webhook/ |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 257 | scripts/migrations/kajabi/scrape_lessons.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 260 | scripts/migrations/kajabi/requirements.txt |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 265 | scripts/migrations/kajabi/scrape_lessons.py |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 266 | scripts/migrations/kajabi/output/course_structure.json |
| docs/migrations/kajabi/KAJABI_MIGRATION_NOTES.md | 278 | scripts/migrations/kajabi/transform_data.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 128 | scripts/migrations/kajabi/output/ |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 129 | scripts/migrations/kajabi/output/course_packages/ |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 139 | scripts/migrations/kajabi/transform_data.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 140 | scripts/migrations/kajabi/build_course_packages.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 141 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 142 | scripts/migrations/kajabi/run_batches.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 143 | scripts/migrations/kajabi/openedx_bulk_import.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 144 | scripts/migrations/kajabi/import_courses.py |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 150 | services/kajabi-webhook/ |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 51 | scripts/migrations/kajabi/output/ |
| docs/status/migrations/KAJABI_MIGRATION_STATUS.md | 88 | services/kajabi-webhook/ |
| docs/runbooks/migrations/kajabi/KAJABI_REMIGRATION_RUNBOOK.md | 175 | scripts/migrations/kajabi/output/course_structure.json |
| docs/runbooks/migrations/kajabi/KAJABI_REMIGRATION_RUNBOOK.md | 299 | scripts/migrations/kajabi/logs/ |
| docs/status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md | 197 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md | 73 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md | 80 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 128 | scripts/migrations/kajabi/import_courses.py |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 29 | scripts/migrations/kajabi/transform_data.py |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 52 | scripts/migrations/kajabi/build_course_packages.py |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 53 | scripts/migrations/kajabi/output/course_structure.json |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 74 | scripts/migrations/kajabi/prepare_openedx_imports.py |
| docs/reference/migrations/kajabi/OPS_KAJABI_README.md | 79 | scripts/migrations/kajabi/output/openedx/ |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 103 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 128 | scripts/migrations/kajabi/create-rollback-csv.py |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 133 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 219 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md | 96 | scripts/migrations/kajabi/rollback-openedx-imports.py |
| docs/runbooks/migrations/kajabi/VERIFY_AND_SYNC_KAJABI.md | 118 | scripts/migrations/kajabi/output/verification/summary.txt |
| docs/runbooks/migrations/kajabi/VERIFY_AND_SYNC_KAJABI.md | 133 | scripts/migrations/kajabi/output/verification/import_missing_enrollments.sh |
| docs/runbooks/migrations/kajabi/VERIFY_WHEN_SITE_BACK_UP.md | 86 | scripts/migrations/kajabi/output/verification_current/summary.txt |
| docs/migrations/mct/EXPORT_COMPLETE.md | 215 | scripts/migrations/mct/transform_data.py |
| docs/migrations/mct/EXPORT_SUMMARY.md | 128 | scripts/migrations/mct/transform_data.py |
| docs/migrations/mct/MIGRATION_PLAN.md | 197 | scripts/migrations/mct/transform_data.py |
| docs/migrations/mct/MIGRATION_PLAN.md | 220 | scripts/migrations/mct/output/ |
| docs/migrations/mct/MIGRATION_PLAN.md | 234 | scripts/migrations/mct/build_course_packages.py |
| docs/migrations/mct/MIGRATION_PLAN.md | 264 | scripts/migrations/mct/import_courses_k8s.py |
| docs/migrations/mct/MIGRATION_PLAN.md | 375 | scripts/migrations/mct/transform_data.py |
| docs/migrations/mct/MIGRATION_PLAN.md | 396 | scripts/migrations/kajabi/ |
| docs/migrations/mct/OPS_MCT_README.md | 100 | scripts/migrations/mct/openedx_bulk_import_mct.py |
| docs/migrations/mct/OPS_MCT_README.md | 121 | scripts/migrations/mct/run_user_import_k8s.sh |
| docs/migrations/mct/OPS_MCT_README.md | 122 | scripts/migrations/mct/test_user_import.sh |
| docs/migrations/mct/OPS_MCT_README.md | 45 | scripts/migrations/mct/transform_data.py |
| docs/migrations/mct/OPS_MCT_README.md | 55 | scripts/migrations/mct/build_course_packages.py |
| docs/migrations/mct/OPS_MCT_README.md | 70 | scripts/migrations/mct/prepare_openedx_imports.py |
| docs/migrations/mct/OPS_MCT_README.md | 77 | docs/migrations/mct/MIGRATION_PLAN.md |
| docs/migrations/mct/OPS_MCT_README.md | 84 | scripts/migrations/mct/openedx_bulk_import_mct.py |
| docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md | 111 | docs/policies/operations/A11Y_EXCEPTIONS.md |
| docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md | 134 | docs/policies/operations/A11Y_EXCEPTIONS.md |
| docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md | 174 | docs/policies/operations/A11Y_EXCEPTIONS.md |
| docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md | 175 | scripts/qa/verify-accessibility.sh |
| docs/runbooks/operations/A11Y_TENANT_BRANDING_GATE.md | 256 | docs/policies/operations/A11Y_EXCEPTIONS.md |
| docs/runbooks/operations/ALTERNATIVE_DOMAIN_BRANDING_FIX.md | 179 | assets/branding/tenants/biji-biji/ |
| docs/runbooks/operations/ASPECTS_WIRING_CHECKLIST.md | 225 | deploy/k8s/overlays/rke2-nonprod/ingress-aspects-superset.yaml |
| docs/runbooks/operations/ASPECTS_WIRING_CHECKLIST.md | 256 | deploy/k8s/overlays/rke2-nonprod/ingress-aspects-superset.yaml |
| docs/runbooks/operations/ASPECTS_WIRING_CHECKLIST.md | 464 | deploy/k8s/overlays/production/ingress-aspects-superset.yaml |
| docs/runbooks/operations/AUTHENTICATED_SMOKE_A11Y.md | 127 | docs/archive/evidence/operations/authenticated-smoke-a11y-report.md |
| docs/runbooks/operations/AUTHENTICATED_SMOKE_A11Y.md | 135 | docs/archive/evidence/operations/authenticated-smoke-a11y-report.md |
| docs/runbooks/operations/AUTHENTICATED_SMOKE_A11Y.md | 142 | docs/archive/evidence/operations/authenticated-smoke-a11y-report.md |
| reports/2026/audits/CONFIG_REVIEW_2026-02-03.md | 115 | deploy/k8s/patches/argocd-configmap-ignore.yaml |
| docs/status/readiness/CREDENTIALS_READINESS.md | 312 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/status/readiness/CREDENTIALS_READINESS.md | 313 | deploy/k8s/base/services.yml |
| docs/status/readiness/CREDENTIALS_READINESS.md | 34 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/status/readiness/CREDENTIALS_READINESS.md | 35 | deploy/k8s/base/services.yml |
| docs/policies/operations/DATA_RETENTION_POLICY.md | 246 | docs/policies/operations/DATA_RETENTION_POLICY.md |
| docs/meta/docs-program/DEPLOY_TENANCY_EPIC.md | 349 | docs/concepts/architecture/MULTI_TENANCY.md |
| docs/meta/docs-program/DEPLOY_TENANCY_EPIC.md | 350 | scripts/tenants/PROVISIONING.md |
| docs/runbooks/operations/DOMAIN_MANAGEMENT.md | 22 | docs/runbooks/operations/DOMAIN_MANAGEMENT.md |
| docs/runbooks/operations/ECOMMERCE_OAUTH_TROUBLESHOOTING.md | 100 | deploy/k8s/base/apps/purchase-gateway/deployment.yaml |
| docs/reference/operations/ECOMMERCE_THEMING.md | 26 | infrastructure/tutor/branding/design-tokens.yml |
| docs/reference/operations/ECOMMERCE_THEMING.md | 354 | infrastructure/tutor/branding/ |
| docs/runbooks/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md | 137 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/runbooks/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md | 150 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/runbooks/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md | 233 | scripts/infra/decommission-legacy-ecommerce.sh |
| docs/reference/operations/FOOTER_VARIANT_MATRIX.md | 164 | docs/runbooks/operations/DOMAIN_MANAGEMENT.md |
| docs/runbooks/operations/FORUM_AUTH_E2E.md | 131 | scripts/infra/sync-secrets.sh |
| docs/runbooks/operations/FORUM_AUTH_E2E.md | 187 | scripts/qa/verify-forum-integration.sh |
| docs/reference/operations/FORUM_MEILISEARCH.md | 32 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/reference/operations/FORUM_MEILISEARCH.md | 33 | deploy/k8s/base/services.yml |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 11 | .github/workflows/frontend-contracts.yml |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 11 | scripts/qa/verify-frontend-contracts-workflow.sh |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 12 | .github/workflows/frontend-extended-surfaces.yml |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 12 | scripts/qa/verify-frontend-extended-surfaces-workflow.sh |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 36 | scripts/qa/verify-make-help-contract.sh |
| docs/status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md | 37 | scripts/qa/verify-frontend-qa-make-targets.sh |
| docs/runbooks/operations/GDPR_COMPLIANCE.md | 421 | infrastructure/monitoring/ |
| docs/runbooks/operations/GDPR_COMPLIANCE.md | 60 | infrastructure/tutor/mfe/ |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 179 | deploy/k8s/base/secrets/hubspot-registration-secrets.yaml |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 257 | deploy/k8s/base/monitoring/prometheusrule-hubspot.yaml |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 331 | deploy/k8s/base/monitoring/servicemonitor-hubspot.yaml |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 466 | deploy/k8s/base/monitoring/prometheusrule-mux.yaml |
| docs/runbooks/operations/HUBSPOT_MUX_DEPLOYMENT_GUIDE.md | 88 | deploy/k8s/base/apps/hubspot-registration/ |
| docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md | 35 | deploy/k8s/base/apps/ecommerce/ |
| docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md | 56 | docs/archive/legacy-ecommerce/ |
| docs/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md | 132 | docs/archive/evidence/operations/footer-migration-diff.md |
| reports/2026/closures/LOGO-404-EMERGENCY-FIX.md | 157 | deploy/k8s/base/apps/lms/deployment.yaml |
| docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md | 183 | docs/adr/014-mfe-plugin-slot-first.md |
| docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md | 312 | docs/adr/014-mfe-plugin-slot-first.md |
| docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md | 100 | docs/archive/evidence/operations/selector-to-slot-migration-diff.md |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 202 | deploy/k8s/base/secrets/external-secrets-mobile.yaml |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 380 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 381 | docs/IOS_DEPLOYMENT_LEARNINGS.md |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 382 | docs/IOS_APP_CI_SETUP.md |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 383 | docs/adr/016-android-deferral.md |
| docs/runbooks/operations/MOBILE_DEPLOYMENT.md | 6 | docs/adr/016-android-deferral.md |
| docs/runbooks/operations/MOBILE_OAUTH_PROVISIONING.md | 275 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| docs/runbooks/operations/MONGODB_DEV_SEED.md | 140 | scripts/tenants/acme-branding.json |
| docs/policies/operations/MULTISITE_GOVERNANCE.md | 81 | reports/2026/audits/CONFIG_REVIEW_2026-02-03.md |
| docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md | 279 | infrastructure/tutor/plugins/multi-tenancy/tenants/skillourfuture-brand.json |
| docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md | 332 | reports/2026/audits/CONFIG_REVIEW_2026-02-03.md |
| docs/policies/operations/OBSERVABILITY_GA_READINESS_GATE.md | 85 | docs/archive/evidence/operations/observability-drills/ |
| docs/runbooks/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md | 9 | .github/workflows/observability-parity-runtime.yml |
| docs/runbooks/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md | 191 | docs/archive/evidence/operations/observability-drills/ |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 171 | scripts/qa/verify-tutor-patches-inventory.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 184 | scripts/qa/verify-tutor-patches-inventory.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 261 | scripts/qa/verify-postmerge-governance-closure.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 26 | scripts/qa/verify-tutor-patches-inventory.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 273 | scripts/qa/verify-postmerge-governance-closure.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 38 | scripts/qa/verify-tutor-patches-inventory.sh |
| docs/status/active/PLUGIN_SPLIT_STATUS_2026-03-02.md | 46 | scripts/qa/verify-tutor-patches-inventory.sh |
| reports/2026/closures/POSTMERGE_GOVERNANCE_CLOSURE.md | 309 | scripts/qa/verify-postmerge-governance-closure.sh |
| reports/2026/closures/POSTMERGE_GOVERNANCE_CLOSURE.md | 358 | scripts/qa/verify-postmerge-governance-closure.sh |
| reports/2026/closures/POSTMERGE_GOVERNANCE_CLOSURE.md | 6 | scripts/qa/verify-postmerge-governance-closure.sh |
| docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md | 152 | infrastructure/tutor/plugins/multi-tenancy/mereka_tenancy/models.py |
| docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md | 212 | infrastructure/tutor/plugins/multi-tenancy/mereka_tenancy/models.py |
| docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md | 213 | infrastructure/tutor/plugins/multi-tenancy/mereka_tenancy/migrations/ |
| docs/status/readiness/PROCTORING_VENDOR_READINESS.md | 74 | docs/status/readiness/PROCTORING_IMPLEMENTATION_READINESS.md |
| docs/reference/operations/RELEASE_EVIDENCE.md | 86 | scripts/infra/assemble-release-evidence.sh |
| docs/reference/operations/ROUTE_MATRIX.md | 161 | infrastructure/tutor/plugins/mereka_lms.py |
| docs/policies/operations/SLO_POLICY.md | 152 | deploy/k8s/base/monitoring/README.md |
| docs/reference/operations/TENANT_BRANDING_MATRIX.md | 88 | docs/runbooks/operations/DOMAIN_MANAGEMENT.md |
| docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md | 37 | infrastructure/tutor/plugins/multi-tenancy/middleware.py |
| docs/runbooks/operations/TENANT_BRANDING_TROUBLESHOOTING.md | 351 | scripts/branding/sync-brand-assets.sh |
| docs/runbooks/operations/TENANT_FOOTER_VARIANT_LANE.md | 279 | docs/runbooks/operations/DOMAIN_MANAGEMENT.md |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 173 | infrastructure/tutor/themes/mereka/tenants/acme-corp/branding.json |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 206 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 212 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo-square.png |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 215 | infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo-white.png |
| docs/runbooks/operations/TENANT_PROVISIONING.md | 581 | scripts/branding/sync-brand-assets.sh |
| reports/2026/audits/UI_UX_AUDIT_REPORT.md | 332 | scripts/branding/sync-brand-assets.sh |
| docs/status/active/blocked-epics.md | 70 | docs/archive/evidence/operations/1bdm1-mux-creds-mapping-cleanup.md |
| docs/status/active/blocked-epics.md | 95 | docs/archive/evidence/operations/1bdm1-mux-creds-mapping-cleanup.md |
| docs/reference/operations/CI_CD_SETUP.md | 152 | .github/workflows/docs-policy.yml |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 33 | .github/workflows/docs-policy.yml |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 70 | scripts/qa/verify-a11y-tenant-branding-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 71 | scripts/qa/verify-accessibility-audit-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 72 | scripts/qa/verify-certificate-branding-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 73 | scripts/qa/verify-cicd-tutor-config-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 74 | scripts/qa/verify-cross-browser-branding-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 75 | scripts/qa/verify-email-template-branding-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 76 | scripts/qa/verify-frontend-before-after-visuals-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 77 | scripts/qa/verify-frontend-branding-closure-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 78 | scripts/qa/verify-frontend-performance-spotcheck-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 79 | scripts/qa/verify-frontend-runtime-qa-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 80 | scripts/qa/verify-mfe-live-dom-audit-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 81 | scripts/qa/verify-mfe-selector-hardening-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 82 | scripts/qa/verify-npm-start-smoke-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 83 | scripts/qa/verify-paragon-runtime-contract-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 84 | scripts/qa/verify-paragon-theme-budget-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 85 | scripts/qa/verify-phase2-smoke-evidence-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 86 | scripts/qa/verify-release-evidence-workflow.sh |
| docs/ops/ci-cd/CI_CEREMONY_REDUCTION_MATRIX_104.md | 87 | scripts/qa/verify-runtime-theme-drift-diagnose-workflow.sh |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 131 | .github/workflows/verify-specs.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 133 | .github/workflows/tutor-config-verify.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 148 | .github/workflows/alert-routing-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 149 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 160 | .github/workflows/observability-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 162 | .github/workflows/observability-parity-runtime.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 173 | .github/workflows/tutor-config-verify.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 176 | .github/workflows/verify-patch-idempotency.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 177 | .github/workflows/verify-specs.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 185 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 202 | .github/workflows/alert-routing-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 207 | .github/workflows/observability-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 208 | .github/workflows/observability-parity-runtime.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 218 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 222 | .github/workflows/tutor-config-verify.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 225 | .github/workflows/verify-patch-idempotency.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 226 | .github/workflows/verify-specs.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 238 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 255 | .github/workflows/verify-specs.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 370 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 393 | .github/workflows/observability-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 394 | .github/workflows/alert-routing-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 395 | .github/workflows/observability-parity-runtime.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 488 | .github/workflows/verify-specs.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 489 | .github/workflows/authenticated-sso-canary.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 490 | .github/workflows/observability-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 491 | .github/workflows/alert-routing-audit.yml |
| docs/status/active/CI_OPTIMIZATION_TRACKER.md | 492 | .github/workflows/observability-parity-runtime.yml |
| reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md | 282 | .github/actions/gcp-gke-auth/action.yml |
| docs/ops/ci-cd/TUTOR_CONFIG_CI.md | 9 | .github/workflows/tutor-config-verify.yml |
| docs/ops/quickref/verification-scripts.md | 310 | scripts/qa/verify-lms-health.sh |
| docs/ops/quickref/verification-scripts.md | 311 | scripts/qa/verify-cms-health.sh |
| docs/ops/quickref/verification-scripts.md | 312 | scripts/qa/verify-mfe-health.sh |
| docs/ops/runbooks/COST_MONITORING_RUNBOOK.md | 59 | .github/workflows/scorecard.yml |
| docs/ops/runbooks/database-issues.md | 485 | scripts/qa/verify-mysql-health.sh |
| docs/ops/runbooks/database-issues.md | 488 | scripts/qa/verify-mongodb-health.sh |
| docs/ops/runbooks/database-issues.md | 491 | scripts/qa/verify-redis-health.sh |
| docs/ops/runbooks/scaling.md | 353 | deploy/k8s/base/apps/lms/hpa.yaml |
| docs/ops/runbooks/scaling.md | 495 | scripts/infra/backup-db.sh |
| docs/ops/runbooks/scaling.md | 758 | scripts/qa/load-test-libraries.sh |
| docs/ops/runbooks/scaling.md | 888 | scripts/infra/restore-mysql-backup.sh |
| docs/ops/runbooks/scaling.md | 975 | /tmp/scaling-log.txt |
| docs/reference/operations/MOBILE_SECRETS_MANAGEMENT.md | 252 | docs/archive/ios/MOBILE_IOS_APP_SETUP.md |
| reports/2026/audits/DEPLOYMENT_CRITICAL_GAP_REPORT.md | 126 | scripts/qa/verify-k8s-deployment-spec.sh |
| do../meta/docs-program/IMPLEMENTATION_ROADMAP.md | 181 | docs/archive/reports/ |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 314 | scripts/qa/verify-accessibility.sh |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 325 | scripts/qa/verify-accessibility.sh |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 345 | scripts/qa/run-tenant-branding-qa.sh |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 351 | scripts/qa/run-tenant-branding-qa.sh |
| do../../reports/2026/audits/FRONTEND_AUDIT_CHECKLIST.md | 364 | scripts/qa/run-tenant-branding-qa.sh |
| reports/2026/sprints/SPRINT-02-multi-tenancy.md | 29 | deploy/k8s/overlays/local/patches/meilisearch-security-context.yaml |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 27 | deploy/k8s/base/monitoring/prometheusrule-auth.yaml |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 50 | deploy/k8s/base/apps/tenant-admin/ |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 52 | services/tenant-admin/validators/saml.py |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 56 | infrastructure/tutor/custom-apps/saml_sp/metadata.py |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 61 | deploy/k8s/base/apps/openedx/settings/lms/saml_config.py |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 65 | infrastructure/tutor/custom-apps/saml_sp/attributes.py |
| reports/2026/sprints/SPRINT-03-auth-sso-phase1.md | 72 | infrastructure/tutor/custom-apps/saml_sp/provisioning.py |
| verification/assurance/ASSURANCE_CASE.md | 74 | infrastructure/monitoring/ |
| verification/assurance/ASSURANCE_CASE.md | 92 | docs/archive/reports/PII_DATA_INVENTORY.md |

## Suggested execution sequence

1. Ops/operations cluster: repair paths in docs/ops/** and docs/operations/** (fastest operational impact).
2. ADR/architecture cluster: repair docs/adr/** and docs/concepts/architecture/** paths.
3. Guide/onboarding cluster: repair docs/guides/** and docs/onboarding/** paths.
4. Re-run the non-archive command-reference audit and confirm missing references trend down.
